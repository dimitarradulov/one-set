import Foundation

/// Why the account owner refused to start a purchase or restore.
enum PaywallDenial: Equatable, Sendable {
  /// Another purchase or restore is already running.
  case operationInProgress
  /// The account selection changed since the paywall opened.
  case accountChanged
  /// A fresh check found Pro already active, so checkout is not needed.
  case alreadyActive
  /// The operation could not be approved for another reason.
  case unavailable
}

enum PaywallApprovalDecision: Equatable, Sendable {
  case approved
  /// A payment or approval is still unresolved for this account, so checkout stays closed.
  case pending
  case denied(PaywallDenial)
}

/// The seam where the app-scoped account owner approves paywall purchases and restores (#97).
/// The paywall calls `release(for:)` when an approved operation succeeds, fails, is cancelled,
/// or moves to pending approval.
@MainActor
protocol PaywallApproving {
  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async -> PaywallApprovalDecision
  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision
  func release(for selection: AccountSelection)
}

/// Used until the account owner is wired: nothing can be purchased or restored.
@MainActor
struct UnconfiguredPaywallApproval: PaywallApproving {
  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision {
    .denied(.unavailable)
  }

  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    .denied(.unavailable)
  }

  func release(for selection: AccountSelection) {}
}
