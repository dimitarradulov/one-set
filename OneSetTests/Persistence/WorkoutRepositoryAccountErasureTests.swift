import Foundation
import GRDB
import Testing
@testable import OneSet

@MainActor
struct WorkoutRepositoryAccountErasureTests {
  private let cycleID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!

  private func makeDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString).appending(path: "workouts.sqlite")
  }

  /// Seeds every kind of local data the repository keeps for one account.
  private func seed(_ repository: WorkoutRepository, accountID: String) throws {
    let program = try #require(ProgramCatalog.bundled.program(id: "machine-full-body"))
    let workout = program.workouts[0]
    let slot = try #require(workout.exercises.first)
    let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let session = WorkoutSession(
      accountID: accountID, cycleID: cycleID, program: program, workout: workout,
      week: 1, day: 1, weightUnit: .kilograms, startedAt: startedAt
    )
    _ = try repository.start(session)
    _ = try repository.saveDraft(
      sessionID: session.id, accountID: accountID, slotID: slot.id, weightInput: "50", repsInput: "8"
    )
    _ = try repository.completeSet(
      sessionID: session.id, accountID: accountID, slotID: slot.id, at: startedAt.addingTimeInterval(10)
    )
    _ = try repository.finish(
      sessionID: session.id, accountID: accountID, note: nil, at: startedAt.addingTimeInterval(20)
    )
    let required = program.workouts.map(\.id)
    try repository.restoreProgress(
      AccountProgress(
        cycleID: cycleID, programID: program.id, currentTrainingWeek: 3,
        completedOccurrences: [.init(weekNumber: 3, workoutID: required[0])],
        workoutPeriods: required.map { .init(workoutID: $0, startsWeek: 1, endsWeek: nil) },
        requiredWorkoutIDs: required
      ),
      accountID: accountID
    )
    try repository.saveHistoryPage(
      SessionHistoryPage(sessions: [], nextCursor: "cursor", hasMore: true), accountID: accountID
    )
    try repository.saveRestoredPreviousPerformances([], accountID: accountID)
    _ = try repository.blockSessionUploadsForSetupCycle(
      accountID: accountID, cycleID: cycleID, establishedCycleID: UUID()
    )
  }

  /// Counts the account's rows in every table that has an `account_id` column, so a table added
  /// later is covered without changing this test.
  private func rowCounts(databaseURL: URL, accountID: String) throws -> [String: Int] {
    let database = try DatabaseQueue(path: databaseURL.path)
    return try database.read { db in
      var counts: [String: Int] = [:]
      for table in try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'") {
        guard try db.columns(in: table).contains(where: { $0.name == "account_id" }) else { continue }
        counts[table] = try Int.fetchOne(
          db, sql: "SELECT COUNT(*) FROM \"\(table)\" WHERE account_id = ?", arguments: [accountID]
        ) ?? 0
      }
      return counts
    }
  }

  @Test
  func eraseRemovesEveryRowForTheAccountAndLeavesOthersUnchanged() throws {
    let url = makeDatabaseURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repository = try WorkoutRepository(databaseURL: url)
    try seed(repository, accountID: "erased")
    try seed(repository, accountID: "kept")
    let before = try rowCounts(databaseURL: url, accountID: "erased")
    let keptBefore = try rowCounts(databaseURL: url, accountID: "kept")
    #expect(before["workout_sessions", default: 0] > 0)
    #expect(before["completed_session_uploads", default: 0] > 0)
    #expect(before["restored_cycle_progress", default: 0] > 0)
    #expect(before["restored_previous_performance", default: 0] > 0)
    #expect(before["account_history_coverage", default: 0] > 0)

    try repository.eraseAccount(accountID: "erased")

    #expect(try rowCounts(databaseURL: url, accountID: "erased").values.allSatisfy { $0 == 0 })
    #expect(try rowCounts(databaseURL: url, accountID: "kept") == keptBefore)
    #expect(try repository.sessionUploadQueue(accountID: "erased").isEmpty)
    #expect(try repository.completedSessions(accountID: "erased").isEmpty)
    #expect(try repository.sessionUploadQueue(accountID: "kept").count == 1)
  }

  @Test
  func eraseIsSafeForAnUnknownAccountAndWhenRepeated() throws {
    let url = makeDatabaseURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let repository = try WorkoutRepository(databaseURL: url)
    try seed(repository, accountID: "kept")
    let keptBefore = try rowCounts(databaseURL: url, accountID: "kept")

    try repository.eraseAccount(accountID: "nobody")
    try repository.eraseAccount(accountID: "nobody")

    #expect(try rowCounts(databaseURL: url, accountID: "kept") == keptBefore)
  }
}
