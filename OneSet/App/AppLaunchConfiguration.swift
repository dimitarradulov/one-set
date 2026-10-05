struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]
  let selectedProgramID: TrainingProgram.ID?
  let trainingDays: Int
  let authenticationEntryPoint: AuthenticationModel.EntryPoint?

  init(arguments: [String]) {
    #if DEBUG
    trainingDays = arguments.contains("--ui-programs-minimalist") ? 2 : 3
    if arguments.contains("--ui-account-setup-error") || arguments.contains("--ui-progress-save-error") {
      onboardingPath = []
      selectedProgramID = nil
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-email-auth") {
      onboardingPath = [.emailAuthentication]
      selectedProgramID = nil
      authenticationEntryPoint = .continueWithEmail
    } else if arguments.contains("--ui-welcome") || arguments.contains("--ui-apple-auth-error")
      || arguments.contains("--ui-google-auth-error") {
      onboardingPath = []
      selectedProgramID = nil
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-preferences") {
      onboardingPath = [.preferences]
      selectedProgramID = nil
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-login") {
      onboardingPath = [.login]
      selectedProgramID = nil
      authenticationEntryPoint = .logIn
    } else if arguments.contains("--ui-programs-minimalist") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = "minimalist-full-body"
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-programs-selected") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = "push-pull-legs"
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-programs") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = nil
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-program-detail") {
      onboardingPath = [.preferences, .programs, .programDetail("machine-full-body")]
      selectedProgramID = nil
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-trial-preview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body")
      ]
      selectedProgramID = "machine-full-body"
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-program-overview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body"),
        .programOverview("machine-full-body")
      ]
      selectedProgramID = "machine-full-body"
      authenticationEntryPoint = nil
    } else if arguments.contains("--ui-workout-preview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body"),
        .programOverview("machine-full-body"),
        .workoutPreview(programID: "machine-full-body", workoutID: "Workout A")
      ]
      selectedProgramID = "machine-full-body"
      authenticationEntryPoint = nil
    } else {
      onboardingPath = []
      selectedProgramID = nil
      authenticationEntryPoint = nil
    }
    #else
    trainingDays = 3
    onboardingPath = []
    selectedProgramID = nil
    authenticationEntryPoint = nil
    #endif
  }
}
