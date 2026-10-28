import Foundation
import GRDB

enum WorkoutRepositoryError: Error, LocalizedError {
  case activeSessionExists
  case noActiveSession
  case occurrenceUnavailable
  case invalidWeight
  case invalidReps
  case sessionNotFound

  var errorDescription: String? {
    switch self {
    case .activeSessionExists: "Finish or discard your current workout first."
    case .noActiveSession: "There is no workout to resume."
    case .occurrenceUnavailable: "This workout is not the next available day."
    case .invalidWeight: "Enter a valid weight of zero or more."
    case .invalidReps: "Enter a positive whole number of repetitions."
    case .sessionNotFound: "This workout could not be found. Reopen it and try again."
    }
  }
}

@MainActor
final class WorkoutRepository {
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
