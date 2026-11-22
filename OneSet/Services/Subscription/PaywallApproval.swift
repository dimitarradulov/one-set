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

/// The seam where the app-scoped account owner approves paywall purchases and restores.
/// An approved purchase or embedded restore holds the owner's single operation slot. The
/// paywall calls `release(_:for:)` exactly once per approval, with how the operation ended:
/// success, cancel, failure, pending approval, or the paywall closing without any callback
/// (reported as cancelled). Denied approvals hold nothing and are never released.
@MainActor
protocol PaywallApproving {
  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async -> PaywallApprovalDecision
  /// Approves a restore started inside the embedded paywall. Holds the slot when approved.
  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision
  /// Checks a restore the parent screen runs itself through `SubscriptionAccessService.restore`.
  /// Holds no slot, because the service claims its own.
  func preflightRestore(for selection: AccountSelection) async -> PaywallApprovalDecision
  func release(_ result: PaywallOperationResult, for selection: AccountSelection)
}

/// Used when no account owner is available: nothing can be purchased or restored.
@MainActor
struct UnconfiguredPaywallApproval: PaywallApproving {
  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision {
    .denied(.unavailable)
  }

  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    .denied(.unavailable)
  }

  func preflightRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    .denied(.unavailable)
  }

  func release(_ result: PaywallOperationResult, for selection: AccountSelection) {}
}

/// The owner behind both the access check and the operation slot.
typealias SubscriptionOperationOwner = SubscriptionAccessService & SubscriptionOperationApproving
  & SubscriptionAccountSelecting

/// Approves paywall operations through the account owner and releases its slot with the result.
@MainActor
final class OwnerPaywallApproval: PaywallApproving {
  private let owner: any SubscriptionOperationOwner
  private var releases: [Task<Void, Never>] = []

  init(owner: any SubscriptionOperationOwner) {
    self.owner = owner
  }

  /// The owner-backed approval when `service` is the account owner, otherwise the refusing
  /// fallback, so previews and tests that inject fakes never reach RevenueCat.
  static func make(for service: any SubscriptionAccessService) -> any PaywallApproving {
    guard let owner = service as? any SubscriptionOperationOwner else { return UnconfiguredPaywallApproval() }
    return OwnerPaywallApproval(owner: owner)
  }

  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision {
    if await owner.onPurchaseInitiated(for: selection) { return .approved }
    return await refusal(for: selection)
  }

  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    if await owner.onRestoreInitiated(for: selection) { return .approved }
    return await refusal(for: selection)
  }

  func preflightRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    owner.selection == selection ? .approved : .denied(.accountChanged)
  }

  func release(_ result: PaywallOperationResult, for selection: AccountSelection) {
    let owner = owner
    releases.append(Task { _ = await owner.paywallOperationFinished(result, for: selection) })
  }

  /// Suspends until every release started so far has reached the owner.
  func waitForReleases() async {
    for task in releases { await task.value }
    releases = []
  }

  private func refusal(for selection: AccountSelection) async -> PaywallApprovalDecision {
    guard owner.selection == selection else { return .denied(.accountChanged) }
    switch await owner.currentAccess(for: selection).access {
    case .proVerified: return .denied(.alreadyActive)
    case .pendingApproval: return .pending
    default: return .denied(.operationInProgress)
    }
  }
}
