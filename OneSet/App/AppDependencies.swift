@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService
  let accountSetup: any AccountSetupService

  static func live(arguments: [String]) -> AppDependencies {
    #if DEBUG
    if arguments.contains("--ui-auth-test")
      || arguments.contains("--ui-email-auth")
      || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-account-setup-error") {
      return AppDependencies(
        catalog: .bundled,
        authentication: PreviewAuthenticationService(
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: arguments.contains("--ui-auth-restored") || arguments.contains("--ui-account-setup-error"),
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset"),
          signOutFails: arguments.contains("--ui-auth-signout-error")
        ),
        accountSetup: PreviewAccountSetupService(arguments: arguments)
      )
    }
    #endif

    let authentication = ClerkAuthenticationService()
    return AppDependencies(
      catalog: .bundled,
      authentication: authentication,
      accountSetup: HTTPAccountSetupService(authentication: authentication)
    )
  }
}
