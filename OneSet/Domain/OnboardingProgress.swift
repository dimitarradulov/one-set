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
  // Optional so existing setup files migrate without fabricating cycle metadata.
  var cycles: ProgramCycleState? = nil
  // Account-scoped remote selection awaiting explicit confirmation.
  var pendingRemoteSelection: AccountSetup? = nil
  // A persisted lookup reservation is uncertain, rather than a confirmed change.
  var remoteSelectionDiscoveryPending: Bool? = nil
}
