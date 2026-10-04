@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService

  static let live = AppDependencies(
    catalog: .bundled,
    authentication: ClerkAuthenticationService()
  )
}
