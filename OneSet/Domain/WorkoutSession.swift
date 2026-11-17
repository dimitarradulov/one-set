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
  struct Exercise: Codable, Hashable, Identifiable, Sendable {
    var id: String { slotID }
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
  private(set) var exercises: [Exercise]
  let supersets: [SupersetPair]
  private(set) var originalExercises: [Exercise]?
  private(set) var startingExerciseKeys: [String: String]?

  var newSubstitutions: [Exercise] {
    exercises.filter { exercise in
      guard let startingKey = startingExerciseKeys?[exercise.slotID] else { return false }
      return exercise.exerciseKey != startingKey
    }
  }

  func prescribedExercise(for slotID: String) -> Exercise? {
    (originalExercises ?? exercises).first { $0.slotID == slotID }
  }

  mutating func applyRememberedExercises(_ keys: [String: String], library: [String: WorkoutExercise]) {
    let prescribed = exercises
    for exercise in prescribed {
      guard let key = keys[exercise.slotID], let replacement = library[key] else { continue }
      replaceExercise(slotID: exercise.slotID, with: replacement)
    }
    if originalExercises != nil { startingExerciseKeys = exerciseKeysBySlot }
  }

  private var exerciseKeysBySlot: [String: String] {
    Dictionary(uniqueKeysWithValues: exercises.map { ($0.slotID, $0.exerciseKey) })
  }

  mutating func replaceExercise(slotID: String, with replacement: WorkoutExercise) {
    guard setEntries[slotID]?.completedAt == nil,
          let index = exercises.firstIndex(where: { $0.slotID == slotID }),
          exercises[index].exerciseKey != replacement.exerciseKey else { return }
    if originalExercises == nil {
      originalExercises = exercises
      startingExerciseKeys = exerciseKeysBySlot
    }
    let order = exercises[index].order
    if let prescribed = prescribedExercise(for: slotID), prescribed.exerciseKey == replacement.exerciseKey {
      exercises[index] = prescribed
    } else {
      exercises[index] = Exercise(
        slotID: slotID, exerciseKey: replacement.exerciseKey, name: replacement.name, order: order,
        repTarget: replacement.defaultRepTarget ?? replacement.repTarget, instructions: replacement.instructions,
        stoppingGuidance: replacement.stoppingGuidance, warmupGuidance: replacement.warmupGuidance,
        restSeconds: replacement.restSeconds, videoKey: replacement.videoKey
      )
    }
    setEntries[slotID] = nil
  }
  var setEntries: [String: SetEntry]
  var restDeadline: Date?
  var finishedAt: Date?
  var note: String?
  let requiredWorkoutIDs: [String]

  private(set) var restSlotID: String?

  mutating func startRest(after slotID: String, seconds: Int, at date: Date) {
    restSlotID = slotID
    restDeadline = date.addingTimeInterval(TimeInterval(seconds))
  }

  mutating func clearRest() {
    restSlotID = nil
    restDeadline = nil
  }

  mutating func updateRest(afterCompleting slotID: String, standaloneSeconds: Int?, at date: Date) {
    let pair = supersets.first { $0.contains(slotID: slotID) }
    if let pair,
       setEntries[pair.firstSlotID]?.completedAt == nil || setEntries[pair.secondSlotID]?.completedAt == nil {
      return
    }
    guard let pair else {
      restDeadline = standaloneSeconds.map { date.addingTimeInterval(TimeInterval($0)) }
      restSlotID = restDeadline != nil && slotID != exercises.last?.slotID
        && exercises.contains(where: { setEntries[$0.slotID]?.completedAt == nil }) ? slotID : nil
      return
    }
    guard pair.secondSlotID != exercises.last?.slotID,
          exercises.contains(where: { setEntries[$0.slotID]?.completedAt == nil }) else {
      clearRest()
      return
    }
    startRest(after: pair.secondSlotID, seconds: 180, at: date)
  }

  mutating func updateRest(afterUndoing slotID: String) {
    if supersets.contains(where: {
      $0.secondSlotID == restSlotID && $0.contains(slotID: slotID)
    }) {
      clearRest()
    } else if restDeadline != nil && (restSlotID == slotID || restSlotID == nil) {
      restSlotID = latestStandaloneRestAnchor
    }
  }

  private var latestStandaloneRestAnchor: String? {
    guard exercises.contains(where: { setEntries[$0.slotID]?.completedAt == nil }) else { return nil }
    let latest = exercises
      .filter { exercise in
        setEntries[exercise.slotID]?.completedAt != nil && !supersets.contains {
          $0.contains(slotID: exercise.slotID)
        }
      }
      .max {
        (setEntries[$0.slotID]?.completedAt ?? .distantPast)
          < (setEntries[$1.slotID]?.completedAt ?? .distantPast)
      }?.slotID
    return latest == exercises.last?.slotID ? nil : latest
  }

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
    supersets = workout.supersets ?? []
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
    weightUnit: WeightUnit,
    supersets: [SupersetPair] = []
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
    self.supersets = supersets
    self.setEntries = setEntries
    restDeadline = nil
    self.finishedAt = finishedAt
    self.note = note
    requiredWorkoutIDs = []
  }

  private enum CodingKeys: String, CodingKey {
    case id, accountID, cycleID, programID, week, workoutID, day, historicalDayNumber
    case workoutName, resolvedProgramName, startedAt
    case originalExercises, startingExerciseKeys
    case weightUnit, exercises, supersets, setEntries, restDeadline, restSlotID, finishedAt, note, requiredWorkoutIDs
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
    supersets = try values.decodeIfPresent([SupersetPair].self, forKey: .supersets) ?? []
    originalExercises = try values.decodeIfPresent([Exercise].self, forKey: .originalExercises)
    startingExerciseKeys = try values.decodeIfPresent([String: String].self, forKey: .startingExerciseKeys)
    setEntries = try values.decodeIfPresent([String: SetEntry].self, forKey: .setEntries) ?? [:]
    restDeadline = try values.decodeIfPresent(Date.self, forKey: .restDeadline)
    finishedAt = try values.decodeIfPresent(Date.self, forKey: .finishedAt)
    note = try values.decodeIfPresent(String.self, forKey: .note)
    requiredWorkoutIDs = try values.decodeIfPresent([String].self, forKey: .requiredWorkoutIDs) ?? [workoutID]
    restSlotID = try values.decodeIfPresent(String.self, forKey: .restSlotID)
    if restSlotID == nil, restDeadline != nil { restSlotID = latestStandaloneRestAnchor }
  }
}
