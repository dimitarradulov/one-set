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
      workout: workout, week: 3, day: 2, weightUnit: .pounds, startedAt: startedAt)
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
    #expect(model.formattedWeight(rowResult, in: historySession) == "45.36 kg")
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
}
