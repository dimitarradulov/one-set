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
  case invalidCompletedSession

  var errorDescription: String? {
    switch self {
    case .activeSessionExists: "Finish or discard your current workout first."
    case .noActiveSession: "There is no workout to resume."
    case .occurrenceUnavailable: "This workout is not the next available day."
    case .invalidWeight: "Enter a valid weight of zero or more."
    case .invalidReps: "Enter a positive whole number of repetitions."
    case .sessionNotFound: "This workout could not be found. Reopen it and try again."
    case .noCompletedSets: "Complete at least one set before finishing this workout."
    case .invalidCompletedSession: "This workout contains a result that can’t be saved. Your recorded work is still on this device."
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
    let day: Int?
    let isSameProgramWorkout: Bool
  }
  struct PreviousPerformanceSnapshot: Codable, Hashable, Sendable {
    let sessionID: UUID
    let exerciseKey: String
    let programID: String
    let workoutID: String
    let slotID: String
    let weightInput: String
    let repsInput: String
    let weightUnit: WeightUnit
    let completedAt: Date
    let workoutName: String
    let week: Int
    let day: Int?
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
    try Self.normalizeLegacyMigrationIdentifiers(in: database)
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
    migrator.registerMigration("completed-session-uploads-v3") { db in
      try db.create(table: "completed_session_uploads") { table in
        table.column("session_id", .text).primaryKey()
          .references("workout_sessions", onDelete: .cascade)
        table.column("account_id", .text).notNull().indexed()
        table.column("sent_body", .blob).notNull()
        table.column("state", .text).notNull().defaults(to: "pending")
          .check(sql: "state IN ('pending', 'acknowledged')")
        table.column("created_at", .double).notNull()
        table.column("acknowledged_at", .double)
      }
    }
    migrator.registerMigration("completed-session-upload-retry-v4") { db in
      try db.alter(table: "completed_session_uploads") { table in
        table.add(column: "attempt_count", .integer).notNull().defaults(to: 0)
        table.add(column: "retry_after", .double)
        table.add(column: "authentication_deferred", .boolean).notNull().defaults(to: false)
        table.add(column: "permanent_failure", .text)
      }
    }
    migrator.registerMigration("backfill-completed-session-uploads-v5") { db in
      try Self.backfillCompletedSessionUploads(in: db)
    }
    migrator.registerMigration("workout-setup-cycle-upload-conflicts-v6") { db in
      try db.create(table: "workout_cycle_upload_blocks") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("established_cycle_id", .text).notNull()
        table.column("created_at", .double).notNull()
        table.primaryKey(["account_id", "cycle_id"])
      }
    }
    migrator.registerMigration("restored-cycle-progress-v7") { db in
      try db.create(table: "restored_cycle_progress") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("current_training_week", .integer).notNull()
        table.column("payload", .blob).notNull()
        table.primaryKey(["account_id", "cycle_id"])
      }
      try db.create(table: "restored_completed_occurrences") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("week", .integer).notNull()
        table.column("workout_id", .text).notNull()
        table.primaryKey(["account_id", "cycle_id", "week", "workout_id"])
      }
      try db.create(table: "restored_required_workouts") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("week", .integer).notNull()
        table.column("position", .integer).notNull()
        table.column("workout_id", .text).notNull()
        table.primaryKey(["account_id", "cycle_id", "week", "workout_id"])
      }
      try db.create(table: "restored_workout_periods") { table in
        table.column("account_id", .text).notNull()
        table.column("cycle_id", .text).notNull()
        table.column("workout_id", .text).notNull()
        table.column("starts_week", .integer).notNull()
        table.column("ends_week", .integer)
        table.column("payload", .blob).notNull()
        table.primaryKey(["account_id", "cycle_id", "workout_id", "starts_week"])
      }
    }
    migrator.registerMigration("restored-previous-performance-v8") { db in
      try db.create(table: "restored_previous_performance") { table in
        table.column("account_id", .text).primaryKey()
        table.column("payload", .blob).notNull()
        table.column("saved_at", .double).notNull()
      }
    }
    migrator.registerMigration("downloaded-session-history-v9") { db in
      try db.create(table: "account_history_coverage") { table in
        table.column("account_id", .text).primaryKey()
        table.column("next_cursor", .text)
        table.column("has_more", .boolean).notNull()
        table.column("has_loaded_page", .boolean).notNull()
      }
    }
    try migrator.migrate(database)
  }

  private static func normalizeLegacyMigrationIdentifiers(in database: DatabaseQueue) throws {
    try database.write { db in
      guard try db.tableExists("grdb_migrations") else { return }
      // Earlier development builds applied the same cycle-upload-block schema as v5.
      // Recognize that identifier without changing applied migrations or workout data.
      try db.execute(sql: """
        INSERT OR IGNORE INTO grdb_migrations (identifier)
        SELECT 'workout-setup-cycle-upload-conflicts-v6' FROM grdb_migrations
        WHERE identifier = 'workout-setup-cycle-upload-conflicts-v5'
        """)
      try db.execute(sql: """
        DELETE FROM grdb_migrations
        WHERE identifier = 'workout-setup-cycle-upload-conflicts-v5'
        """)
    }
  }

  nonisolated static func backfillCompletedSessionUploads(in db: Database) throws {
    let rows = try Row.fetchAll(db, sql: """
      SELECT id, account_id, payload, finished_at
      FROM workout_sessions
      WHERE finished_at IS NOT NULL
      ORDER BY started_at, id
      """)
    let decoder = JSONDecoder()
    for row in rows {
      let storedID: String = row["id"]
      let storedAccountID: String = row["account_id"]
      let payload: Data = row["payload"]
      guard let sessionID = UUID(uuidString: storedID) else { continue }
      let session = try decoder.decode(WorkoutSession.self, from: payload)
      let hasCompletedCapturedSet = session.exercises.contains { exercise in
        session.setEntries[exercise.slotID]?.completedAt != nil
      }
      guard session.id == sessionID,
            session.accountID == storedAccountID,
            let finishedAt = session.finishedAt,
            hasCompletedCapturedSet else {
        continue
      }

      let sentBody = try CompletedSessionUploadPayload(session: session).encoded()
      try db.execute(sql: """
        INSERT INTO completed_session_uploads (session_id, account_id, sent_body, state, created_at)
        VALUES (?, ?, ?, 'pending', ?)
        ON CONFLICT (session_id) DO NOTHING
        """, arguments: [sessionID.uuidString, storedAccountID, sentBody, finishedAt.timeIntervalSince1970])
    }
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
      let next = try nextOccurrence(in: db, accountID: session.accountID, cycleID: session.cycleID,
        programID: session.programID, workoutIDs: session.requiredWorkoutIDs)
      guard session.week == next.week, session.day == next.day, session.workoutID == next.workoutID else {
        throw WorkoutRepositoryError.occurrenceUnavailable
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
      try nextOccurrence(in: db, accountID: accountID, cycleID: cycleID,
        programID: programID, workoutIDs: workoutIDs)
    }
  }

  private func nextOccurrence(in db: Database, accountID: String, cycleID: UUID,
                              programID: String, workoutIDs: [String]) throws
    -> (week: Int, day: Int, workoutID: String) {
    var week = try Int.fetchOne(db, sql: "SELECT current_training_week FROM restored_cycle_progress WHERE account_id = ? AND cycle_id = ?", arguments: [accountID, cycleID.uuidString]) ?? 1
    while true {
      var members = try String.fetchAll(db, sql: "SELECT workout_id FROM restored_required_workouts WHERE account_id = ? AND cycle_id = ? AND week = ? ORDER BY position", arguments: [accountID, cycleID.uuidString, week])
      if members.isEmpty {
        members = try String.fetchAll(db, sql: "SELECT workout_id FROM workout_week_membership WHERE account_id = ? AND cycle_id = ? AND week = ? ORDER BY rowid", arguments: [accountID, cycleID.uuidString, week])
      }
      if members.isEmpty {
        members = workoutIDs
        for workoutID in members {
          try db.execute(sql: "INSERT OR IGNORE INTO workout_week_membership (account_id, cycle_id, program_id, week, workout_id) VALUES (?, ?, ?, ?, ?)", arguments: [accountID, cycleID.uuidString, programID, week, workoutID])
        }
      }
      for (index, workoutID) in members.enumerated() {
        let completed = try Int.fetchOne(db, sql: """
          SELECT (SELECT COUNT(*) FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND week = ? AND workout_id = ? AND finished_at IS NOT NULL)
            + (SELECT COUNT(*) FROM restored_completed_occurrences WHERE account_id = ? AND cycle_id = ? AND week = ? AND workout_id = ?)
          """, arguments: [accountID, cycleID.uuidString, week, workoutID,
                           accountID, cycleID.uuidString, week, workoutID]) ?? 0
        if completed == 0 { return (week, index + 1, workoutID) }
      }
      week += 1
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
      let sentBody = try CompletedSessionUploadPayload(session: session).encoded()
      try db.execute(sql: "UPDATE workout_sessions SET payload = ?, finished_at = ? WHERE id = ? AND account_id = ? AND finished_at IS NULL", arguments: [updatedPayload, date.timeIntervalSince1970, sessionID.uuidString, accountID])
      try db.execute(sql: """
        INSERT INTO completed_session_uploads (session_id, account_id, sent_body, state, created_at)
        VALUES (?, ?, ?, 'pending', ?)
        ON CONFLICT (session_id) DO NOTHING
        """, arguments: [sessionID.uuidString, accountID, sentBody, date.timeIntervalSince1970])
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET permanent_failure = 'setupCycleConflict'
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
          AND permanent_failure IS NULL
          AND EXISTS (
            SELECT 1 FROM workout_cycle_upload_blocks AS blocks
            WHERE blocks.account_id = ? AND blocks.cycle_id = ?
          )
        """, arguments: [sessionID.uuidString, accountID, accountID, session.cycleID.uuidString])
      return session
    }
  }
}

// MARK: - Completed session uploads

extension WorkoutRepository {
  /// Keeps uploads for a locally-created cycle blocked after setup resolves to another cycle.
  /// The block and existing queue state commit together so relaunch cannot send the wrong cycle.
  @discardableResult
  func blockSessionUploadsForSetupCycle(
    accountID: String,
    cycleID: UUID,
    establishedCycleID: UUID,
    at date: Date = .now
  ) throws -> Bool {
    try database.write { db in
      try db.execute(sql: """
        INSERT INTO workout_cycle_upload_blocks (account_id, cycle_id, established_cycle_id, created_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (account_id, cycle_id) DO NOTHING
        """, arguments: [accountID, cycleID.uuidString, establishedCycleID.uuidString, date.timeIntervalSince1970])
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET permanent_failure = 'setupCycleConflict', retry_after = NULL, authentication_deferred = 0
        WHERE account_id = ? AND state = 'pending' AND permanent_failure IS NULL
          AND session_id IN (
            SELECT id FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND finished_at IS NOT NULL
          )
        """, arguments: [accountID, accountID, cycleID.uuidString])
      return try Self.hasUnresolvedSetupCycleConflict(in: db, accountID: accountID)
    }
  }

  func hasUnresolvedSetupCycleConflict(accountID: String) throws -> Bool {
    try database.read { db in
      try Self.hasUnresolvedSetupCycleConflict(in: db, accountID: accountID)
    }
  }

  private static func hasUnresolvedSetupCycleConflict(in db: Database, accountID: String) throws -> Bool {
    try Bool.fetchOne(db, sql: """
      SELECT EXISTS (
        SELECT 1
        FROM workout_sessions AS sessions
        JOIN workout_cycle_upload_blocks AS blocks
          ON blocks.account_id = sessions.account_id AND blocks.cycle_id = sessions.cycle_id
        LEFT JOIN completed_session_uploads AS uploads
          ON uploads.session_id = sessions.id AND uploads.account_id = sessions.account_id
        WHERE sessions.account_id = ?
          AND (sessions.finished_at IS NULL OR uploads.state = 'pending')
      )
      """, arguments: [accountID]) ?? false
  }

  func pendingSessionUploads(accountID: String) throws -> [PendingSessionUpload] {
    try database.read { db in
      try Row.fetchAll(db, sql: """
        SELECT uploads.session_id, uploads.account_id, uploads.sent_body
        FROM completed_session_uploads AS uploads
        JOIN workout_sessions AS sessions ON sessions.id = uploads.session_id
        WHERE uploads.account_id = ? AND uploads.state = 'pending'
        ORDER BY sessions.started_at, sessions.id
        """, arguments: [accountID]).map { row in
          guard let sessionID = UUID(uuidString: row["session_id"] as String) else {
            throw WorkoutRepositoryError.invalidCompletedSession
          }
          return PendingSessionUpload(
            sessionID: sessionID,
            accountID: row["account_id"],
            body: row["sent_body"]
          )
        }
    }
  }

  func hasPendingSessionUploads(accountID: String) throws -> Bool {
    try database.read { db in
      try Bool.fetchOne(db, sql: """
        SELECT EXISTS (
          SELECT 1 FROM completed_session_uploads
          WHERE account_id = ? AND state = 'pending'
        )
        """, arguments: [accountID]) ?? false
    }
  }

  func hasPendingSessionUploads(accountID: String, cycleID: UUID) throws -> Bool {
    try database.read { db in
      try Bool.fetchOne(db, sql: """
        SELECT EXISTS (
          SELECT 1
          FROM completed_session_uploads AS uploads
          JOIN workout_sessions AS sessions
            ON sessions.id = uploads.session_id AND sessions.account_id = uploads.account_id
          WHERE uploads.account_id = ? AND uploads.state = 'pending' AND sessions.cycle_id = ?
        )
        """, arguments: [accountID, cycleID.uuidString]) ?? false
    }
  }

  func sessionUploadQueue(accountID: String) throws -> [CompletedSessionUploadQueueEntry] {
    try database.read { db in
      try Row.fetchAll(db, sql: """
        SELECT uploads.session_id, uploads.account_id, uploads.sent_body,
          uploads.attempt_count, uploads.retry_after, uploads.authentication_deferred,
          uploads.permanent_failure
        FROM completed_session_uploads AS uploads
        JOIN workout_sessions AS sessions ON sessions.id = uploads.session_id
        WHERE uploads.account_id = ? AND uploads.state = 'pending'
        ORDER BY sessions.started_at, sessions.id
        """, arguments: [accountID]).map { row in
          guard let sessionID = UUID(uuidString: row["session_id"] as String) else {
            throw WorkoutRepositoryError.invalidCompletedSession
          }
          let retryTimestamp: Double? = row["retry_after"]
          let rawFailure: String? = row["permanent_failure"]
          return CompletedSessionUploadQueueEntry(
            upload: PendingSessionUpload(
              sessionID: sessionID,
              accountID: row["account_id"],
              body: row["sent_body"]
            ),
            attemptCount: row["attempt_count"],
            retryAfter: retryTimestamp.map(Date.init(timeIntervalSince1970:)),
            isAuthenticationDeferred: row["authentication_deferred"],
            permanentFailure: rawFailure.flatMap(CompletedSessionUploadRejection.init(rawValue:))
          )
        }
    }
  }

  func pendingSessionUpload(sessionID: UUID, accountID: String) throws -> PendingSessionUpload? {
    try database.read { db in
      guard let row = try Row.fetchOne(db, sql: """
        SELECT session_id, account_id, sent_body
        FROM completed_session_uploads
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
        """, arguments: [sessionID.uuidString, accountID]) else { return nil }
      guard let storedSessionID = UUID(uuidString: row["session_id"] as String) else {
        throw WorkoutRepositoryError.invalidCompletedSession
      }
      return PendingSessionUpload(
        sessionID: storedSessionID,
        accountID: row["account_id"],
        body: row["sent_body"]
      )
    }
  }

  func acknowledgeSessionUpload(sessionID: UUID, accountID: String, at date: Date = .now) throws {
    try database.write { db in
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET state = 'acknowledged', acknowledged_at = ?
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
        """, arguments: [date.timeIntervalSince1970, sessionID.uuidString, accountID])
    }
  }

  func recordTransientUploadFailure(
    sessionID: UUID, accountID: String, retryAt: Date
  ) throws {
    try database.write { db in
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET attempt_count = attempt_count + 1, retry_after = ?, authentication_deferred = 0
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
          AND permanent_failure IS NULL
        """, arguments: [retryAt.timeIntervalSince1970, sessionID.uuidString, accountID])
    }
  }

  func deferUploadUntilAuthenticationRestored(sessionID: UUID, accountID: String) throws {
    try database.write { db in
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET authentication_deferred = 1, retry_after = NULL
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
          AND permanent_failure IS NULL
        """, arguments: [sessionID.uuidString, accountID])
    }
  }

  func resumeAuthenticationDeferredUploads(accountID: String) throws {
    try database.write { db in
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET authentication_deferred = 0, retry_after = NULL
        WHERE account_id = ? AND state = 'pending' AND authentication_deferred = 1
          AND permanent_failure IS NULL
        """, arguments: [accountID])
    }
  }

  func rejectSessionUpload(
    sessionID: UUID, accountID: String, reason: CompletedSessionUploadRejection
  ) throws {
    try database.write { db in
      try db.execute(sql: """
        UPDATE completed_session_uploads
        SET permanent_failure = ?, retry_after = NULL, authentication_deferred = 0
        WHERE session_id = ? AND account_id = ? AND state = 'pending'
          AND permanent_failure IS NULL
        """, arguments: [reason.rawValue, sessionID.uuidString, accountID])
    }
  }
}

