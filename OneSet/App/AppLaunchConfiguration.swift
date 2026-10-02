struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]
  let selectedProgramID: TrainingProgram.ID?

  init(arguments: [String]) {
    #if DEBUG
    if arguments.contains("--ui-welcome") {
      onboardingPath = []
      selectedProgramID = nil
    } else if arguments.contains("--ui-preferences") {
      onboardingPath = [.preferences]
      selectedProgramID = nil
    } else if arguments.contains("--ui-login") {
      onboardingPath = [.login]
      selectedProgramID = nil
    } else if arguments.contains("--ui-programs-selected") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = "push-pull-legs"
    } else if arguments.contains("--ui-programs") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = nil
    } else if arguments.contains("--ui-program-detail") {
      onboardingPath = [.preferences, .programs, .programDetail("machine-full-body")]
      selectedProgramID = nil
    } else if arguments.contains("--ui-trial-preview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body")
      ]
      selectedProgramID = "machine-full-body"
    } else if arguments.contains("--ui-program-overview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body"),
        .programOverview("machine-full-body")
      ]
      selectedProgramID = "machine-full-body"
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
    } else {
      onboardingPath = []
      selectedProgramID = nil
    }
    #else
    onboardingPath = []
    selectedProgramID = nil
    #endif
  }
}
