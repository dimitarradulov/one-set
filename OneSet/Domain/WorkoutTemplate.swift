struct WorkoutTemplate: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let banner: String?
  let exercises: [WorkoutExercise]

  init(id: String? = nil, name: String, banner: String? = nil, exercises: [WorkoutExercise]) {
    self.id = id ?? name
    self.name = name
    self.banner = banner
    self.exercises = exercises
  }

  var movements: [String] {
    exercises.map(\.name)
  }

  var summary: String {
    let firstMovements = movements.prefix(2).joined(separator: " · ")
    let remainingCount = movements.count - min(movements.count, 2)
    guard remainingCount > 0 else { return firstMovements }
    return "\(firstMovements) · +\(remainingCount) more"
  }
}

struct WorkoutExercise: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let exerciseKey: String
  let name: String
  let repTarget: RepTarget

  let instructions: String
  let stoppingGuidance: String
  let warmupGuidance: String
  let restSeconds: Int?
  let defaultRepTarget: RepTarget?
  let videoKey: String?

  init(
    id: String? = nil,
    exerciseKey: String? = nil,
    name: String,
    repTarget: RepTarget,
    instructions: String = "",
    stoppingGuidance: String = "",
    warmupGuidance: String = "",
    restSeconds: Int? = nil,
    defaultRepTarget: RepTarget? = nil,
    videoKey: String? = nil
  ) {
    self.id = id ?? name
    self.exerciseKey = exerciseKey ?? name
    self.name = name
    self.repTarget = repTarget
    self.instructions = instructions
    self.stoppingGuidance = stoppingGuidance
    self.warmupGuidance = warmupGuidance
    self.restSeconds = restSeconds
    self.defaultRepTarget = defaultRepTarget
    self.videoKey = videoKey
  }
}

struct RepTarget: Codable, Hashable, Sendable {
  enum Scope: String, Codable, Hashable, Sendable {
    case reps
    case eachLeg
    case eachSide
  }

  let minimum: Int
  let maximum: Int
  let scope: Scope

  init(minimum: Int, maximum: Int, scope: Scope = .reps) {
    precondition(minimum > 0 && maximum >= minimum, "Rep target must be a positive range")
    self.minimum = minimum
    self.maximum = maximum
    self.scope = scope
  }

  var label: String {
    let range = "\(minimum)–\(maximum) reps"
    switch scope {
    case .reps:
      return range
    case .eachLeg:
      return "\(range) each leg"
    case .eachSide:
      return "\(range) each side"
    }
  }
}
