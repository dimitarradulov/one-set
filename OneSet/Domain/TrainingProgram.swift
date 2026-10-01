struct TrainingProgram: Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let trainingDaysPerWeek: Int
  let format: String
  let emphasis: String
  let symbol: String
  let workouts: [WorkoutTemplate]

  var workoutCountLabel: String {
    "\(workouts.count) " + (workouts.count == 1 ? "workout" : "workouts")
  }

  static func matchingPreferenceFirst(_ programs: [TrainingProgram], days: Int) -> [TrainingProgram] {
    programs.enumerated()
      .sorted { first, second in
        let firstMatches = first.element.trainingDaysPerWeek == days
        let secondMatches = second.element.trainingDaysPerWeek == days
        if firstMatches != secondMatches { return firstMatches }
        return first.offset < second.offset
      }
      .map(\.element)
  }
}
