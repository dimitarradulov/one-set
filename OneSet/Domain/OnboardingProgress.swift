struct OnboardingProgress: Codable, Sendable {
  enum Step: String, Codable, Sendable {
    case preferences
    case programs
    case trial
    case overview
  }

  let weightUnit: WeightUnit
  let trainingDays: Int
  let selectedProgramID: TrainingProgram.ID?
  let nextStep: Step
  var completed: CompletedOnboarding? = nil
}
