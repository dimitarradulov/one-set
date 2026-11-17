import Foundation
import Testing
@testable import OneSet

@MainActor
struct AlternatingTrainingWeeksTests {
  @Test
  func bundledRotationAdvancesAfterTwoWorkoutsAndRepeats() throws {
    let program = try #require(ProgramCatalog.bundled.program(id: "hit-upper-lower-rotation"))
    #expect(program.trainingDaysPerWeek == 2)
    #expect(program.workouts.count == 4)
    #expect(program.workouts(inWeek: 1).map(\.name) == ["Chest & Back", "Legs"])
    #expect(program.workouts(inWeek: 2).map(\.name) == ["Delts & Arms", "Legs (Advanced Emphasis)"])
    #expect(program.workouts.allSatisfy { $0.supersets?.count == 1 })

    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "workouts.sqlite")
    let cycleID = UUID()
    let accountID = "rotation-test"
    for week in 1...2 {
      let repository = try WorkoutRepository(databaseURL: url)
      for (index, workout) in program.workouts(inWeek: week).enumerated() {
        let session = WorkoutSession(accountID: accountID, cycleID: cycleID, program: program,
          workout: workout, week: week, day: index + 1, weightUnit: .kilograms)
        let active = try repository.start(session)
        #expect(active.supersets == workout.supersets)
        let slot = try #require(active.exercises.first?.slotID)
        _ = try repository.saveDraft(sessionID: active.id, accountID: accountID,
          slotID: slot, weightInput: "40", repsInput: "8")
        _ = try repository.completeSet(sessionID: active.id, accountID: accountID, slotID: slot)
        _ = try repository.finish(sessionID: active.id, accountID: accountID, note: nil)
      }
    }
    let next = try WorkoutRepository(databaseURL: url).nextOccurrence(
      accountID: accountID, cycleID: cycleID, programID: program.id,
      workoutIDs: program.workouts(inWeek: 1).map(\.id), evenWeekWorkoutIDs: program.evenWeekWorkoutIDs
    )
    #expect(next.week == 3)
    #expect(next.day == 1)
    #expect(next.workoutID == "hit-upper-lower-rotation-chest-back")
  }
}
