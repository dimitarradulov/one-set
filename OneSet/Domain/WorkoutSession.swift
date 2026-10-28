import Foundation

struct WorkoutSession: Codable, Hashable, Identifiable, Sendable {
  struct SetEntry: Codable, Hashable, Sendable {
    var weightInput: String
    var repsInput: String
    var completedAt: Date?

    init(weightInput: String = "", repsInput: String = "", completedAt: Date? = nil) {
      self.weightInput = weightInput
      self.repsInput = repsInput
      self.completedAt = completedAt
    }
  }
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
  let weightUnit: WeightUnit
  let exercises: [Exercise]
  var setEntries: [String: SetEntry]
  var restDeadline: Date?

  init(accountID: String, cycleID: UUID, program: TrainingProgram, workout: WorkoutTemplate,
       week: Int, day: Int, weightUnit: WeightUnit = .kilograms, startedAt: Date = .now, id: UUID = UUID()) {
    self.id = id
    self.accountID = accountID
    self.cycleID = cycleID
    programID = program.id
    self.week = week
    workoutID = workout.id
    self.day = day
    workoutName = workout.name
    self.startedAt = startedAt
    self.weightUnit = weightUnit
    exercises = workout.exercises.enumerated().map { Exercise(slot: $0.element, order: $0.offset) }
    setEntries = [:]
    restDeadline = nil
  }

  private enum CodingKeys: String, CodingKey {
    case id, accountID, cycleID, programID, week, workoutID, day, workoutName, startedAt
    case weightUnit, exercises, setEntries, restDeadline
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    accountID = try values.decode(String.self, forKey: .accountID)
    cycleID = try values.decode(UUID.self, forKey: .cycleID)
    programID = try values.decode(String.self, forKey: .programID)
    week = try values.decode(Int.self, forKey: .week)
    workoutID = try values.decode(String.self, forKey: .workoutID)
    day = try values.decode(Int.self, forKey: .day)
    workoutName = try values.decode(String.self, forKey: .workoutName)
    startedAt = try values.decode(Date.self, forKey: .startedAt)
    weightUnit = try values.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kilograms
    exercises = try values.decode([Exercise].self, forKey: .exercises)
    setEntries = try values.decodeIfPresent([String: SetEntry].self, forKey: .setEntries) ?? [:]
    restDeadline = try values.decodeIfPresent(Date.self, forKey: .restDeadline)
  }
}
