#if DEBUG
@MainActor
final class PreviewAccountDeletionService: AccountDeletionService {
  private let fails: Bool

  init(arguments: [String] = []) {
    fails = arguments.contains("--ui-account-deletion-failure")
  }

  func deleteAccount(for user: AuthenticatedUser) async -> AccountDeletionResult {
    fails ? .failed : .deleted
  }
}
#endif
