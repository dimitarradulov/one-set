@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService

  static func live(arguments: [String]) -> AppDependencies {
    #if DEBUG
    if arguments.contains("--ui-auth-test")
      || arguments.contains("--ui-email-auth")
      || arguments.contains("--ui-auth-persist-session-test") {
      return AppDependencies(
        catalog: .bundled,
        authentication: PreviewAuthenticationService(
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: arguments.contains("--ui-auth-restored"),
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset")
        )
      )
    }
    #endif

    return AppDependencies(catalog: .bundled, authentication: ClerkAuthenticationService())
  }
}
