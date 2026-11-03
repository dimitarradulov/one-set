import Foundation

struct WorkoutSession: Codable, Hashable, Identifiable, Sendable {
  struct SetEntry: Codable, Hashable, Sendable {
    var weightInput: String
    var repsInput: String
    var completedAt: Date?
    var recordedWeightUnit: WeightUnit?

    init(
      weightInput: String = "", repsInput: String = "", completedAt: Date? = nil,
      recordedWeightUnit: WeightUnit? = nil
    ) {
      self.weightInput = weightInput
      self.repsInput = repsInput
      self.completedAt = completedAt
      self.recordedWeightUnit = recordedWeightUnit
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
    let warmupSteps: [String]
    let restSeconds: Int?
    let videoKey: String?

    init(slot: WorkoutExercise, order: Int) {
      self.init(
        slotID: slot.id, exerciseKey: slot.exerciseKey, name: slot.name, order: order,
        repTarget: slot.repTarget, instructions: slot.instructions,
        stoppingGuidance: slot.stoppingGuidance, warmupGuidance: slot.warmupGuidance,
        warmupSteps: [],
        restSeconds: slot.restSeconds, videoKey: slot.videoKey
      )
    }

    init(
      slotID: String, exerciseKey: String, name: String, order: Int, repTarget: RepTarget,
      instructions: String, stoppingGuidance: String, warmupGuidance: String,
      warmupSteps: [String] = [],
      restSeconds: Int?, videoKey: String?
    ) {
      self.slotID = slotID
      self.exerciseKey = exerciseKey
      self.name = name
      self.order = order
      self.repTarget = repTarget
      self.instructions = instructions
      self.stoppingGuidance = stoppingGuidance
      self.warmupGuidance = warmupGuidance
      self.warmupSteps = warmupSteps
      self.restSeconds = restSeconds
      self.videoKey = videoKey
    }

    private enum CodingKeys: String, CodingKey {
      case slotID, exerciseKey, name, order, repTarget, instructions, stoppingGuidance
      case warmupGuidance, warmupSteps, restSeconds, videoKey
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      slotID = try values.decode(String.self, forKey: .slotID)
      exerciseKey = try values.decode(String.self, forKey: .exerciseKey)
      name = try values.decode(String.self, forKey: .name)
      order = try values.decode(Int.self, forKey: .order)
      repTarget = try values.decode(RepTarget.self, forKey: .repTarget)
      instructions = try values.decode(String.self, forKey: .instructions)
      stoppingGuidance = try values.decode(String.self, forKey: .stoppingGuidance)
      warmupGuidance = try values.decode(String.self, forKey: .warmupGuidance)
      warmupSteps = try values.decodeIfPresent([String].self, forKey: .warmupSteps) ?? []
      restSeconds = try values.decodeIfPresent(Int.self, forKey: .restSeconds)
      videoKey = try values.decodeIfPresent(String.self, forKey: .videoKey)
    }

    func progressionGuidance(for repsInput: String) -> String? {
      guard let reps = Int(repsInput), reps > 0 else { return nil }
      if reps >= repTarget.maximum {
        return "If you completed all reps with good form, add a small amount of weight next time."
      }
      return "Keep the same weight and aim for more reps with good form. Target: \(repTarget.minimum)–\(repTarget.maximum)."
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
  let historicalDayNumber: Int?
  let workoutName: String
  let resolvedProgramName: String?
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
    historicalDayNumber = day
    workoutName = workout.name
    resolvedProgramName = nil
    self.startedAt = startedAt
    self.weightUnit = weightUnit
    exercises = workout.exercises.enumerated().map { Exercise(slot: $0.element, order: $0.offset) }
    setEntries = [:]
    restDeadline = nil
    finishedAt = nil
    note = nil
    requiredWorkoutIDs = program.workouts.map(\.id)
  }

  init(
    id: UUID,
    accountID: String,
    cycleID: UUID,
    programID: String,
    resolvedProgramName: String,
    week: Int,
    workoutID: String,
    dayNumber: Int?,
    workoutName: String,
    startedAt: Date,
    finishedAt: Date,
    note: String?,
    exercises: [Exercise],
    setEntries: [String: SetEntry],
    weightUnit: WeightUnit
  ) {
    self.id = id
    self.accountID = accountID
    self.cycleID = cycleID
    self.programID = programID
    self.week = week
    self.workoutID = workoutID
    day = dayNumber ?? 0
    historicalDayNumber = dayNumber
    self.workoutName = workoutName
    self.resolvedProgramName = resolvedProgramName
    self.startedAt = startedAt
    self.weightUnit = weightUnit
    self.exercises = exercises
    self.setEntries = setEntries
    restDeadline = nil
    self.finishedAt = finishedAt
    self.note = note
    requiredWorkoutIDs = []
  }

  private enum CodingKeys: String, CodingKey {
    case id, accountID, cycleID, programID, week, workoutID, day, historicalDayNumber
    case workoutName, resolvedProgramName, startedAt
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
    historicalDayNumber = try values.decodeIfPresent(Int.self, forKey: .historicalDayNumber)
      ?? (day > 0 ? day : nil)
    workoutName = try values.decode(String.self, forKey: .workoutName)
    resolvedProgramName = try values.decodeIfPresent(String.self, forKey: .resolvedProgramName)
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
