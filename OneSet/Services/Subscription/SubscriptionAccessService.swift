import Foundation

/// Subscription access scoped to the active account selection. Callers pass the
/// selection they started with and drop results that no longer apply.
@MainActor
protocol SubscriptionAccessService {
  /// Awaits the current decision. Concurrent callers for one selection share a check in progress.
  func currentAccess(for selection: AccountSelection) async -> SubscriptionAccessResult
  /// Runs a new check, then returns its decision.
  func refresh(for selection: AccountSelection) async -> SubscriptionAccessResult
  /// Purchases a package. A purchase awaiting approval returns `.pendingApproval`.
  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult
  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult
  /// Reports later decisions, including pending approval resolving outside the app.
  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult>
}

/// Used when no subscription provider is configured: access can never be confirmed.
@MainActor
struct UnconfiguredSubscriptionAccessService: SubscriptionAccessService {
  func currentAccess(for selection: AccountSelection) async -> SubscriptionAccessResult {
    SubscriptionAccessResult(selection: selection, access: .unconfirmed)
  }

  func refresh(for selection: AccountSelection) async -> SubscriptionAccessResult {
    await currentAccess(for: selection)
  }

  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult {
    throw SubscriptionOperationError.failed
  }

  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult {
    throw SubscriptionOperationError.failed
  }

  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult> {
    AsyncStream { $0.finish() }
  }
}
