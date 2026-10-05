@MainActor
protocol AccountSetupService {
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup?
}
