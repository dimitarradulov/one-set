enum AccountDeletionResult: Equatable, Sendable {
  case deleted
  case failed
}

@MainActor
protocol AccountDeletionService {
  func deleteAccount(for user: AuthenticatedUser) async -> AccountDeletionResult
}
