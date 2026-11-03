import Foundation
import Testing
@testable import OneSet

@MainActor
struct HistoryModelTests {
  @Test
  func historyKeepsCapturedResultsAndConvertsOnlyForDisplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let workout = WorkoutTemplate(id: "captured-day", name: "Captured Day", exercises: [
      WorkoutExercise(id: "slot-row", exerciseKey: "row", name: "Captured Row",
        repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachSide)),
      WorkoutExercise(id: "slot-press", exerciseKey: "press", name: "Captured Press",
        repTarget: RepTarget(minimum: 8, maximum: 12)),
    ])
    let program = TrainingProgram(id: "removed-program", name: "Old Program", format: "A",
      emphasis: "Strength", workouts: [workout])
    let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let session = WorkoutSession(accountID: "history-account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1, weightUnit: .pounds, startedAt: startedAt)
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-row", weightInput: "100", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-row", at: startedAt.addingTimeInterval(600))
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-press", weightInput: "999", repsInput: "draft")
    let finished = try repository.finish(sessionID: session.id, accountID: session.accountID,
      note: "Captured note", at: startedAt.addingTimeInterval(3_600))

    let reopened = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let model = HistoryModel(
      accountID: "history-account",
      displayUnit: .kilograms,
      loadSessions: { try reopened.completedSessions(accountID: $0) },
      resolveProgramName: { _ in nil }
    )
    await model.reload()

    #expect(model.sessions.map(\.id) == [session.id])
    let historySession = try #require(model.session(id: session.id))
    let rowResult = try #require(historySession.setEntries["slot-row"])
    #expect(model.completedExerciseCount(for: historySession) == 1)
    let converted = Measurement(value: 100, unit: UnitMass.pounds).converted(to: .kilograms).value
      .formatted(.number.precision(.fractionLength(0...2)))
    #expect(model.formattedWeight(rowResult, in: historySession) == "\(converted) kg")
    #expect(model.programName(for: historySession) == "Unavailable program")
    #expect(model.months().count == 1)
    #expect(historySession.note == "Captured note")
    #expect(historySession.setEntries["slot-press"]?.weightInput == "999")
  }

  @Test
  func localReadFailureIsNotReportedAsAnEmptyHistory() async {
    let model = HistoryModel(
      accountID: "account",
      displayUnit: .kilograms,
      loadSessions: { _ in throw HistoryDataError.storageUnavailable },
      resolveProgramName: { _ in nil }
    )

    await model.reload()

    #expect(model.sessions.isEmpty)
    #expect(model.loadError != nil)
  }

  @Test
  func downloadedPagesPersistSessionsAndCoverageWithoutQueueingUploads() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let program = try #require(ProgramCatalog.bundled.program(id: "machine-full-body"))
    let workout = try #require(program.workouts.first)
    let importedID = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
    let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let imported = WorkoutSession(
      id: importedID, accountID: "history-account", cycleID: UUID(), programID: program.id,
      resolvedProgramName: "Captured program", week: 4, workoutID: workout.id, dayNumber: 2,
      workoutName: workout.name, startedAt: startedAt, finishedAt: startedAt.addingTimeInterval(600),
      note: "Downloaded note", exercises: workout.exercises.enumerated().map { .init(slot: $0.element, order: $0.offset) },
      setEntries: [workout.exercises[0].id: .init(weightInput: "50", repsInput: "8", completedAt: startedAt.addingTimeInterval(500), recordedWeightUnit: .pounds)],
      weightUnit: .pounds
    )

    try repository.saveHistoryPage(
      SessionHistoryPage(sessions: [imported], nextCursor: "page-2", hasMore: true),
      accountID: "history-account"
    )
    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try reopened.completedSessions(accountID: "history-account").map(\.id) == [importedID])
    #expect(try reopened.historyCoverage(accountID: "history-account") ==
      SessionHistoryCoverage(nextCursor: "page-2", hasMore: true, hasLoadedPage: true))
    #expect(try reopened.pendingSessionUploads(accountID: "history-account").isEmpty)
    #expect(try reopened.completedSessions(accountID: "another-account").isEmpty)
    let saved = try #require(reopened.completedSessions(accountID: "history-account").first)
    #expect(saved.historicalDayNumber == 2)
    #expect(saved.resolvedProgramName == "Captured program")
    #expect(saved.note == "Downloaded note")

    try reopened.saveHistoryPage(
      SessionHistoryPage(sessions: [], nextCursor: nil, hasMore: false), accountID: "history-account"
    )
    #expect(try reopened.historyCoverage(accountID: "history-account") ==
      SessionHistoryCoverage(nextCursor: nil, hasMore: false, hasLoadedPage: true))
  }
}
