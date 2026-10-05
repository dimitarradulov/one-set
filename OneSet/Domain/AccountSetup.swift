import Foundation

struct AccountSetup: Codable, Sendable {
  let preferredUnit: WeightUnit
  let trainingDays: Int
  let programID: TrainingProgram.ID
  let cycleID: UUID

  enum CodingKeys: String, CodingKey {
    case preferredUnit = "preferred_unit"
    case trainingDays = "training_days"
    case programID = "program_id"
    case cycleID = "cycle_id"
  }
}
