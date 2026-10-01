struct WorkoutTemplate: Hashable, Identifiable, Sendable {
  let name: String
  let movements: [String]

  var id: String { name }

  var summary: String {
    let firstMovements = movements.prefix(2).joined(separator: " · ")
    let remainingCount = movements.count - min(movements.count, 2)
    guard remainingCount > 0 else { return firstMovements }
    return "\(firstMovements) · +\(remainingCount) more"
  }
}

