struct AppLaunchConfiguration {
  let onboardingPath: [OnboardingRoute]
  let selectedProgramID: TrainingProgram.ID?
  let trainingDays: Int
  let selectedMainTab: MainTab
  let settingsPath: [SettingsDestination]
  let programPath: [OnboardingRoute]
  let includesMainTabsPreview: Bool
  #if DEBUG
  /// Preset subscription state from `--ui-subscription-<active|inactive|checking|failed|pending>`.
  /// `--ui-main-workout-gated` opens the tab preview, taps Start once, and defaults to inactive.
  let subscriptionPreset: SubscriptionAccessPreset?
  /// Checkout sheet state from `--ui-paywall[-unavailable|-verifying|-verify-failed|-pending]`.
  let paywallPreview: PaywallPreviewState?
  /// Restore outcome from `--ui-subscription-restore-<name>` or a Settings subscription route.
  let subscriptionRestore: SubscriptionRestorePreset?
  /// Settings Subscription state from `--ui-settings-subscription[-<state>]`.
  let subscriptionSettingsRoute: SubscriptionSettingsRoute?
  #endif

  #if DEBUG
  /// Opens Settings > Delete account. The base route shows the ready screen; the others preset
  /// a blocking or warning state (`-failure` is also read by the preview deletion service).
  static let accountDeletionRoutes: Set<String> = [
    "--ui-account-deletion", "--ui-account-deletion-offline", "--ui-account-deletion-active-workout",
    "--ui-account-deletion-unsynced", "--ui-account-deletion-failure"
  ]

  private static func paywallPreview(arguments: [String]) -> PaywallPreviewState? {
    let routes: [String: PaywallPreviewState] = [
      "--ui-paywall": .ready,
      "--ui-paywall-unavailable": .unavailable,
      "--ui-paywall-verifying": .verifying,
      "--ui-paywall-verify-failed": .verifyFailed,
      "--ui-paywall-pending": .pending
    ]
    return arguments.lazy.compactMap { routes[$0] }.first
  }
  #endif

  static func usesMainTabsPreview(arguments: [String]) -> Bool {
    #if DEBUG
    return arguments.contains("--ui-program-change") || arguments.contains("--ui-program-change-preview")
      || arguments.contains("--ui-program-change-active") || arguments.contains("--ui-switch-conflict") || arguments.contains("--ui-replacement-device") || arguments.contains("--ui-switch-resume-detail") || arguments.contains("--ui-switch-test") || arguments.contains("--ui-switch-programs") || arguments.contains("--ui-switch-detail")
      || arguments.contains("--ui-main-workout-superset") || arguments.contains("--ui-main-workout-recording") || arguments.contains("--ui-finish-review") || arguments.contains("--ui-warmup-sheet") || arguments.contains("--ui-main-tabs") || arguments.contains("--ui-main-history")
      || arguments.contains("--ui-history-populated") || arguments.contains("--ui-history-partial-detail")
      || arguments.contains("--ui-history-empty") || arguments.contains("--ui-history-error")
      || arguments.contains("--ui-history-refresh-error")
      || arguments.contains("--ui-history-pagination") || arguments.contains("--ui-history-offline-boundary")
      || arguments.contains("--ui-signout-confirmation")
      || arguments.contains("--ui-main-settings") || arguments.contains("--ui-main-workout-preview")
      || arguments.containsAny(Self.accountDeletionRoutes)
      || Self.subscriptionSettingsRoute(arguments: arguments) != nil
      || arguments.contains("--ui-main-workout-gated")
      || arguments.contains("--ui-main-settings-units") || arguments.contains("--ui-main-exercise-detail")
      || arguments.contains("--ui-main-settings-rest-alerts")
      || arguments.contains("--ui-setup-cycle-conflict")
      || arguments.contains("--ui-session-signout-confirmation")
      || arguments.contains("--ui-session-signout-error")
      || arguments.contains("--ui-progress-restore-error")
    #else
    return false
    #endif
  }

