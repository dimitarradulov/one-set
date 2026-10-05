import Foundation

@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService
  let onboardingProgress: any OnboardingProgressStore
  let accountSetup: any AccountSetupService

  static func live(arguments: [String]) -> AppDependencies {
    let directory = URL.applicationSupportDirectory.appending(path: "Onboarding")
    #if DEBUG
    let preview = arguments.contains("--ui-auth-test") || arguments.contains("--ui-account-setup-error")
      || arguments.contains("--ui-email-auth") || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-progress-save-error") || arguments.contains("--ui-apple-auth-error")
    let progressURL = directory.appending(path: preview ? "preview-progress.json" : "progress.json")
    if preview && (!arguments.contains("--ui-progress-keep") || arguments.contains("--ui-progress-reset")) {
      try? FileManager.default.removeItem(at: progressURL)
    }
    #else
    let progressURL = directory.appending(path: "progress.json")
    #endif
    let fileStore = FileOnboardingProgressStore(fileURL: progressURL)
    #if DEBUG
    let progress: any OnboardingProgressStore = arguments.contains("--ui-progress-save-error")
      ? PreviewOnboardingProgressStore(store: fileStore) : fileStore
    #else
    let progress: any OnboardingProgressStore = fileStore
    #endif
    #if DEBUG
    if preview {
      return AppDependencies(
        catalog: .bundled,
        authentication: PreviewAuthenticationService(
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: arguments.contains("--ui-auth-restored") || arguments.contains("--ui-account-setup-error")
            || arguments.contains("--ui-progress-save-error"),
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset"),
          signOutFails: arguments.contains("--ui-auth-signout-error"),
          appleCancels: arguments.contains("--ui-apple-cancel"),
          appleFails: arguments.contains("--ui-apple-error") || arguments.contains("--ui-apple-auth-error")
        ),
        onboardingProgress: progress,
        accountSetup: PreviewAccountSetupService(arguments: arguments)
      )
    }
    #endif

    let authentication = ClerkAuthenticationService()
    return AppDependencies(
      catalog: .bundled,
      authentication: authentication,
      onboardingProgress: progress,
      accountSetup: HTTPAccountSetupService(authentication: authentication)
    )
  }
}
