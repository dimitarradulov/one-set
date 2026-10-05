@MainActor
protocol AccountSetupService {
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup?
}
