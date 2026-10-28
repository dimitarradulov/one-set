import Foundation
import Testing
@testable import OneSet

@MainActor
struct WorkoutRepositorySetTests {
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
  func capturedExerciseProvidesDoubleProgressionAndWarmupGuidanceWithoutInventingLoads() throws {
    let exercise = try #require(makeSession().exercises.first)
    #expect(exercise.progressionGuidance(for: "8")?.contains("aim for more clean reps") == true)
    #expect(exercise.progressionGuidance(for: "12")?.contains("smallest practical load increase") == true)
    #expect(exercise.progressionGuidance(for: "") == nil)
    let ranges = exercise.warmupRanges(for: "100")
    #expect(ranges.count == 3)
    #expect(ranges[0].minimumLoad == 40)
    #expect(ranges[0].maximumLoad == 50)
    #expect(exercise.warmupRanges(for: "NaN").isEmpty)
    #expect(exercise.warmupRanges(for: "0").isEmpty)
  }

  private func makeSession() -> WorkoutSession {
    let workout = WorkoutTemplate(id: "day-a", name: "Day A", exercises: [
      WorkoutExercise(id: "slot-a", exerciseKey: "row", name: "Row",
                      repTarget: RepTarget(minimum: 8, maximum: 12), restSeconds: 120),
      WorkoutExercise(id: "slot-b", exerciseKey: "press", name: "Press",
                      repTarget: RepTarget(minimum: 8, maximum: 12))
    ])
    let program = TrainingProgram(id: "program", name: "Program", format: "A/B", emphasis: "Strength", workouts: [workout])
    return WorkoutSession(accountID: "account", cycleID: UUID(), program: program,
                          workout: workout, week: 1, day: 1, weightUnit: .pounds)
  }
}
