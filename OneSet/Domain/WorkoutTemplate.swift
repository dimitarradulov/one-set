struct WorkoutTemplate: Hashable, Identifiable, Sendable {
  let name: String
  let exercises: [WorkoutExercise]

  var id: String { name }

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

struct WorkoutExercise: Hashable, Identifiable, Sendable {
  let name: String
  let repTarget: RepTarget

  var id: String { name }
}

struct RepTarget: Hashable, Sendable {
  enum Scope: Hashable, Sendable {
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
