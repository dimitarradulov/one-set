struct TrainingProgram: Codable, Hashable, Identifiable, Sendable {
  let id: String
  let name: String
  let format: String
  let emphasis: String
  let workouts: [WorkoutTemplate]
  let recommendedWeeks: Int
  let isOffered: Bool

  var trainingDaysPerWeek: Int { workouts(inWeek: 1).count }
  var alternatesTrainingWeeks: Bool { workouts.contains { $0.weekParity != nil } }
  var evenWeekWorkoutIDs: [String]? { alternatesTrainingWeeks ? workouts(inWeek: 2).map(\.id) : nil }

  func workouts(inWeek week: Int) -> [WorkoutTemplate] {
    workouts.filter { $0.weekParity?.includes(week) ?? true }
  }

  func trainingDay(for workout: WorkoutTemplate) -> Int {
    let week = workout.weekParity == .even ? 2 : 1
    return (workouts(inWeek: week).firstIndex { $0.id == workout.id } ?? 0) + 1
  }

  init(
    id: String,
    name: String,
    format: String,
    emphasis: String,
    workouts: [WorkoutTemplate],
    recommendedWeeks: Int = 8,
    isOffered: Bool = true
  ) {
    self.id = id
    self.name = name
    self.format = format
    self.emphasis = emphasis
    self.workouts = workouts
    self.recommendedWeeks = recommendedWeeks
    self.isOffered = isOffered
  }

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
