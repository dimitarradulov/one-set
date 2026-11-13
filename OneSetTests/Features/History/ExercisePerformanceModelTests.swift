import Foundation
import Testing
@testable import OneSet

@MainActor
struct ExercisePerformanceModelTests {
  @Test
  func mergesPagesWithLocalSessionsAndCalculatesRecords() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let workout = WorkoutTemplate(id: "day", name: "Day", exercises: [
      WorkoutExercise(id: "row", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12)),
      WorkoutExercise(id: "other", exerciseKey: "other", name: "Other", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    var local = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout,
      week: 1, day: 1, weightUnit: .kilograms, startedAt: date)
    local.setEntries["row"] = .init(weightInput: "100", repsInput: "8", completedAt: date, recordedWeightUnit: .kilograms)
    local.finishedAt = date
    var remote = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout,
      week: 1, day: 1, weightUnit: .pounds, startedAt: date.addingTimeInterval(-100))
    remote.setEntries["row"] = .init(weightInput: "220.462262", repsInput: "12", completedAt: date.addingTimeInterval(-100), recordedWeightUnit: .pounds)
    remote.finishedAt = date
    var draft = local
    draft.finishedAt = nil
    let model = ExercisePerformanceModel(exerciseKey: "row", unit: .kilograms,
      loadLocal: { [local, draft] }, fetchPage: { cursor in
        cursor == nil ? SessionHistoryPage(sessions: [local], nextCursor: "next", hasMore: true)
          : SessionHistoryPage(sessions: [remote], nextCursor: nil, hasMore: false)
      }, isCurrent: { true })
    await model.reload()
    #expect(model.results.count == 2)
    #expect(model.results.first?.session.id == local.id)
    #expect(abs((model.heaviest?.weight ?? 0) - 100) < 0.001)
    #expect(abs((model.estimatedMaximum ?? 0) - (100 * (1 + 8.0 / 30))) < 0.001)
    #expect(model.error == nil)
  }

  @Test
  func pendingLocalSessionRemainsVisibleWhenServerHasNotReceivedIt() async {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let workout = WorkoutTemplate(id: "day", name: "Day", exercises: [
      WorkoutExercise(id: "row", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    var local = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout,
      week: 1, day: 1, startedAt: date)
    local.setEntries["row"] = .init(weightInput: "75", repsInput: "8", completedAt: date)
    local.finishedAt = date
    let model = ExercisePerformanceModel(exerciseKey: "row", unit: .kilograms,
      loadLocal: { [local] }, fetchPage: { _ in
        SessionHistoryPage(sessions: [], nextCursor: nil, hasMore: false)
      }, pendingIDs: { [local.id] }, isCurrent: { true })
    await model.reload()
    #expect(model.results.first?.session.id == local.id)
    #expect(model.results.first?.weight == 75)
  }

  @Test
  func cachingServerResultsPreservesPendingLocalSessionAndHistoryCursor() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let workout = WorkoutTemplate(id: "day", name: "Day", exercises: [
      WorkoutExercise(id: "row", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout,
      week: 1, day: 1, startedAt: date)
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: "account", slotID: "row", weightInput: "75", repsInput: "8")
    _ = try repository.completeSet(sessionID: session.id, accountID: "account", slotID: "row", at: date)
    let finished = try repository.finish(sessionID: session.id, accountID: "account", note: nil, at: date)
    var stale = finished
    stale.setEntries["row"] = .init(weightInput: "10", repsInput: "1", completedAt: date)
    try repository.cacheHistorySessions([stale], accountID: "account")
    let cached = try #require(repository.completedSessions(accountID: "account").first)
    #expect(cached.setEntries["row"]?.weightInput == "75")
    #expect(try repository.historyCoverage(accountID: "account").hasLoadedPage == false)
    #expect(try repository.completedSessions(accountID: "other").isEmpty)
  }

  @Test
  func networkFailureKeepsLocalResultsAndReportsIncompleteHistory() async {
    let model = ExercisePerformanceModel(exerciseKey: "row", unit: .kilograms,
      loadLocal: { [] }, fetchPage: { _ in throw URLError(.notConnectedToInternet) }, isCurrent: { true })
    await model.reload()
    #expect(model.results.isEmpty)
    #expect(model.error != nil)
  }
}