  init(arguments: [String]) {
    includesMainTabsPreview = Self.usesMainTabsPreview(arguments: arguments)
    #if DEBUG
    let settingsRoute = Self.subscriptionSettingsRoute(arguments: arguments)
    subscriptionSettingsRoute = settingsRoute
    subscriptionPreset = SubscriptionAccessPreset(arguments: arguments) ?? settingsRoute?.preset
      ?? (arguments.contains("--ui-main-workout-gated") ? .inactive : nil)
    subscriptionRestore = SubscriptionRestorePreset(arguments: arguments) ?? settingsRoute?.restore
    paywallPreview = Self.paywallPreview(arguments: arguments)
    selectedMainTab = Self.mainTab(arguments: arguments, hasSettingsRoute: settingsRoute != nil)
    if arguments.contains("--ui-main-settings-units") {
      settingsPath = [.units]
    } else if arguments.contains("--ui-main-settings-rest-alerts") {
      settingsPath = [.restAlerts]
    } else if arguments.containsAny(Self.accountDeletionRoutes) {
      settingsPath = [.accountDeletion]
    } else {
      settingsPath = settingsRoute == nil ? [] : [.subscription]
    }
    programPath = Self.mainProgramPath(arguments: arguments)
    trainingDays = arguments.contains("--ui-programs-minimalist") ? 2 : 3
    let onboarding = Self.onboardingPreview(arguments: arguments)
    onboardingPath = onboarding.path
    selectedProgramID = onboarding.programID
    #else
    selectedMainTab = .program
    settingsPath = []
    programPath = []
    trainingDays = 3
    onboardingPath = []
    selectedProgramID = nil
    #endif
  }

  #if DEBUG
  private static func mainTab(arguments: [String], hasSettingsRoute: Bool) -> MainTab {
    if arguments.containsAny(
      "--ui-main-history", "--ui-history-populated", "--ui-history-partial-detail", "--ui-history-empty",
      "--ui-history-error", "--ui-history-refresh-error", "--ui-history-pagination",
      "--ui-history-offline-boundary"
    ) {
      return .history
    }
    if hasSettingsRoute || arguments.containsAny(Self.accountDeletionRoutes) || arguments.containsAny(
      "--ui-signout-confirmation", "--ui-main-settings", "--ui-main-settings-units", "--ui-main-settings-rest-alerts",
      "--ui-session-signout-confirmation", "--ui-session-signout-error"
    ) {
      return .settings
    }
    return .program
  }

