import Foundation
import GRDB

enum WorkoutRepositoryError: Error, LocalizedError {
  case activeSessionExists
  case noActiveSession
  case occurrenceUnavailable

  var errorDescription: String? {
    switch self {
    case .activeSessionExists: "Finish or discard your current workout first."
    case .noActiveSession: "There is no workout to resume."
    case .occurrenceUnavailable: "This workout is not the next available day."
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
}
