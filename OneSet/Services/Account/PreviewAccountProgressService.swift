#if DEBUG
import Foundation

@MainActor
struct PreviewAccountProgressService: AccountProgressService {
  let fails: Bool

  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? {
    if fails { throw AccountSetupError.unavailable }
    return nil
  }
}
#endif