  private static func mainProgramPath(arguments: [String]) -> [OnboardingRoute] {
    if arguments.containsAny("--ui-switch-detail", "--ui-switch-resume-detail") {
      return [.programs, .programDetail("push-pull-legs")]
    } else if arguments.contains("--ui-switch-programs") {
      return [.programs]
    } else if arguments.contains("--ui-program-change-preview") {
      return [.workoutPreview(programID: "bro-split", workoutID: "bro-split-day-1-chest")]
    } else if arguments.containsAny("--ui-main-workout-preview", "--ui-main-workout-gated") {
      return [.workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a")]
    } else if arguments.contains("--ui-main-exercise-detail") {
      return [
        .workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a"),
        .exerciseDetail(
          programID: "machine-full-body",
          workoutID: "machine-full-body-workout-a",
          exerciseID: "machine-full-body-workout-a-hack-squat-machine"
        )
      ]
    }
    return []
  }

  private struct OnboardingPreview {
    let path: [OnboardingRoute]
    let programID: String?
  }

  private static func onboardingPreview(arguments: [String]) -> OnboardingPreview {
    let empty = OnboardingPreview(path: [], programID: nil)
    if usesMainTabsPreview(arguments: arguments)
      || arguments.containsAny(
        "--ui-setup-upload-pending", "--ui-setup-upload-discard", "--ui-setup-upload-removed",
        "--ui-account-setup-error", "--ui-setup-timeout", "--ui-progress-save-error",
        "--ui-progress-restore-error", "--ui-welcome", "--ui-welcome-account-deleted", "--ui-apple-auth-error", "--ui-google-auth-error"
      ) {
      return empty
    }
    if arguments.contains("--ui-email-auth") { return OnboardingPreview(path: [.emailAuthentication], programID: nil) }
    if arguments.contains("--ui-preferences") { return OnboardingPreview(path: [.preferences], programID: nil) }
    return programSetupPreview(arguments: arguments) ?? workoutRoutePreview(arguments: arguments) ?? empty
  }

  private static func programSetupPreview(arguments: [String]) -> OnboardingPreview? {
    let programs: [OnboardingRoute] = [.preferences, .programs]
    if arguments.contains("--ui-programs-removed") { return OnboardingPreview(path: programs, programID: nil) }
    if arguments.contains("--ui-programs-minimalist") {
      return OnboardingPreview(path: programs, programID: "minimalist-full-body")
    }
    if arguments.contains("--ui-programs-selected") { return OnboardingPreview(path: programs, programID: "push-pull-legs") }
    if arguments.contains("--ui-programs") { return OnboardingPreview(path: programs, programID: nil) }
    if let programID = programPreviewID(arguments: arguments, detail: true) {
      return OnboardingPreview(path: programs + [.programDetail(programID)], programID: nil)
    }
    if arguments.contains("--ui-trial-preview") {
      let path: [OnboardingRoute] = programs + [.programDetail("machine-full-body"), .trialPreview("machine-full-body")]
      return OnboardingPreview(path: path, programID: "machine-full-body")
    }
    if let programID = programPreviewID(arguments: arguments, detail: false) {
      return OnboardingPreview(path: overviewPath(programID: programID), programID: programID)
    }
    return nil
  }

  private static func workoutRoutePreview(arguments: [String]) -> OnboardingPreview? {
    let machine = "machine-full-body"
    let machineWorkout = "machine-full-body-workout-a"
    if arguments.containsAny("--ui-exercise-detail", "--ui-exercise-detail-expanded", "--ui-exercise-history") {
      let path = overviewPath(programID: machine) + [
        .workoutPreview(programID: machine, workoutID: machineWorkout),
        .exerciseDetail(
          programID: machine,
          workoutID: machineWorkout,
          exerciseID: "machine-full-body-workout-a-hack-squat-machine",
          guidanceExpanded: arguments.contains("--ui-exercise-detail-expanded"),
          initiallyShowingHistory: arguments.contains("--ui-exercise-history")
        )
      ]
      return OnboardingPreview(path: path, programID: machine)
    }
    if let (programID, workoutID) = workoutBannerPreview(arguments: arguments) {
      let path = overviewPath(programID: programID) + [.workoutPreview(programID: programID, workoutID: workoutID)]
      return OnboardingPreview(path: path, programID: programID)
    }
    if arguments.contains("--ui-workout-preview-minimalist") {
      let id = "minimalist-full-body"
      let path = overviewPath(programID: id) + [.workoutPreview(programID: id, workoutID: "minimalist-full-body-workout-a")]
      return OnboardingPreview(path: path, programID: id)
    }
    if arguments.containsAny("--ui-workout-preview", "--ui-workout-preview-superset") {
      let path = overviewPath(programID: machine) + [.workoutPreview(programID: machine, workoutID: machineWorkout)]
      return OnboardingPreview(path: path, programID: machine)
    }
    return nil
  }

  private static func overviewPath(programID: String) -> [OnboardingRoute] {
    [.preferences, .programs, .programDetail(programID), .trialPreview(programID), .programOverview(programID)]
  }
  #endif

  private static func programPreviewID(arguments: [String], detail: Bool) -> String? {
    let routes = detail
      ? [("--ui-program-detail", "machine-full-body"), ("--ui-program-rotation-detail", "hit-upper-lower-rotation")]
      : [("--ui-program-overview", "machine-full-body"), ("--ui-program-rotation", "hit-upper-lower-rotation")]
    return routes.first { arguments.contains($0.0) }?.1
  }

  private static func workoutBannerPreview(arguments: [String]) -> (String, String)? {
    let routes = [
      "--ui-workout-preview-rotation": ("hit-upper-lower-rotation", "hit-upper-lower-rotation-legs-advanced"),
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
      "--ui-workout-banner-arms": ("bro-split", "bro-split-day-5-arms")
    ]
    return routes.first(where: { arguments.contains($0.key) })?.value
  }
}

private extension [String] {
  func containsAny(_ names: String...) -> Bool {
    names.contains { contains($0) }
  }

  func containsAny(_ names: Set<String>) -> Bool {
    contains { names.contains($0) }
  }
}
