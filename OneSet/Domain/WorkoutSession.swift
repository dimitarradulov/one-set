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
    struct WarmupRange: Hashable, Sendable {
      let minimumLoad: Double
      let maximumLoad: Double
      let reps: ClosedRange<Int>
    }

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

    func progressionGuidance(for repsInput: String) -> String? {
      guard let reps = Int(repsInput), reps > 0 else { return nil }
      if reps >= repTarget.maximum {
        return "If those reps were clean, try the smallest practical load increase next time."
      }
      return "Keep the same load and aim for more clean reps within \(repTarget.minimum)–\(repTarget.maximum)."
    }

    func warmupRanges(for workingWeightInput: String) -> [WarmupRange] {
      guard let weight = Double(workingWeightInput), weight.isFinite, weight > 0 else { return [] }
      return [
        WarmupRange(minimumLoad: weight * 0.40, maximumLoad: weight * 0.50, reps: 6...8),
        WarmupRange(minimumLoad: weight * 0.65, maximumLoad: weight * 0.70, reps: 3...5),
        WarmupRange(minimumLoad: weight * 0.80, maximumLoad: weight * 0.85, reps: 1...3)
      ]
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
  var finishedAt: Date?
  var note: String?
  let requiredWorkoutIDs: [String]

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
    finishedAt = nil
    note = nil
    requiredWorkoutIDs = program.workouts.map(\.id)
  }

  private enum CodingKeys: String, CodingKey {
    case id, accountID, cycleID, programID, week, workoutID, day, workoutName, startedAt
    case weightUnit, exercises, setEntries, restDeadline, finishedAt, note, requiredWorkoutIDs
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
    finishedAt = try values.decodeIfPresent(Date.self, forKey: .finishedAt)
    note = try values.decodeIfPresent(String.self, forKey: .note)
    requiredWorkoutIDs = try values.decodeIfPresent([String].self, forKey: .requiredWorkoutIDs) ?? [workoutID]
  }
}
