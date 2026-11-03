import Foundation

struct AccountProgress: Codable, Equatable, Sendable {
  struct Occurrence: Codable, Equatable, Sendable {
    let weekNumber: Int
    let workoutID: String

    enum CodingKeys: String, CodingKey {
      case weekNumber = "week_number"
      case workoutID = "workout_id"
    }
  }

  struct WorkoutPeriod: Codable, Equatable, Sendable {
    let workoutID: String
    let startsWeek: Int
    let endsWeek: Int?

    enum CodingKeys: String, CodingKey {
      case workoutID = "workout_id"
      case startsWeek = "starts_week"
      case endsWeek = "ends_week"
    }
  }

  let cycleID: UUID
  let programID: TrainingProgram.ID
  let currentTrainingWeek: Int
  let completedOccurrences: [Occurrence]
  let workoutPeriods: [WorkoutPeriod]
  let requiredWorkoutIDs: [String]

  enum CodingKeys: String, CodingKey {
    case cycleID = "cycle_id"
    case programID = "program_id"
    case currentTrainingWeek = "current_training_week"
    case completedOccurrences = "completed_occurrences"
    case workoutPeriods = "workout_periods"
    case requiredWorkoutIDs = "required_workouts"
  }
}