// MARK: - History and restored progress

extension WorkoutRepository {
  func completedOccurrenceIDs(accountID: String, cycleID: UUID, week: Int) throws -> Set<String> {
    try database.read { db in
      let local = try String.fetchAll(db, sql: "SELECT workout_id FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND week = ? AND finished_at IS NOT NULL", arguments: [accountID, cycleID.uuidString, week])
      let restored = try String.fetchAll(db, sql: "SELECT workout_id FROM restored_completed_occurrences WHERE account_id = ? AND cycle_id = ? AND week = ?", arguments: [accountID, cycleID.uuidString, week])
      return Set(local + restored)
    }
  }

  func restoreProgress(_ progress: AccountProgress, accountID: String) throws {
    guard progress.currentTrainingWeek > 0,
          progress.completedOccurrences.allSatisfy({ $0.weekNumber > 0 }),
          progress.workoutPeriods.allSatisfy({ period in
            period.startsWeek > 0 && (period.endsWeek.map { $0 >= period.startsWeek } ?? true)
          }) else {
      throw AccountSetupError.invalidSetup
    }
    let payload = try JSONEncoder().encode(progress)
    try database.write { db in
      let existingWeek = try Int.fetchOne(db, sql: "SELECT current_training_week FROM restored_cycle_progress WHERE account_id = ? AND cycle_id = ?", arguments: [accountID, progress.cycleID.uuidString]) ?? 0
      for occurrence in progress.completedOccurrences {
        try db.execute(sql: """
          INSERT OR IGNORE INTO restored_completed_occurrences (account_id, cycle_id, week, workout_id)
          VALUES (?, ?, ?, ?)
          """, arguments: [accountID, progress.cycleID.uuidString, occurrence.weekNumber, occurrence.workoutID])
      }
      if progress.currentTrainingWeek >= existingWeek {
        try db.execute(sql: """
          INSERT INTO restored_cycle_progress (account_id, cycle_id, current_training_week, payload)
          VALUES (?, ?, ?, ?)
          ON CONFLICT (account_id, cycle_id) DO UPDATE SET
            current_training_week = max(restored_cycle_progress.current_training_week, excluded.current_training_week),
            payload = CASE WHEN excluded.current_training_week >= restored_cycle_progress.current_training_week
              THEN excluded.payload ELSE restored_cycle_progress.payload END
          """, arguments: [accountID, progress.cycleID.uuidString, progress.currentTrainingWeek, payload])
        try db.execute(sql: "DELETE FROM restored_required_workouts WHERE account_id = ? AND cycle_id = ? AND week = ?", arguments: [accountID, progress.cycleID.uuidString, progress.currentTrainingWeek])
        for (position, workoutID) in progress.requiredWorkoutIDs.enumerated() {
          try db.execute(sql: """
            INSERT OR IGNORE INTO restored_required_workouts (account_id, cycle_id, week, position, workout_id)
            VALUES (?, ?, ?, ?, ?)
            """, arguments: [accountID, progress.cycleID.uuidString, progress.currentTrainingWeek, position, workoutID])
        }
      }
      for period in progress.workoutPeriods {
        let periodData = try JSONEncoder().encode(period)
        try db.execute(sql: """
          INSERT OR REPLACE INTO restored_workout_periods (account_id, cycle_id, workout_id, starts_week, ends_week, payload)
          VALUES (?, ?, ?, ?, ?, ?)
          """, arguments: [accountID, progress.cycleID.uuidString, period.workoutID, period.startsWeek, period.endsWeek, periodData])
      }
    }
  }

