struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]
  let selectedProgramID: TrainingProgram.ID?
  let trainingDays: Int
  let selectedMainTab: MainTab
  let settingsPath: [SettingsDestination]
  let programPath: [OnboardingRoute]
  let includesMainTabsPreview: Bool

  static func usesMainTabsPreview(arguments: [String]) -> Bool {
    #if DEBUG
    return arguments.contains("--ui-main-tabs") || arguments.contains("--ui-main-history")
      || arguments.contains("--ui-main-settings") || arguments.contains("--ui-main-workout-preview")
      || arguments.contains("--ui-main-settings-units") || arguments.contains("--ui-main-exercise-detail")
    #else
    return false
    #endif
  }

  init(arguments: [String]) {
    includesMainTabsPreview = Self.usesMainTabsPreview(arguments: arguments)
    #if DEBUG
    if arguments.contains("--ui-main-history") {
      selectedMainTab = .history
    } else if arguments.contains("--ui-main-settings") || arguments.contains("--ui-main-settings-units") {
      selectedMainTab = .settings
    } else {
      selectedMainTab = .program
    }
    settingsPath = arguments.contains("--ui-main-settings-units") ? [.units] : []
    if arguments.contains("--ui-main-workout-preview") {
      programPath = [.workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a")]
    } else if arguments.contains("--ui-main-exercise-detail") {
      programPath = [
        .workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a"),
        .exerciseDetail(
          programID: "machine-full-body",
          workoutID: "machine-full-body-workout-a",
          exerciseID: "machine-full-body-workout-a-hack-squat-machine"
        )
      ]
    } else {
      programPath = []
    }
    #else
    selectedMainTab = .program
    settingsPath = []
    programPath = []
    #endif
    #if DEBUG
    trainingDays = arguments.contains("--ui-programs-minimalist") ? 2 : 3
    if Self.usesMainTabsPreview(arguments: arguments) {
      onboardingPath = []
      selectedProgramID = nil
    } else if arguments.contains("--ui-setup-upload-pending") || arguments.contains("--ui-setup-upload-discard")
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
    } else if let (programID, workoutID) = Self.workoutBannerPreview(arguments: arguments) {
      onboardingPath = [
        .preferences,
        .programs,
        .programDetail(programID),
        .trialPreview(programID),
        .programOverview(programID),
        .workoutPreview(programID: programID, workoutID: workoutID)
      ]
      selectedProgramID = programID
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

  private static func workoutBannerPreview(arguments: [String]) -> (String, String)? {
    let routes = [
      "--ui-workout-banner-fallback": ("upper-lower", "upper-lower-lower-a"),
      "--ui-workout-banner-legacy": ("upper-lower", "upper-lower-lower-a"),
      "--ui-workout-banner-offline": ("founder-authored-plan", "founder-authored-plan-day-a"),
      "--ui-workout-banner-general-gym": ("machine-full-body", "machine-full-body-workout-a"),
      "--ui-workout-banner-upper-body": ("upper-lower", "upper-lower-upper-a"),
      "--ui-workout-banner-lower-body": ("upper-lower", "upper-lower-lower-a"),
      "--ui-workout-banner-lower-body-shared": ("upper-lower", "upper-lower-lower-b"),
      "--ui-workout-banner-chest-push": ("bro-split", "bro-split-day-1-chest"),
      "--ui-workout-banner-back-pull": ("bro-split", "bro-split-day-2-back"),
      "--ui-workout-banner-shoulders": ("bro-split", "bro-split-day-4-shoulders"),
      "--ui-workout-banner-arms": ("bro-split", "bro-split-day-5-arms"),
    ]
    return routes.first(where: { arguments.contains($0.key) })?.value
  }
}
