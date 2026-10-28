import Foundation

struct WorkoutSession: Codable, Hashable, Identifiable, Sendable {
  struct Exercise: Codable, Hashable, Sendable {
    let slotID: String
    let exerciseKey: String
    let name: String
    let order: Int
    let repTarget: RepTarget
    let instructions: String
    let stoppingGuidance: String
    let warmupGuidance: String
    let restSeconds: Int?

    init(slot: WorkoutExercise, order: Int) {
      slotID = slot.id
      exerciseKey = slot.exerciseKey
      name = slot.name
      self.order = order
      repTarget = slot.repTarget
      instructions = slot.instructions
      stoppingGuidance = slot.stoppingGuidance
      warmupGuidance = slot.warmupGuidance
      restSeconds = slot.restSeconds
    }
  }

  let id: UUID
  let accountID: String
  let cycleID: UUID
  let programID: String
  let week: Int
  let workoutID: String
  let day: Int
  let workoutName: String
  let startedAt: Date
  let exercises: [Exercise]

  init(accountID: String, cycleID: UUID, program: TrainingProgram, workout: WorkoutTemplate,
       week: Int, day: Int, startedAt: Date = .now, id: UUID = UUID()) {
    self.id = id
    self.accountID = accountID
    self.cycleID = cycleID
    programID = program.id
    self.week = week
    workoutID = workout.id
    self.day = day
    workoutName = workout.name
    self.startedAt = startedAt
    exercises = workout.exercises.enumerated().map { Exercise(slot: $0.element, order: $0.offset) }
  }
}
