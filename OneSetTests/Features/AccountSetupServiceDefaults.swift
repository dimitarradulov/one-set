@testable import OneSet

/// Most test stubs only cover setup lookup and save. Preference updates fail as unavailable
/// unless a test supplies its own implementation.
extension AccountSetupService {
  func updatePreferences(_ preferences: AccountPreferences, for user: AuthenticatedUser) async throws -> AccountPreferences {
    throw AccountSetupError.unavailable
  }
}
