@MainActor
protocol AccountSetupService {
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup
  /// Sends the latest unit and training frequency with `PATCH /v1/me`. Throws
  /// `AccountSetupError.invalidPreferences` when the server rejects the values with `400`.
  func updatePreferences(_ preferences: AccountPreferences, for user: AuthenticatedUser) async throws -> AccountPreferences
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup?
}
