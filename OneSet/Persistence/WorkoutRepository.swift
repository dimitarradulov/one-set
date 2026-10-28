import Foundation
import GRDB

enum WorkoutRepositoryError: Error, LocalizedError {
  case activeSessionExists
  case noActiveSession
  case occurrenceUnavailable
  case invalidWeight
  case invalidReps
  case sessionNotFound
  case noCompletedSets

  var errorDescription: String? {
    switch self {
    case .activeSessionExists: "Finish or discard your current workout first."
    case .noActiveSession: "There is no workout to resume."
    case .occurrenceUnavailable: "This workout is not the next available day."
    case .invalidWeight: "Enter a valid weight of zero or more."
    case .invalidReps: "Enter a positive whole number of repetitions."
    case .sessionNotFound: "This workout could not be found. Reopen it and try again."
    case .noCompletedSets: "Complete at least one set before finishing this workout."
    }
  }
}

@MainActor
final class WorkoutRepository {
  struct PreviousPerformance: Hashable, Sendable {
    let weightInput: String
    let repsInput: String
    let weightUnit: WeightUnit
    let completedAt: Date
    let workoutName: String
    let week: Int
    let day: Int
    let isSameProgramWorkout: Bool
  }
  struct PreviousPerformanceRequest: Hashable, Sendable {
    let slotID: String
    let exerciseKey: String
  }

  private let database: DatabaseQueue

