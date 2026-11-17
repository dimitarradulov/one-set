import Foundation
import GRDB
import Testing
@testable import OneSet

extension WorkoutRepositorySetTests {
  @Test(arguments: [false, true])
  func logsBothMembersAndRecoversRestBelowSecondSlot(reverse: Bool) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let slots = ["previous", "upper", "lower", "next"].map {
      WorkoutExercise(id: $0, exerciseKey: $0, name: $0, repTarget: .init(minimum: 8, maximum: 12))
    }
    let workout = WorkoutTemplate(id: "day", name: "Workout", exercises: slots,
      supersets: [.init(firstSlotID: "upper", secondSlotID: "lower")])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout, week: 1, day: 1)
    _ = try repository.start(session)
    for slot in slots {
      _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
        slotID: slot.id, weightInput: "20", repsInput: "8")
    }
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let first = reverse ? "lower" : "upper"
    let second = reverse ? "upper" : "lower"
    func complete(_ slot: String, seconds: TimeInterval, in storage: WorkoutRepository) throws -> WorkoutSession {
      try storage.completeSet(sessionID: session.id, accountID: session.accountID, slotID: slot,
        restSeconds: 120, at: start.addingTimeInterval(seconds))
    }

    _ = try complete("previous", seconds: 0, in: repository)
    let partial = try complete(first, seconds: 10, in: repository)
    #expect(partial.restSlotID == "previous")
    #expect(partial.restDeadline == start.addingTimeInterval(120))

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let paired = try complete(second, seconds: 20, in: reopened)
    #expect(paired.restSlotID == "lower")
    #expect(paired.restDeadline == start.addingTimeInterval(200))
    let restored = try #require(try reopened.activeSession(accountID: session.accountID))
    #expect(restored.restSlotID == "lower")
    #expect(restored.restDeadline == paired.restDeadline)
    #expect(try complete(second, seconds: 30, in: reopened).restDeadline == paired.restDeadline)

    let undone = try reopened.unmarkSet(sessionID: session.id, accountID: session.accountID, slotID: first)
    #expect(undone.restDeadline == nil)
    #expect(try complete(first, seconds: 40, in: reopened).restDeadline == start.addingTimeInterval(220))
  }

  @Test(arguments: [false, true])
  func pairHasNoRestWhenLastOrAllRowsAreComplete(lastPair: Bool) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let slotIDs = lastPair ? ["before", "upper", "lower"] : ["upper", "lower", "after"]
    let slots = slotIDs.map {
      WorkoutExercise(id: $0, exerciseKey: $0, name: $0, repTarget: .init(minimum: 8, maximum: 12))
    }
    let workout = WorkoutTemplate(id: "day", name: "Workout", exercises: slots,
      supersets: [.init(firstSlotID: "upper", secondSlotID: "lower")])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout, week: 1, day: 1)
    _ = try repository.start(session)
    for slotID in (lastPair ? ["upper", "lower"] : ["after", "upper", "lower"]) {
      _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
        slotID: slotID, weightInput: "20", repsInput: "8")
      _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: slotID)
    }
    let completed = try #require(try repository.activeSession(accountID: session.accountID))
    #expect(completed.restSlotID == nil)
    #expect(completed.restDeadline == nil)
  }

  @Test
  func failedFinishRollsBackRememberedReplacementAndRetryCommitsOnce() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: url)
    let row = WorkoutExercise(id: "slot-a", exerciseKey: "row", name: "Row", repTarget: .init(minimum: 8, maximum: 12))
    let workout = WorkoutTemplate(id: "day", name: "Workout", exercises: [row])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout, week: 1, day: 1)
    let replacement = WorkoutExercise(exerciseKey: "fly", name: "Fly", repTarget: .init(minimum: 8, maximum: 12))
    _ = try repository.start(session)
    _ = try repository.replaceExercise(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", with: replacement)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "slot-a", weightInput: "20", repsInput: "10")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "slot-a")

    let probe = try DatabaseQueue(path: url.path)
    try probe.write { db in
      try db.execute(sql: """
        CREATE TRIGGER fail_remembered_finish BEFORE INSERT ON completed_session_uploads
        BEGIN SELECT RAISE(ABORT, 'upload queue unavailable'); END
        """)
    }

    #expect(throws: (any Error).self) {
      try repository.finish(sessionID: session.id, accountID: session.accountID,
        note: nil, rememberSubstitutions: true)
    }
    let reopened = try WorkoutRepository(databaseURL: url)
    #expect(try reopened.activeSession(accountID: session.accountID)?.newSubstitutions.first?.exerciseKey == "fly")
    #expect(try reopened.pendingSessionUploads(accountID: session.accountID).isEmpty)
    #expect(try probe.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM remembered_workout_exercises") } == 0)

    try probe.write { db in try db.execute(sql: "DROP TRIGGER fail_remembered_finish") }
    for _ in 0..<2 {
      _ = try reopened.finish(sessionID: session.id, accountID: session.accountID,
        note: nil, rememberSubstitutions: true)
    }
    #expect(try reopened.pendingSessionUploads(accountID: session.accountID).count == 1)
    #expect(try probe.read { db in
      try String.fetchAll(db, sql: "SELECT exercise_key FROM remembered_workout_exercises")
    } == ["fly"])
  }

  @Test(arguments: [false, true])
  func replacementRetainsPairAndUsesTheActualExerciseInHistory(remember: Bool) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let row = WorkoutExercise(id: "upper", exerciseKey: "row", name: "Row",
      repTarget: .init(minimum: 8, maximum: 12))
    let press = WorkoutExercise(id: "lower", exerciseKey: "press", name: "Press",
      repTarget: .init(minimum: 8, maximum: 12))
    let fly = WorkoutExercise(id: "fly", exerciseKey: "fly", name: "Fly", repTarget: .init(minimum: 12, maximum: 15),
      warmupGuidance: "Warm up lightly.", restSeconds: 120)
    let pair = SupersetPair(firstSlotID: "upper", secondSlotID: "lower")
    let workout = WorkoutTemplate(id: "day", name: "Workout", exercises: [row, press], supersets: [pair])
    let program = TrainingProgram(id: "program", name: "Program", format: "A", emphasis: "Strength", workouts: [workout])
    let session = WorkoutSession(accountID: "account", cycleID: UUID(), program: program, workout: workout, week: 1, day: 1)
    _ = try repository.start(session)
    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "lower", weightInput: "60", repsInput: "8")
    let substituted = try repository.replaceExercise(sessionID: session.id, accountID: session.accountID,
      slotID: "lower", with: fly)
    #expect(substituted.supersets == [pair])
    #expect(substituted.exercises[1].exerciseKey == "fly")
    #expect(substituted.exercises[1].warmupGuidance == "Warm up lightly.")
    #expect(substituted.exercises[1].repTarget.label == "12–15 reps")
    #expect(substituted.setEntries["lower"] == nil)

    _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
      slotID: "lower", weightInput: "10", repsInput: "13")
    _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID, slotID: "lower")
    let finished = try repository.finish(sessionID: session.id, accountID: session.accountID,
      note: nil, rememberSubstitutions: remember)
    #expect(finished.setEntries["upper"]?.completedAt == nil)
    #expect(finished.setEntries["lower"]?.completedAt != nil)
    #expect(finished.supersets == [pair])

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let actual = try reopened.previousPerformance(accountID: session.accountID, exerciseKey: "fly",
      slotID: "lower", programID: program.id, workoutID: workout.id)
    #expect(actual?.repsInput == "13")
    #expect(try reopened.previousPerformance(accountID: session.accountID, exerciseKey: "press",
      slotID: "lower", programID: program.id, workoutID: workout.id) == nil)

    let nextCycle = WorkoutSession(accountID: session.accountID, cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1)
    let next = try reopened.start(nextCycle, exerciseLibrary: ["fly": fly])
    #expect(next.supersets == [pair])
    #expect(next.exercises[1].exerciseKey == (remember ? "fly" : "press"))
    #expect(next.newSubstitutions.isEmpty)

    let otherAccount = WorkoutSession(accountID: "other-account", cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1)
    #expect(try reopened.start(otherAccount, exerciseLibrary: ["fly": fly]).exercises[1].exerciseKey == "press")

    try reopened.discard(sessionID: next.id, accountID: next.accountID)
    let otherProgram = TrainingProgram(id: "other-program", name: "Another program", format: "A",
      emphasis: "Strength", workouts: [workout])
    let anotherProgram = WorkoutSession(accountID: session.accountID, cycleID: UUID(),
      program: otherProgram, workout: workout, week: 1, day: 1)
    #expect(try reopened.start(anotherProgram, exerciseLibrary: ["fly": fly]).exercises[1].exerciseKey == "press")
  }
}
