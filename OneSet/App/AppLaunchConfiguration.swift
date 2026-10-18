struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]
  let selectedProgramID: TrainingProgram.ID?
  let trainingDays: Int

  init(arguments: [String]) {
    #if DEBUG
    trainingDays = arguments.contains("--ui-programs-minimalist") ? 2 : 3
    if arguments.contains("--ui-setup-upload-pending") || arguments.contains("--ui-setup-upload-discard")
      || arguments.contains("--ui-setup-upload-removed")
      || arguments.contains("--ui-account-setup-error") || arguments.contains("--ui-progress-save-error") {
      onboardingPath = []
      selectedProgramID = nil
    } else if arguments.contains("--ui-email-auth") {
      onboardingPath = [.emailAuthentication]
      selectedProgramID = nil
    } else if arguments.contains("--ui-welcome") || arguments.contains("--ui-apple-auth-error")
      || arguments.contains("--ui-google-auth-error") {
      onboardingPath = []
      selectedProgramID = nil
    } else if arguments.contains("--ui-preferences") {
      onboardingPath = [.preferences]
      selectedProgramID = nil
    } else if arguments.contains("--ui-programs-removed") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = nil
    } else if arguments.contains("--ui-programs-minimalist") {
      onboardingPath = [.preferences, .programs]
      selectedProgramID = "minimalist-full-body"
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
    } else if arguments.contains("--ui-exercise-detail") || arguments.contains("--ui-exercise-detail-expanded")
      || arguments.contains("--ui-exercise-history") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body"),
        .programOverview("machine-full-body"),
        .workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a"),
        .exerciseDetail(
          programID: "machine-full-body",
          workoutID: "machine-full-body-workout-a",
          exerciseID: "machine-full-body-workout-a-hack-squat-machine",
          guidanceExpanded: arguments.contains("--ui-exercise-detail-expanded"),
          initiallyShowingHistory: arguments.contains("--ui-exercise-history")
        )
      ]
      selectedProgramID = "machine-full-body"
    } else if arguments.contains("--ui-workout-preview-minimalist") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("minimalist-full-body"),
        .trialPreview("minimalist-full-body"),
        .programOverview("minimalist-full-body"),
        .workoutPreview(programID: "minimalist-full-body", workoutID: "minimalist-full-body-workout-a")
      ]
      selectedProgramID = "minimalist-full-body"
    } else if arguments.contains("--ui-workout-preview") {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail("machine-full-body"),
        .trialPreview("machine-full-body"),
        .programOverview("machine-full-body"),
        .workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a")
      ]
      selectedProgramID = "machine-full-body"
    } else {
      onboardingPath = []
      selectedProgramID = nil
    }
    #else
    trainingDays = 3
    onboardingPath = []
    selectedProgramID = nil
    #endif
  }
}
