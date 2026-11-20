struct WorkoutExerciseGroup: Identifiable {
  let id: String
  let firstIndex: Int
  let secondIndex: Int?

  static func ordered<Exercise>(
    _ exercises: [Exercise], slotID: KeyPath<Exercise, String>, supersets: [SupersetPair]
  ) -> [Self] {
    var groups: [Self] = []
    var index = 0
    while index < exercises.count {
      let firstID = exercises[index][keyPath: slotID]
      let nextIndex = index + 1
      let adjacentPair = exercises.indices.contains(nextIndex) && supersets.contains {
        $0.firstSlotID == firstID && $0.secondSlotID == exercises[nextIndex][keyPath: slotID]
      }
      groups.append(.init(id: firstID, firstIndex: index, secondIndex: adjacentPair ? nextIndex : nil))
      index += adjacentPair ? 2 : 1
    }
    return groups
  }
}
