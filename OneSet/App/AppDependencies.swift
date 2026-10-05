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
    let uploadPreview = arguments.contains("--ui-setup-upload-pending")
      || arguments.contains("--ui-setup-upload-discard")
    let completionSaveError = arguments.contains("--ui-completion-save-error")
    let preview = completionSaveError || uploadPreview || arguments.contains("--ui-auth-test") || arguments.contains("--ui-account-setup-error")
      || arguments.contains("--ui-email-auth") || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-progress-save-error") || arguments.contains("--ui-apple-auth-error")
      || arguments.contains("--ui-google-auth-error")
    let progressURL = directory.appending(path: preview ? "preview-progress.json" : "progress.json")
    if preview && (!arguments.contains("--ui-progress-keep") || arguments.contains("--ui-progress-reset")) {
      try? FileManager.default.removeItem(at: progressURL)
    }
    #else
    let progressURL = directory.appending(path: "progress.json")
    #endif
    let fileStore = FileOnboardingProgressStore(fileURL: progressURL)
    #if DEBUG
    if uploadPreview {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                         selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body", cycleID: UUID()
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
    let progress: any OnboardingProgressStore = (completionSaveError || arguments.contains("--ui-progress-save-error"))
      ? PreviewOnboardingProgressStore(store: fileStore, completionOnly: completionSaveError) : fileStore
    #else
    let progress: any OnboardingProgressStore = fileStore
    #endif
    #if DEBUG
    if preview {
      return AppDependencies(
        catalog: .bundled,
        authentication: PreviewAuthenticationService(
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: uploadPreview || arguments.contains("--ui-auth-restored") || arguments.contains("--ui-account-setup-error")
            || arguments.contains("--ui-progress-save-error"),
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset"),
          signOutFails: arguments.contains("--ui-auth-signout-error"),
          googleIncomplete: arguments.contains("--ui-google-incomplete"),
          googleFails: arguments.contains("--ui-google-error") || arguments.contains("--ui-google-auth-error"),
          googleCancels: arguments.contains("--ui-google-cancel"),
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