  /// A restored summary confirms the server's complete compact progress for this cycle.
  func hasRestoredCycleSummary(accountID: String, cycleID: UUID) throws -> Bool {
    try database.read { db in
      try Bool.fetchOne(db, sql: """
        SELECT EXISTS (SELECT 1 FROM restored_cycle_progress WHERE account_id = ? AND cycle_id = ?)
        """, arguments: [accountID, cycleID.uuidString]) ?? false
    }
  }

  func hasRestorableProgress(accountID: String, cycleID: UUID) throws -> Bool {
    try database.read { db in
      try Bool.fetchOne(db, sql: """
        SELECT EXISTS (SELECT 1 FROM restored_cycle_progress WHERE account_id = ? AND cycle_id = ?)
          OR EXISTS (SELECT 1 FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND finished_at IS NOT NULL)
          OR EXISTS (SELECT 1 FROM workout_sessions WHERE account_id = ? AND cycle_id = ? AND finished_at IS NULL)
        """, arguments: [accountID, cycleID.uuidString, accountID, cycleID.uuidString,
                         accountID, cycleID.uuidString]) ?? false
    }
  }

  /// Returns only this account's explicitly finished sessions that contain a completed working set.
  /// Ordering is based on the recorded start time, with the stable session ID breaking ties.
  func completedSessions(accountID: String) throws -> [WorkoutSession] {
    let payloads = try database.read { db in
      try Data.fetchAll(db, sql: """
        SELECT payload FROM workout_sessions
        WHERE account_id = ? AND finished_at IS NOT NULL
        ORDER BY started_at DESC, id DESC
        """, arguments: [accountID])
    }
    return try payloads
      .map { try JSONDecoder().decode(WorkoutSession.self, from: $0) }
      .filter { session in
        session.accountID == accountID && session.finishedAt != nil
          && session.exercises.contains { session.setEntries[$0.slotID]?.completedAt != nil }
      }
  }

