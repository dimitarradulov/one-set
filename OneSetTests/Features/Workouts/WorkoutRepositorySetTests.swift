import Foundation
import GRDB
import Testing
@testable import OneSet

@MainActor
struct WorkoutRepositorySetTests {
  @Test(arguments: [false, true])
  func reopensStoreWithLegacyCycleUploadBlockMigration(backfillWasApplied: Bool) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "72.5", repsInput: "10")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    _ = try repository.finish(sessionID: session.id, accountID: session.accountID, note: "Keep this session")
    try repository.recordTransientUploadFailure(sessionID: session.id, accountID: session.accountID,
      retryAt: Date(timeIntervalSince1970: 1_800_000_050))
    let active = makeSession(cycleID: session.cycleID, week: 2)
    _ = try repository.start(active)
    _ = try repository.saveDraft(sessionID: active.id, accountID: active.accountID,
      slotID: "slot-b", weightInput: "25", repsInput: "draft")
    _ = try repository.blockSessionUploadsForSetupCycle(accountID: session.accountID,
      cycleID: session.cycleID, establishedCycleID: UUID())

    let database = try DatabaseQueue(path: databaseURL.path)
    let tables = ["workout_sessions", "workout_week_membership", "completed_session_uploads",
                  "workout_cycle_upload_blocks"]
    let before = try database.read { db in
      try tables.map { try Row.fetchAll(db, sql: "SELECT * FROM \($0) ORDER BY rowid") }
    }
    // Reproduce the migration history found in the affected simulator store.
    try database.write { db in
      try db.execute(sql: """
        UPDATE grdb_migrations SET identifier = 'workout-setup-cycle-upload-conflicts-v5'
        WHERE identifier = 'workout-setup-cycle-upload-conflicts-v6'
        """)
      if !backfillWasApplied {
        try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = 'backfill-completed-session-uploads-v5'")
      }
    }
    let fixtureMigrations = try database.read { db in
      try String.fetchSet(db, sql: "SELECT identifier FROM grdb_migrations")
    }
    try #require(fixtureMigrations.contains("workout-setup-cycle-upload-conflicts-v5"))
    try #require(fixtureMigrations.contains("workout-setup-cycle-upload-conflicts-v6") == false)
    try #require(fixtureMigrations.contains("backfill-completed-session-uploads-v5") == backfillWasApplied)

    for _ in 0..<2 {
      let reopened = try WorkoutRepository(databaseURL: databaseURL)
      let after = try database.read { db in
        try tables.map { try Row.fetchAll(db, sql: "SELECT * FROM \($0) ORDER BY rowid") }
      }
      #expect(after == before)
      #expect(try reopened.activeSession(accountID: active.accountID)?.id == active.id)
      #expect(try reopened.hasUnresolvedSetupCycleConflict(accountID: session.accountID))
      let migrations = try database.read { db in
        try String.fetchSet(db, sql: "SELECT identifier FROM grdb_migrations")
      }
      #expect(migrations.contains("workout-setup-cycle-upload-conflicts-v6"))
      #expect(migrations.contains("workout-setup-cycle-upload-conflicts-v5") == false)
      #expect(migrations.contains("backfill-completed-session-uploads-v5"))
    }
  }

  @Test
  func completedUploadRetryPolicyUsesExponentialDelayAndHonorsRetryAfter() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(CompletedSessionUploadRetryPolicy.retryDate(afterAttempt: 1, at: now)
      == now.addingTimeInterval(15))
    #expect(CompletedSessionUploadRetryPolicy.retryDate(afterAttempt: 2, at: now)
      == now.addingTimeInterval(30))
    #expect(CompletedSessionUploadRetryPolicy.retryDate(afterAttempt: 99, at: now)
      == now.addingTimeInterval(6 * 60 * 60))
    #expect(CompletedSessionUploadRetryPolicy.retryDate(
      afterAttempt: 1, at: now, serverRetryAt: now.addingTimeInterval(60)
    ) == now.addingTimeInterval(60))
    #expect(CompletedSessionUploadRetryPolicy.retryDate(
      afterAttempt: 1, at: now, serverRetryAt: now.addingTimeInterval(7 * 60 * 60)
    ) == now.addingTimeInterval(7 * 60 * 60))
  }

  @Test
  func draftsAndCompletedSetsSurviveRepositoryReopenAndCanBeCorrectedOrUndone() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let session = makeSession()
    let first = try WorkoutRepository(databaseURL: databaseURL)
    _ = try first.start(session)

    _ = try first.saveDraft(sessionID: session.id, accountID: session.accountID,
                            slotID: "slot-a", weightInput: "72.5", repsInput: "")
    #expect(throws: WorkoutRepositoryError.invalidReps) {
      try first.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    }
    _ = try first.saveDraft(sessionID: session.id, accountID: session.accountID,
                            slotID: "slot-a", weightInput: "72.5", repsInput: "10")
    let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let completed = try first.completeSet(
      sessionID: session.id, accountID: session.accountID, slotID: "slot-a", restSeconds: 120, at: completedAt
    )
    #expect(completed.setEntries["slot-a"]?.completedAt == completedAt)
    #expect(completed.restDeadline == completedAt.addingTimeInterval(120))
    #expect(try first.completeSet(
      sessionID: session.id, accountID: session.accountID, slotID: "slot-a", restSeconds: 300, at: completedAt.addingTimeInterval(10)
    ).restDeadline == completedAt.addingTimeInterval(120))

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let restored = try #require(try reopened.activeSession(accountID: session.accountID))
    #expect(restored.setEntries["slot-a"]?.weightInput == "72.5")
    #expect(restored.setEntries["slot-a"]?.repsInput == "10")
    #expect(restored.setEntries["slot-a"]?.completedAt == completedAt)

    let corrected = try reopened.updateSet(sessionID: session.id, accountID: session.accountID,
                                           slotID: "slot-a", weightInput: "75.25", repsInput: "11")
    #expect(corrected.setEntries["slot-a"]?.weightInput == "75.25")
    #expect(corrected.setEntries["slot-a"]?.completedAt == completedAt)
    let undone = try reopened.unmarkSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    #expect(undone.setEntries["slot-a"]?.completedAt == nil)
    #expect(undone.setEntries["slot-a"]?.weightInput == "75.25")
  }

  @Test
  func completedSessionsAreAccountScopedFinishedAndNewestFirstWithStableTies() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let tiedStart = Date(timeIntervalSince1970: 1_800_000_000)
    let firstID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    let secondID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
    let cycleID = UUID()

    for (week, id) in [(1, firstID), (2, secondID)] {
      let session = makeSession(cycleID: cycleID, week: week, startedAt: tiedStart, id: id)
      _ = try repository.start(session)
      _ = try repository.saveDraft(sessionID: id, accountID: session.accountID,
        slotID: "slot-a", weightInput: "0", repsInput: "8")
      _ = try repository.completeSet(sessionID: id, accountID: session.accountID,
        slotID: "slot-a", at: tiedStart.addingTimeInterval(30))
      _ = try repository.finish(sessionID: id, accountID: session.accountID,
        note: nil, at: tiedStart.addingTimeInterval(60))
    }

    let active = makeSession(cycleID: cycleID, week: 3, startedAt: tiedStart.addingTimeInterval(100))
    _ = try repository.start(active)
    let otherAccount = makeSession(week: 1, startedAt: tiedStart, accountID: "other-account")
    _ = try repository.start(otherAccount)
    _ = try repository.saveDraft(sessionID: otherAccount.id, accountID: otherAccount.accountID,
      slotID: "slot-a", weightInput: "20", repsInput: "10")
    _ = try repository.completeSet(sessionID: otherAccount.id, accountID: otherAccount.accountID,
      slotID: "slot-a")
    _ = try repository.finish(sessionID: otherAccount.id, accountID: otherAccount.accountID, note: nil)

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let sessions = try reopened.completedSessions(accountID: "account")
    #expect(sessions.map(\.id) == [secondID, firstID])
    #expect(sessions.allSatisfy { $0.finishedAt != nil })
    #expect(try reopened.completedSessions(accountID: "other-account").map(\.id) == [otherAccount.id])
    #expect(sessions[0].setEntries["slot-a"]?.weightInput == "0")
  }

  @Test
  func invalidLoadsAndOtherAccountsCannotCompleteASession() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
                                 slotID: "slot-a", weightInput: "NaN", repsInput: "8")
    #expect(throws: WorkoutRepositoryError.invalidWeight) {
      try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    }
    #expect(throws: WorkoutRepositoryError.sessionNotFound) {
      try repository.completeSet(sessionID: session.id, accountID: "another-account", slotID: "slot-a")
    }
    #expect(try repository.activeSession(accountID: session.accountID)?.setEntries["slot-a"]?.completedAt == nil)
  }

  @Test
  func finishingPartialWorkPersistsNoteAndAdvancesOnlyAfterRequiredDays() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let first = makeSession()
    let occurrence = try repository.nextOccurrence(accountID: first.accountID, cycleID: first.cycleID,
      programID: first.programID, workoutIDs: ["day-a", "day-b"])
    #expect(occurrence.week == 1)
    #expect(occurrence.day == 1)
    _ = try repository.start(first)
    _ = try repository.saveDraft(sessionID: first.id, accountID: first.accountID,
      slotID: "slot-a", weightInput: "50", repsInput: "8")
    _ = try repository.completeSet(sessionID: first.id, accountID: first.accountID, slotID: "slot-a")

    let finished = try repository.finish(sessionID: first.id, accountID: first.accountID, note: "Felt strong")
    #expect(finished.finishedAt != nil)
    #expect(finished.note == "Felt strong")
    #expect(finished.setEntries["slot-a"]?.completedAt != nil)
    #expect(try repository.activeSession(accountID: first.accountID) == nil)
    #expect(try repository.completedOccurrenceIDs(accountID: first.accountID, cycleID: first.cycleID, week: 1) == ["day-a"])
    let next = try repository.nextOccurrence(accountID: first.accountID, cycleID: first.cycleID,
      programID: first.programID, workoutIDs: ["day-a", "day-b"])
    #expect(next.week == 1)
    #expect(next.day == 2)
    #expect(next.workoutID == "day-b")

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try reopened.completedOccurrenceIDs(accountID: first.accountID, cycleID: first.cycleID, week: 1) == ["day-a"])
    #expect(try reopened.finish(sessionID: first.id, accountID: first.accountID, note: "ignored").note == "Felt strong")
  }

  @Test
  func upgradingPreUploadStoreBackfillsOnlyCompletedSessionsAndPreservesSnapshots() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let cycleID = UUID()
    let first = makeLegacyFinishedSession(cycleID: cycleID, week: 1,
      startedAt: Date(timeIntervalSince1970: 1_800_000_000),
      finishedAt: Date(timeIntervalSince1970: 1_800_003_600), note: "First session")
    let second = makeLegacyFinishedSession(cycleID: cycleID, week: 2,
      startedAt: Date(timeIntervalSince1970: 1_806_000_000),
      finishedAt: Date(timeIntervalSince1970: 1_806_003_600), note: nil)
    var active = makeSession(cycleID: cycleID, week: 3)
    active.setEntries["slot-a"] = .init(weightInput: "90", repsInput: "draft", completedAt: nil)
    let empty = makeLegacyFinishedSession(cycleID: cycleID, week: 4,
      startedAt: Date(timeIntervalSince1970: 1_807_000_000),
      finishedAt: Date(timeIntervalSince1970: 1_807_003_600), note: "Empty attempt", completed: false)
    try makePreUploadStore(databaseURL: databaseURL, sessions: [first, second, active, empty])

    let upgraded = try WorkoutRepository(databaseURL: databaseURL)
    let queued = try upgraded.pendingSessionUploads(accountID: "account")
    #expect(queued.map(\.sessionID) == [first.id, second.id])
    #expect(try upgraded.pendingSessionUploads(accountID: "different-account").isEmpty)
    #expect(try upgraded.activeSession(accountID: "account")?.id == active.id)
    #expect(try upgraded.activeSession(accountID: "account")?.setEntries["slot-a"]?.weightInput == "90")
    #expect(try upgraded.completedOccurrenceIDs(accountID: "account", cycleID: cycleID, week: 1) == ["day-a"])
    #expect(try upgraded.completedOccurrenceIDs(accountID: "account", cycleID: cycleID, week: 2) == ["day-a"])
    #expect(try upgraded.completedOccurrenceIDs(accountID: "account", cycleID: cycleID, week: 3).isEmpty)
    #expect(try upgraded.nextOccurrence(accountID: "account", cycleID: cycleID,
      programID: "program", workoutIDs: ["day-a"]).week == 3)

    let firstBody = try #require(JSONSerialization.jsonObject(with: queued[0].body) as? [String: Any])
    #expect(firstBody["session_id"] as? String == first.id.uuidString.lowercased())
    #expect(firstBody["cycle_id"] as? String == cycleID.uuidString.lowercased())
    #expect(firstBody["week_number"] as? Int == 1)
    #expect(firstBody["day_number"] as? Int == 1)
    #expect(firstBody["note"] as? String == "First session")
    let firstSets = try #require(firstBody["sets"] as? [[String: Any]])
    #expect(firstSets.count == 2)
    #expect(firstSets[0]["workout_exercise_key"] as? String == "removed-slot")
    #expect(firstSets[0]["unit"] as? String == WeightUnit.pounds.rawValue)
    #expect(firstSets[0]["weight"] as? Double == 72.5)
    #expect(firstSets[0]["reps"] as? Int == 10)
    let capturedPrescription = try #require(firstSets[0]["prescription"] as? [String: Any])
    #expect(capturedPrescription["instructions"] as? String == "Instructions captured before the catalog changed.")
    #expect(capturedPrescription["video_key"] as? String == "row/legacy-demo.mp4")
    #expect(firstSets[1]["weight"] is NSNull)
    #expect(firstSets[1]["reps"] is NSNull)
    #expect(firstSets[1]["completed_at"] is NSNull)

    try upgraded.acknowledgeSessionUpload(sessionID: first.id, accountID: "account",
      at: Date(timeIntervalSince1970: 1_810_000_000))
    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let remaining = try reopened.pendingSessionUploads(accountID: "account")
    #expect(remaining.map(\.sessionID) == [second.id])
    #expect(try reopened.pendingSessionUpload(sessionID: first.id, accountID: "account") == nil)
    #expect(remaining.first?.body == queued[1].body)

    let database = try DatabaseQueue(path: databaseURL.path)
    try database.write { db in
      try WorkoutRepository.backfillCompletedSessionUploads(in: db)
    }
    let afterRepeatedBackfill = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try afterRepeatedBackfill.sessionUploadQueue(accountID: "account").map(\.upload.sessionID) == [second.id])
    #expect(try afterRepeatedBackfill.pendingSessionUpload(sessionID: first.id, accountID: "account") == nil)
  }

  @Test
  func setupCycleConflictMigrationRunsOnFreshAndExistingV5Stores() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let freshURL = directory.appending(path: "fresh.sqlite")
    _ = try WorkoutRepository(databaseURL: freshURL)
    let freshDatabase = try DatabaseQueue(path: freshURL.path)
    let freshMigrations = try freshDatabase.read { db in
      try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
    }
    #expect(freshMigrations.contains("backfill-completed-session-uploads-v5"))
    #expect(freshMigrations.contains("workout-setup-cycle-upload-conflicts-v6"))
    #expect(try freshDatabase.read { try $0.tableExists("workout_cycle_upload_blocks") })
    #expect(freshMigrations.contains("restored-previous-performance-v8"))
    #expect(try freshDatabase.read { try $0.tableExists("restored_previous_performance") })

    let existingURL = directory.appending(path: "existing-v5.sqlite")
    _ = try WorkoutRepository(databaseURL: existingURL)
    let existingDatabase = try DatabaseQueue(path: existingURL.path)
    try existingDatabase.write { db in
      try db.execute(sql: "DROP TABLE workout_cycle_upload_blocks")
      try db.execute(
        sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
        arguments: ["workout-setup-cycle-upload-conflicts-v6"]
      )
    }
    let beforeUpgrade = try existingDatabase.read { db in
      try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
    }
    #expect(beforeUpgrade.contains("backfill-completed-session-uploads-v5"))
    #expect(!beforeUpgrade.contains("workout-setup-cycle-upload-conflicts-v6"))

    _ = try WorkoutRepository(databaseURL: existingURL)
    let upgradedDatabase = try DatabaseQueue(path: existingURL.path)
    let upgradedMigrations = try upgradedDatabase.read { db in
      try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
    }
    #expect(upgradedMigrations.contains("backfill-completed-session-uploads-v5"))
    #expect(upgradedMigrations.contains("workout-setup-cycle-upload-conflicts-v6"))
    #expect(try upgradedDatabase.read { try $0.tableExists("workout_cycle_upload_blocks") })
    #expect(upgradedMigrations.contains("restored-previous-performance-v8"))
    #expect(try upgradedDatabase.read { try $0.tableExists("restored_previous_performance") })
  }

  @Test
  func finishingPersistsOneStableUploadWithCapturedResultsAndNullUnperformedSlots() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "72.5", repsInput: "10")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", at: Date(timeIntervalSince1970: 1_800_000_060))
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-b", weightInput: "999", repsInput: "99")

    let finishedAt = Date(timeIntervalSince1970: 1_800_000_120)
    let finished = try repository.finish(sessionID: session.id, accountID: session.accountID,
      note: "  Felt strong  ", at: finishedAt)
    let pending = try #require(repository.pendingSessionUploads(accountID: session.accountID).first)
    let body = try #require(JSONSerialization.jsonObject(with: pending.body) as? [String: Any])
    let slots = try #require(body["sets"] as? [[String: Any]])
    let completed = try #require(slots.first { $0["workout_exercise_key"] as? String == "slot-a" })
    let unperformed = try #require(slots.first { $0["workout_exercise_key"] as? String == "slot-b" })

    #expect(finished.id == session.id)
    #expect(body["session_id"] as? String == session.id.uuidString.lowercased())
    #expect(body["note"] as? String == "Felt strong")
    #expect(completed["weight"] as? Double == 72.5)
    #expect(completed["unit"] as? String == "lb")
    #expect(completed["reps"] as? Int == 10)
    #expect(completed["completed_at"] as? String == "2027-01-15T08:01:00.000Z")
    #expect(unperformed["weight"] is NSNull)
    #expect(unperformed["reps"] is NSNull)
    #expect(unperformed["completed_at"] is NSNull)

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let recovered = try #require(reopened.pendingSessionUploads(accountID: session.accountID).first)
    #expect(recovered.body == pending.body)
    #expect(try reopened.finish(sessionID: session.id, accountID: session.accountID,
      note: "changed", at: finishedAt).note == "Felt strong")
    #expect(try reopened.pendingSessionUploads(accountID: session.accountID).first?.body == pending.body)

    try reopened.acknowledgeSessionUpload(sessionID: session.id, accountID: session.accountID,
      at: finishedAt.addingTimeInterval(1))
    let acknowledged = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try acknowledged.pendingSessionUploads(accountID: session.accountID).isEmpty)
    #expect(try acknowledged.finish(sessionID: session.id, accountID: session.accountID,
      note: "changed again", at: finishedAt).note == "Felt strong")
    #expect(try acknowledged.pendingSessionUploads(accountID: session.accountID).isEmpty)
  }

  @Test
  func failedFinishTransactionRetainsActiveSessionAndDoesNotQueueAnUpload() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "50", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    let sabotage = try DatabaseQueue(path: databaseURL.path)
    try sabotage.write { db in
      try db.execute(sql: """
        CREATE TRIGGER fail_session_upload BEFORE INSERT ON completed_session_uploads
        BEGIN SELECT RAISE(ABORT, 'upload queue unavailable'); END
        """)
    }

    #expect(throws: (any Error).self) {
      try repository.finish(sessionID: session.id, accountID: session.accountID, note: "Kept")
    }
    #expect(try repository.activeSession(accountID: session.accountID)?.id == session.id)
    #expect(try repository.pendingSessionUploads(accountID: session.accountID).isEmpty)
    #expect(try repository.activeSession(accountID: session.accountID)?.setEntries["slot-a"]?.completedAt != nil)

    try sabotage.write { db in
      try db.execute(sql: "DROP TRIGGER fail_session_upload")
    }
    let finished = try repository.finish(sessionID: session.id, accountID: session.accountID, note: "Kept")
    #expect(finished.finishedAt != nil)
    #expect(try repository.pendingSessionUploads(accountID: session.accountID).count == 1)
  }

  @Test
  func failedUploadAcknowledgmentRetainsTheSameSentBodyForRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "50", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
    _ = try repository.finish(sessionID: session.id, accountID: session.accountID, note: nil)
    let pending = try #require(
      try repository.pendingSessionUpload(sessionID: session.id, accountID: session.accountID)
    )
    let payload = try #require(JSONSerialization.jsonObject(with: pending.body) as? [String: Any])
    #expect(payload["note"] is NSNull)
    let sets = try #require(payload["sets"] as? [[String: Any]])
    let unperformed = try #require(sets.first { $0["workout_exercise_key"] as? String == "slot-b" })
    let prescription = try #require(unperformed["prescription"] as? [String: Any])
    #expect(prescription["video_key"] is NSNull)
    #expect(prescription["rest_seconds"] is NSNull)
    let sabotage = try DatabaseQueue(path: databaseURL.path)
    try sabotage.write { db in
      try db.execute(sql: """
        CREATE TRIGGER fail_session_ack BEFORE UPDATE OF state ON completed_session_uploads
        BEGIN SELECT RAISE(ABORT, 'acknowledgment storage unavailable'); END
        """)
    }

    #expect(throws: (any Error).self) {
      try repository.acknowledgeSessionUpload(sessionID: session.id, accountID: session.accountID)
    }
    let retained = try #require(
      try repository.pendingSessionUpload(sessionID: session.id, accountID: session.accountID)
    )
    #expect(retained.body == pending.body)
    #expect(retained.accountID == pending.accountID)
  }

  @Test
  func uploadRetryStateSurvivesRepositoryReopeningAndCanBeReleased() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "50", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", at: Date(timeIntervalSince1970: 1_800_000_010))
    _ = try repository.finish(sessionID: session.id, accountID: session.accountID, note: nil,
      at: Date(timeIntervalSince1970: 1_800_000_020))
    let original = try #require(repository.sessionUploadQueue(accountID: session.accountID).first)
    let retryAt = Date(timeIntervalSince1970: 1_800_000_050)

    try repository.recordTransientUploadFailure(
      sessionID: session.id, accountID: session.accountID, retryAt: retryAt
    )
    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let retry = try #require(reopened.sessionUploadQueue(accountID: session.accountID).first)
    #expect(retry.upload.body == original.upload.body)
    #expect(retry.attemptCount == 1)
    #expect(retry.retryAfter == retryAt)
    #expect(retry.isAuthenticationDeferred == false)
    #expect(retry.permanentFailure == nil)

    try reopened.deferUploadUntilAuthenticationRestored(
      sessionID: session.id, accountID: session.accountID
    )
    let deferred = try #require(reopened.sessionUploadQueue(accountID: session.accountID).first)
    #expect(deferred.isAuthenticationDeferred)
    #expect(deferred.retryAfter == nil)

    try reopened.resumeAuthenticationDeferredUploads(accountID: session.accountID)
    let resumed = try #require(reopened.sessionUploadQueue(accountID: session.accountID).first)
    #expect(resumed.isAuthenticationDeferred == false)
    #expect(resumed.retryAfter == nil)

    try reopened.rejectSessionUpload(
      sessionID: session.id, accountID: session.accountID, reason: .conflict
    )
    let rejected = try #require(reopened.sessionUploadQueue(accountID: session.accountID).first)
    #expect(rejected.upload.body == original.upload.body)
    #expect(rejected.permanentFailure == .conflict)
    #expect(try reopened.pendingSessionUploads(accountID: session.accountID).map(\.sessionID) == [session.id])
  }

  @Test
  func anEmptySessionCannotBeFinishedAsACompletedWorkout() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let session = makeSession()
    _ = try repository.start(session)
    #expect(throws: WorkoutRepositoryError.noCompletedSets) {
      try repository.finish(sessionID: session.id, accountID: session.accountID, note: nil)
    }
    #expect(try repository.activeSession(accountID: session.accountID)?.id == session.id)
  }

  @Test
  func recommendedEightWeeksDoNotBlockStartingWeekNine() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let cycleID = UUID()
    for week in 1...8 {
      let session = makeSession(cycleID: cycleID, week: week)
      _ = try repository.start(session)
      _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
        slotID: "slot-a", weightInput: "50", repsInput: "8")
      _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")
      _ = try repository.finish(sessionID: session.id, accountID: session.accountID, note: nil)
    }
    let weekNine = try repository.nextOccurrence(accountID: "account", cycleID: cycleID,
      programID: "program", workoutIDs: ["day-a"])
    #expect(weekNine.week == 9)
    _ = try repository.start(makeSession(cycleID: cycleID, week: 9))
    #expect(try repository.activeSession(accountID: "account")?.week == 9)
  }

  @Test
  func restCanBeReplacedAdjustedSkippedAndRecoveredFromItsDeadline() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let session = makeSession()
    _ = try repository.start(session)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
                                 slotID: "slot-a", weightInput: "40", repsInput: "8")
    let first = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
                                          slotID: "slot-a", restSeconds: 120, at: now)
    #expect(first.restDeadline == now.addingTimeInterval(120))

    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
                                 slotID: "slot-b", weightInput: "30", repsInput: "9")
    let second = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
                                           slotID: "slot-b", restSeconds: 180, at: now.addingTimeInterval(30))
    #expect(second.restDeadline == now.addingTimeInterval(210))
    let adjusted = try repository.adjustRest(sessionID: session.id, accountID: session.accountID,
                                            by: 15, at: now.addingTimeInterval(60))
    #expect(adjusted.restDeadline == now.addingTimeInterval(225))
    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try reopened.activeSession(accountID: session.accountID)?.restDeadline == now.addingTimeInterval(225))
    let reduced = try reopened.adjustRest(sessionID: session.id, accountID: session.accountID,
                                          by: -15, at: now.addingTimeInterval(200))
    #expect(reduced.restDeadline == now.addingTimeInterval(210))
    #expect(try reopened.skipRest(sessionID: session.id, accountID: session.accountID).restDeadline == nil)
  }

  @Test
  func restAdjustmentsCannotResurrectAnExpiredCountdown() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let session = makeSession()
    _ = try repository.start(session)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
                                 slotID: "slot-a", weightInput: "40", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
                                  slotID: "slot-a", restSeconds: 5, at: now)
    #expect(try repository.adjustRest(sessionID: session.id, accountID: session.accountID,
                                      by: 15, at: now.addingTimeInterval(10)).restDeadline == nil)
  }

  @Test
  func previousPerformancePrefersTheSameWorkoutAndOriginalSlot() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let repeatedWorkout = WorkoutTemplate(id: "day-a", name: "Day A", exercises: [
      WorkoutExercise(id: "slot-a", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12)),
      WorkoutExercise(id: "slot-b", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [repeatedWorkout])
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program,
      workout: repeatedWorkout, week: 1, day: 1, weightUnit: .pounds)
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: "account", slotID: "slot-a", weightInput: "40", repsInput: "9")
    _ = try repository.completeSet(sessionID: session.id, accountID: "account", slotID: "slot-a", at: Date(timeIntervalSince1970: 100))
    _ = try repository.saveDraft(sessionID: session.id, accountID: "account", slotID: "slot-b", weightInput: "80", repsInput: "10")
    _ = try repository.completeSet(sessionID: session.id, accountID: "account", slotID: "slot-b", at: Date(timeIntervalSince1970: 200))
    _ = try repository.finish(sessionID: session.id, accountID: "account", note: nil, at: Date(timeIntervalSince1970: 300))

    let result = try #require(try repository.previousPerformance(accountID: "account", exerciseKey: "row",
      slotID: "slot-a", programID: "program", workoutID: "day-a"))
    #expect(result.weightInput == "40")
    #expect(result.repsInput == "9")
    #expect(result.weightUnit == .pounds)
    #expect(result.isSameProgramWorkout)
  }

  @Test
  func previousPerformanceUsesLatestCompletedFallbackAndExcludesDraftsAndOtherAccounts() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let workout = WorkoutTemplate(id: "day-b", name: "Day B", exercises: [
      WorkoutExercise(id: "slot-row", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "other-program", name: "Other", format: "A", emphasis: "Strength", workouts: [workout])
    let finished = WorkoutSession(accountID: "account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1, weightUnit: .kilograms)
    _ = try repository.start(finished)
    _ = try repository.saveDraft(sessionID: finished.id, accountID: "account", slotID: "slot-row", weightInput: "65.5", repsInput: "11")
    _ = try repository.completeSet(sessionID: finished.id, accountID: "account", slotID: "slot-row")
    _ = try repository.finish(sessionID: finished.id, accountID: "account", note: nil, at: Date(timeIntervalSince1970: 500))

    let latestElsewhere = WorkoutSession(accountID: "account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1, weightUnit: .pounds)
    _ = try repository.start(latestElsewhere)
    _ = try repository.saveDraft(sessionID: latestElsewhere.id, accountID: "account", slotID: "slot-row", weightInput: "70.5", repsInput: "7")
    _ = try repository.completeSet(sessionID: latestElsewhere.id, accountID: "account", slotID: "slot-row")
    _ = try repository.finish(sessionID: latestElsewhere.id, accountID: "account", note: nil, at: Date(timeIntervalSince1970: 600))
    let unfinished = WorkoutSession(accountID: "account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1)
    _ = try repository.start(unfinished)
    _ = try repository.saveDraft(sessionID: unfinished.id, accountID: "account", slotID: "slot-row", weightInput: "99", repsInput: "12")
    let otherAccount = WorkoutSession(accountID: "another-account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1)
    _ = try repository.start(otherAccount)
    _ = try repository.saveDraft(sessionID: otherAccount.id, accountID: "another-account", slotID: "slot-row", weightInput: "120", repsInput: "12")
    _ = try repository.completeSet(sessionID: otherAccount.id, accountID: "another-account", slotID: "slot-row")
    _ = try repository.finish(sessionID: otherAccount.id, accountID: "another-account", note: nil, at: Date(timeIntervalSince1970: 700))

    let result = try #require(try repository.previousPerformance(accountID: "account", exerciseKey: "row",
      slotID: "slot-row", programID: "current-program", workoutID: "current-day"))
    #expect(result.weightInput == "70.5")
    #expect(result.repsInput == "7")
    #expect(result.weightUnit == .pounds)
    #expect(result.workoutName == "Day B")
    #expect(!result.isSameProgramWorkout)
  }

  @Test
  func restoredPreviousResultsPreferOlderSameWorkoutAndSurviveOfflineRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let workout = WorkoutTemplate(id: "day-a", name: "Day A", exercises: [
      WorkoutExercise(id: "slot-a", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let preferred = WorkoutRepository.PreviousPerformanceSnapshot(
      sessionID: UUID(), exerciseKey: "row", programID: "program", workoutID: "day-a", slotID: "slot-a",
      weightInput: "45.5", repsInput: "9", weightUnit: .kilograms,
      completedAt: Date(timeIntervalSince1970: 100), workoutName: "Captured Day A", week: 2, day: nil
    )
    let newerElsewhere = WorkoutRepository.PreviousPerformanceSnapshot(
      sessionID: UUID(), exerciseKey: "row", programID: "program", workoutID: "day-b", slotID: "slot-b",
      weightInput: "90", repsInput: "7", weightUnit: .pounds,
      completedAt: Date(timeIntervalSince1970: 200), workoutName: "Captured Day B", week: 3, day: nil
    )
    try repository.saveRestoredPreviousPerformances([preferred, newerElsewhere], accountID: "account")

    let restored = try WorkoutRepository(databaseURL: databaseURL)
    let result = try #require(try restored.previousPerformance(accountID: "account", exerciseKey: "row",
      slotID: "slot-a", programID: "program", workoutID: "day-a"))
    #expect(result.weightInput == "45.5")
    #expect(result.repsInput == "9")
    #expect(result.weightUnit == .kilograms)
    #expect(result.isSameProgramWorkout)
    #expect(try restored.previousPerformance(accountID: "another-account", exerciseKey: "row",
      slotID: "slot-a", programID: "program", workoutID: "day-a") == nil)
    #expect(try restored.pendingSessionUploads(accountID: "account").isEmpty)

    let local = WorkoutSession(accountID: "account", cycleID: UUID(), program: .init(
      id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout]
    ), workout: workout, week: 1, day: 1, weightUnit: .pounds,
       startedAt: Date(timeIntervalSince1970: 300))
    _ = try restored.start(local)
    _ = try restored.saveDraft(sessionID: local.id, accountID: "account", slotID: "slot-a",
      weightInput: "50", repsInput: "10")
    _ = try restored.completeSet(sessionID: local.id, accountID: "account", slotID: "slot-a",
      at: Date(timeIntervalSince1970: 310))
    _ = try restored.finish(sessionID: local.id, accountID: "account", note: nil,
      at: Date(timeIntervalSince1970: 320))
    let localWins = try #require(try restored.previousPerformance(accountID: "account", exerciseKey: "row",
      slotID: "slot-a", programID: "program", workoutID: "day-a"))
    #expect(localWins.weightInput == "50")
    #expect(localWins.weightUnit == .pounds)
  }

  @Test
  func capturedExerciseProvidesDoubleProgressionAndWarmupGuidanceWithoutInventingLoads() throws {
    let exercise = try #require(makeSession().exercises.first)
    #expect(exercise.progressionGuidance(for: "8")?.contains("aim for more reps with good form") == true)
    #expect(exercise.progressionGuidance(for: "12")?.contains("add a small amount of weight") == true)
    #expect(exercise.progressionGuidance(for: "") == nil)
    let ranges = exercise.warmupRanges(for: "100")
    #expect(ranges.count == 3)
    #expect(ranges[0].minimumLoad == 40)
    #expect(ranges[0].maximumLoad == 50)
    #expect(exercise.warmupRanges(for: "NaN").isEmpty)
    #expect(exercise.warmupRanges(for: "0").isEmpty)
  }

  private func makeSession(cycleID: UUID = UUID(), week: Int = 1,
                           startedAt: Date = .now,
                           weightUnit: WeightUnit = .pounds,
                           accountID: String = "account",
                           id: UUID = UUID()) -> WorkoutSession {
    let workout = WorkoutTemplate(id: "day-a", name: "Day A", exercises: [
      WorkoutExercise(id: "slot-a", exerciseKey: "row", name: "Row",
                      repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachSide),
                      instructions: "Row with control.", stoppingGuidance: "Stop when form breaks.",
                      warmupGuidance: "Warm up gradually.", restSeconds: 120, videoKey: "row/demo.mp4"),
      WorkoutExercise(id: "slot-b", exerciseKey: "press", name: "Press",
                      repTarget: RepTarget(minimum: 8, maximum: 12),
                      instructions: "Press with control.", stoppingGuidance: "Stop when form breaks.",
                      warmupGuidance: "Warm up gradually.")
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A/B", emphasis: "Strength", workouts: [workout])
    return WorkoutSession(accountID: accountID, cycleID: cycleID, program: program,
                          workout: workout, week: week, day: 1, weightUnit: weightUnit,
                          startedAt: startedAt, id: id)
  }

  private func makeLegacyFinishedSession(
    cycleID: UUID,
    week: Int,
    startedAt: Date,
    finishedAt: Date,
    note: String?,
    completed: Bool = true
  ) -> WorkoutSession {
    let workout = WorkoutTemplate(id: "day-a", name: "Day A", exercises: [
      WorkoutExercise(id: "removed-slot", exerciseKey: "removed-row", name: "Removed Row Variation",
        repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachSide),
        instructions: "Instructions captured before the catalog changed.",
        stoppingGuidance: "Stop at technical failure.", warmupGuidance: "Warm up progressively.",
        restSeconds: 150, videoKey: "row/legacy-demo.mp4"),
      WorkoutExercise(id: "slot-b", exerciseKey: "press", name: "Press",
        repTarget: RepTarget(minimum: 8, maximum: 12),
        instructions: "Captured press guidance.", stoppingGuidance: "Stop at technical failure.",
        warmupGuidance: "Warm up progressively.")
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A/B",
      emphasis: "Strength", workouts: [workout])
    var session = WorkoutSession(accountID: "account", cycleID: cycleID, program: program,
      workout: workout, week: week, day: 1, weightUnit: .pounds, startedAt: startedAt)
    if completed {
      session.setEntries["removed-slot"] = .init(weightInput: "72.5", repsInput: "10",
        completedAt: startedAt.addingTimeInterval(1_800))
      session.setEntries["slot-b"] = .init(weightInput: "unperformed draft", repsInput: "",
        completedAt: nil)
    }
    session.finishedAt = finishedAt
    session.note = note
    return session
  }

  private func makePreUploadStore(databaseURL: URL, sessions: [WorkoutSession]) throws {
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let database = try DatabaseQueue(path: databaseURL.path)
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
    try database.write { db in
      for session in sessions {
        let payload = try JSONEncoder().encode(session)
        try db.execute(sql: """
          INSERT INTO workout_sessions
            (id, account_id, cycle_id, program_id, week, workout_id, day, started_at, payload, finished_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          """, arguments: [session.id.uuidString, session.accountID, session.cycleID.uuidString,
            session.programID, session.week, session.workoutID, session.day,
            session.startedAt.timeIntervalSince1970, payload,
            session.finishedAt?.timeIntervalSince1970])
      }
    }
  }
}
