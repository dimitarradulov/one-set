struct UnfinishedOnboarding: Codable, Sendable {
  enum Step: String, Codable, Sendable {
    case preferences
    case programs
    case trial
  }

  let weightUnit: WeightUnit
  let trainingDays: Int
  let selectedProgramID: TrainingProgram.ID?
  let nextStep: Step
}
