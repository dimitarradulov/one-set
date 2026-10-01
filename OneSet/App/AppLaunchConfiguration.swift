struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]

  init(arguments: [String]) {
    #if DEBUG
    if arguments.contains("--ui-welcome") {
      onboardingPath = []
    } else if arguments.contains("--ui-preferences") {
      onboardingPath = [.preferences]
    } else if arguments.contains("--ui-login") {
      onboardingPath = [.login]
    } else if arguments.contains("--ui-programs") {
      onboardingPath = [.preferences, .programs]
    } else if arguments.contains("--ui-program-detail") {
      onboardingPath = [.preferences, .programs, .programDetail("machine-full-body")]
    } else {
      onboardingPath = []
    }
    #else
    onboardingPath = []
    #endif
  }
}