  init(databaseURL: URL) throws {
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    database = try DatabaseQueue(path: databaseURL.path)
    var migrator = DatabaseMigrator()
    migrator.registerMigration("create-workout-sessions-v1") { db in
      try db.create(table: "workout_sessions") { table in
        table.column("id", .text).primaryKey()
        table.column("account_id", .text).notNull().indexed()
        table.column("cycle_id", .text).notNull()
        table.column("program_id", .text).notNull()
        table.column("week", .integer).notNull()
        table.column("workout_id", .text).notNull()
        table.column("day", .integer).notNull()
        table.column("started_at", .double).notNull()
        table.column("payload", .blob).notNull()
        table.column("finished_at", .double)
      }
    }
    migrator.registerMigration("workout-week-membership-v2") { db in
      try db.create(table: "workout_week_membership") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("program_id", .text).notNull()
        table.column("week", .integer).notNull()
        table.column("workout_id", .text).notNull()
        table.primaryKey(["account_id", "cycle_id", "week", "workout_id"])
      }
    }
    try migrator.migrate(database)
  }

  func activeSession(accountID: String) throws -> WorkoutSession? {
    guard let payload = try database.read({ db in
      try Data.fetchOne(db, sql: "SELECT payload FROM workout_sessions WHERE account_id = ? AND finished_at IS NULL ORDER BY started_at LIMIT 1", arguments: [accountID])
    }) else { return nil }
    return try JSONDecoder().decode(WorkoutSession.self, from: payload)
  }

  @discardableResult
  func start(_ session: WorkoutSession) throws -> WorkoutSession {
    try database.write { db in
      if let payload = try Data.fetchOne(db, sql: "SELECT payload FROM workout_sessions WHERE account_id = ? AND finished_at IS NULL ORDER BY started_at LIMIT 1", arguments: [session.accountID]) {
        return try JSONDecoder().decode(WorkoutSession.self, from: payload)
      }
      var expectedWeek = 1
      while true {
        var members = try String.fetchAll(db, sql: "SELECT workout_id FROM workout_week_membership WHERE account_id = ? AND cycle_id = ? AND week = ? ORDER BY rowid", arguments: [session.accountID, session.cycleID.uuidString, expectedWeek])
        if members.isEmpty {
          members = session.requiredWorkoutIDs
          for workoutID in members {
            try db.execute(sql: "INSERT OR IGNORE INTO workout_week_membership (account_id, cycle_id, program_id, week, workout_id) VALUES (?, ?, ?, ?, ?)", arguments: [session.accountID, session.cycleID.uuidString, session.programID, expectedWeek, workoutID])
          }
        }
        var expectedDay: Int?
        for (index, workoutID) in members.enumerated() {
          let completed = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND week = ? AND workout_id = ? AND finished_at IS NOT NULL", arguments: [session.accountID, session.cycleID.uuidString, expectedWeek, workoutID]) ?? 0
          if completed == 0 { expectedDay = index + 1; break }
        }
        if let expectedDay {
          guard session.week == expectedWeek, session.day == expectedDay,
                members[expectedDay - 1] == session.workoutID else {
            throw WorkoutRepositoryError.occurrenceUnavailable
          }
          break
        }
        expectedWeek += 1
      }
      let payload = try JSONEncoder().encode(session)
      try db.execute(sql: "INSERT INTO workout_sessions (id, account_id, cycle_id, program_id, week, workout_id, day, started_at, payload) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", arguments: [session.id.uuidString, session.accountID, session.cycleID.uuidString, session.programID, session.week, session.workoutID, session.day, session.startedAt.timeIntervalSince1970, payload])
      return session
    }
  }

  func discard(sessionID: UUID, accountID: String) throws {
    try database.write { db in
      try db.execute(sql: "DELETE FROM workout_sessions WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [sessionID.uuidString, accountID])
    }
  }

  func nextOccurrence(accountID: String, cycleID: UUID, programID: String,
                      workoutIDs: [String]) throws -> (week: Int, day: Int, workoutID: String) {
    try database.write { db in
      var week = 1
      while true {
        var members = try String.fetchAll(db, sql: "SELECT workout_id FROM workout_week_membership WHERE account_id = ? AND cycle_id = ? AND week = ? ORDER BY rowid", arguments: [accountID, cycleID.uuidString, week])
        if members.isEmpty {
          members = workoutIDs
          for workoutID in members {
            try db.execute(sql: "INSERT OR IGNORE INTO workout_week_membership (account_id, cycle_id, program_id, week, workout_id) VALUES (?, ?, ?, ?, ?)", arguments: [accountID, cycleID.uuidString, programID, week, workoutID])
          }
        }
        for (index, workoutID) in members.enumerated() {
          let completed = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND week = ? AND workout_id = ? AND finished_at IS NOT NULL", arguments: [accountID, cycleID.uuidString, week, workoutID]) ?? 0
          if completed == 0 { return (week, index + 1, workoutID) }
        }
        week += 1
      }
    }
  }

  @discardableResult
  func finish(sessionID: UUID, accountID: String, note: String?, at date: Date = .now) throws -> WorkoutSession {
    try database.write { db in
      guard let payload = try Data.fetchOne(db, sql: "SELECT payload FROM workout_sessions WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [sessionID.uuidString, accountID]) else {
        if let payload = try Data.fetchOne(db, sql: "SELECT payload FROM workout_sessions WHERE id = ? AND account_id = ? AND finished_at IS NOT NULL", arguments: [sessionID.uuidString, accountID]) {
          return try JSONDecoder().decode(WorkoutSession.self, from: payload)
        }
        throw WorkoutRepositoryError.sessionNotFound
      }
      var session = try JSONDecoder().decode(WorkoutSession.self, from: payload)
      guard session.setEntries.values.contains(where: { $0.completedAt != nil }) else {
        throw WorkoutRepositoryError.noCompletedSets
      }
      let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
      session.note = trimmedNote?.isEmpty == true ? nil : trimmedNote
      session.finishedAt = date
      session.restDeadline = nil
      let updatedPayload = try JSONEncoder().encode(session)
      try db.execute(sql: "UPDATE workout_sessions SET payload = ?, finished_at = ? WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [updatedPayload, date.timeIntervalSince1970, sessionID.uuidString, accountID])
      return session
    }
  }

  func completedOccurrenceIDs(accountID: String, cycleID: UUID, week: Int) throws -> Set<String> {
    try database.read { db in
      Set(try String.fetchAll(db, sql: "SELECT workout_id FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND week = ? AND finished_at IS NOT NULL", arguments: [accountID, cycleID.uuidString, week]))
    }
  }

  func previousPerformance(accountID: String, exerciseKey: String, slotID: String,
                           programID: String, workoutID: String) throws -> PreviousPerformance? {
    let query = PreviousPerformanceRequest(slotID: slotID, exerciseKey: exerciseKey)
    return try previousPerformances(accountID: accountID, exercises: [query], programID: programID,
                                    workoutID: workoutID)[slotID]
  }

  func previousPerformances(accountID: String, exercises: [PreviousPerformanceRequest],
                            programID: String, workoutID: String) throws -> [String: PreviousPerformance] {
    let payloads = try database.read { db in
      try Data.fetchAll(db, sql: "SELECT payload FROM workout_sessions WHERE account_id = ? AND finished_at IS NOT NULL ORDER BY finished_at DESC", arguments: [accountID])
    }
    let sessions = try payloads.map { try JSONDecoder().decode(WorkoutSession.self, from: $0) }
    var previousBySlot: [String: PreviousPerformance] = [:]
    for requested in exercises {
      let results = sessions.flatMap { session -> [(WorkoutSession, WorkoutSession.Exercise, WorkoutSession.SetEntry)] in
        guard session.finishedAt != nil else { return [] }
        return session.exercises.compactMap { exercise in
          guard exercise.exerciseKey == requested.exerciseKey,
                let entry = session.setEntries[exercise.slotID],
                entry.completedAt != nil,
                let weight = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
                weight.isFinite, weight >= 0,
                let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else { return nil }
          return (session, exercise, entry)
        }
      }
      let preferred = results.filter { $0.0.programID == programID && $0.0.workoutID == workoutID }
      let sameSlot = preferred.filter { $0.1.slotID == requested.slotID }
      guard let (session, _, entry) = (sameSlot.isEmpty ? preferred : sameSlot).first ?? results.first,
            let completedAt = entry.completedAt else { continue }
      previousBySlot[requested.slotID] = PreviousPerformance(
        weightInput: entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines),
        repsInput: entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines),
        weightUnit: session.weightUnit, completedAt: completedAt, workoutName: session.workoutName,
        week: session.week, day: session.day,
        isSameProgramWorkout: session.programID == programID && session.workoutID == workoutID
      )
    }
    return previousBySlot
  }

  @discardableResult
  func saveDraft(sessionID: UUID, accountID: String, slotID: String,
                 weightInput: String, repsInput: String) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      var entry = session.setEntries[slotID] ?? .init()
      entry.weightInput = weightInput
      entry.repsInput = repsInput
      session.setEntries[slotID] = entry
    }
  }

  @discardableResult
  func completeSet(sessionID: UUID, accountID: String, slotID: String,
                   restSeconds: Int? = nil,
                   at date: Date = .now) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      guard session.exercises.contains(where: { $0.slotID == slotID }) else {
        throw WorkoutRepositoryError.sessionNotFound
      }
      var entry = session.setEntries[slotID] ?? .init()
      guard let weight = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
            weight.isFinite, weight >= 0 else { throw WorkoutRepositoryError.invalidWeight }
      guard let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else {
        throw WorkoutRepositoryError.invalidReps
      }
      // Retrying a completion is idempotent and does not create another completion event.
      guard entry.completedAt == nil else { return }
      entry.completedAt = date
      session.setEntries[slotID] = entry
      session.restDeadline = restSeconds.map { date.addingTimeInterval(TimeInterval($0)) }
    }
  }

  @discardableResult
  func updateSet(sessionID: UUID, accountID: String, slotID: String,
                 weightInput: String, repsInput: String) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      guard var entry = session.setEntries[slotID], entry.completedAt != nil else {
        throw WorkoutRepositoryError.sessionNotFound
      }
      guard let weight = Double(weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
            weight.isFinite, weight >= 0 else { throw WorkoutRepositoryError.invalidWeight }
      guard let reps = Int(repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else {
        throw WorkoutRepositoryError.invalidReps
      }
      entry.weightInput = weightInput
      entry.repsInput = repsInput
      session.setEntries[slotID] = entry
    }
  }

  @discardableResult
  func unmarkSet(sessionID: UUID, accountID: String, slotID: String) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      guard var entry = session.setEntries[slotID], entry.completedAt != nil else { return }
      entry.completedAt = nil
      session.setEntries[slotID] = entry
    }
  }

  @discardableResult
  func adjustRest(sessionID: UUID, accountID: String, by seconds: Int,
                  at date: Date = .now) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      guard let deadline = session.restDeadline, deadline > date else {
        session.restDeadline = nil
        return
      }
      let adjusted = deadline.addingTimeInterval(TimeInterval(seconds))
      session.restDeadline = adjusted > date ? adjusted : nil
    }
  }

  @discardableResult
  func skipRest(sessionID: UUID, accountID: String) throws -> WorkoutSession {
    try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      session.restDeadline = nil
    }
  }

  private func updateActiveSession(
    sessionID: UUID, accountID: String,
    change: (inout WorkoutSession) throws -> Void
  ) throws -> WorkoutSession {
    try database.write { db in
      guard let payload = try Data.fetchOne(db, sql: "SELECT payload FROM workout_sessions WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [sessionID.uuidString, accountID]) else {
        throw WorkoutRepositoryError.sessionNotFound
      }
      var session = try JSONDecoder().decode(WorkoutSession.self, from: payload)
      try change(&session)
      let updatedPayload = try JSONEncoder().encode(session)
      try db.execute(sql: "UPDATE workout_sessions SET payload = ? WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [updatedPayload, sessionID.uuidString, accountID])
      return session
    }
  }
}