  func historyCoverage(accountID: String) throws -> SessionHistoryCoverage {
    try database.read { db in
      guard let row = try Row.fetchOne(db, sql: """
        SELECT next_cursor, has_more, has_loaded_page
        FROM account_history_coverage WHERE account_id = ?
        """, arguments: [accountID]) else {
        return SessionHistoryCoverage(nextCursor: nil, hasMore: false, hasLoadedPage: false)
      }
      let hasMore: Bool = row["has_more"]
      return SessionHistoryCoverage(
        nextCursor: row["next_cursor"], hasMore: hasMore,
        hasLoadedPage: row["has_loaded_page"]
      )
    }
  }

  /// Persists a complete server page and its contiguous continuation atomically.
  /// Imported sessions never enter the completed-session upload queue.
  func saveHistoryPage(_ page: SessionHistoryPage, accountID: String) throws {
    guard page.hasMore == (page.nextCursor != nil),
          page.sessions.allSatisfy({ $0.accountID == accountID && $0.finishedAt != nil }) else {
      throw HistoryDataError.accountUnavailable
    }
    try database.write { db in
      let encoder = JSONEncoder()
      for session in page.sessions {
        if let existingAccountID = try String.fetchOne(
          db, sql: "SELECT account_id FROM workout_sessions WHERE id = ?",
          arguments: [session.id.uuidString]
        ) {
          guard existingAccountID == accountID else { throw HistoryDataError.accountUnavailable }
          continue
        }
        let payload = try encoder.encode(session)
        try db.execute(sql: """
          INSERT INTO workout_sessions (
            id, account_id, cycle_id, program_id, week, workout_id, day, started_at, payload, finished_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          """, arguments: [
            session.id.uuidString, accountID, session.cycleID.uuidString, session.programID,
            session.week, session.workoutID, session.day, session.startedAt.timeIntervalSince1970,
            payload, session.finishedAt?.timeIntervalSince1970,
          ])
      }
      try db.execute(sql: """
        INSERT INTO account_history_coverage (account_id, next_cursor, has_more, has_loaded_page)
        VALUES (?, ?, ?, 1)
        ON CONFLICT (account_id) DO UPDATE SET
          next_cursor = excluded.next_cursor,
          has_more = excluded.has_more,
          has_loaded_page = 1
        """, arguments: [accountID, page.nextCursor, page.hasMore])
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
    let restoredPayload = try database.read { db in
      try Data.fetchOne(db, sql: "SELECT payload FROM restored_previous_performance WHERE account_id = ?", arguments: [accountID])
    }
    let restored = try restoredPayload.map { try JSONDecoder().decode([PreviousPerformanceSnapshot].self, from: $0) } ?? []
    var previousBySlot: [String: PreviousPerformance] = [:]
    for requested in exercises {
      let localResults = sessions.flatMap { session -> [PreviousPerformanceSnapshot] in
        guard session.finishedAt != nil else { return [] }
        return session.exercises.compactMap { exercise -> PreviousPerformanceSnapshot? in
          guard exercise.exerciseKey == requested.exerciseKey,
                 let entry = session.setEntries[exercise.slotID],
                let completedAt = entry.completedAt,
                let weight = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
                weight.isFinite, weight >= 0,
                let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else { return nil }
          return PreviousPerformanceSnapshot(
            sessionID: session.id, exerciseKey: exercise.exerciseKey, programID: session.programID,
            workoutID: session.workoutID, slotID: exercise.slotID,
            weightInput: entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines),
            repsInput: entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines),
            weightUnit: session.weightUnit, completedAt: completedAt, workoutName: session.workoutName,
            week: session.week, day: session.day
          )
        }
      }
      let results = (localResults + restored.filter { $0.exerciseKey == requested.exerciseKey })
        .sorted { lhs, rhs in
          if lhs.completedAt != rhs.completedAt { return lhs.completedAt > rhs.completedAt }
          if lhs.sessionID != rhs.sessionID { return lhs.sessionID.uuidString > rhs.sessionID.uuidString }
          return lhs.slotID < rhs.slotID
        }
      let preferred = results.filter { $0.programID == programID && $0.workoutID == workoutID }
      let sameSlot = preferred.filter { $0.slotID == requested.slotID }
      guard let result = (sameSlot.isEmpty ? preferred : sameSlot).first ?? results.first else { continue }
      previousBySlot[requested.slotID] = PreviousPerformance(
        weightInput: result.weightInput, repsInput: result.repsInput,
        weightUnit: result.weightUnit, completedAt: result.completedAt, workoutName: result.workoutName,
        week: result.week, day: result.day,
        isSameProgramWorkout: result.programID == programID && result.workoutID == workoutID
      )
    }
    return previousBySlot
  }

  func saveRestoredPreviousPerformances(
    _ results: [PreviousPerformanceSnapshot], accountID: String, at date: Date = .now
  ) throws {
    let payload = try JSONEncoder().encode(results)
    try database.write { db in
      try db.execute(sql: """
        INSERT INTO restored_previous_performance (account_id, payload, saved_at)
        VALUES (?, ?, ?)
        ON CONFLICT (account_id) DO UPDATE SET payload = excluded.payload, saved_at = excluded.saved_at
        """, arguments: [accountID, payload, date.timeIntervalSince1970])
    }
  }
}

// MARK: - Active session edits

extension WorkoutRepository {
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

  @concurrent
  func saveRecordingInput(sessionID: UUID, accountID: String, slotID: String,
                          weightInput: String, repsInput: String) async throws {
    _ = try updateActiveSession(sessionID: sessionID, accountID: accountID) { session in
      var entry = session.setEntries[slotID] ?? .init()
      if entry.completedAt != nil {
        try Self.validateSetInput(weightInput: weightInput, repsInput: repsInput)
      }
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
      try Self.validateSetInput(weightInput: entry.weightInput, repsInput: entry.repsInput)
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
      try Self.validateSetInput(weightInput: weightInput, repsInput: repsInput)
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

  private nonisolated static func validateSetInput(weightInput: String, repsInput: String) throws {
    guard let weight = Double(weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
          weight.isFinite, weight >= 0 else { throw WorkoutRepositoryError.invalidWeight }
    guard let reps = Int(repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else {
      throw WorkoutRepositoryError.invalidReps
    }
  }

  private nonisolated func updateActiveSession(
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
