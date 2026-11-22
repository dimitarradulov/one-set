import Foundation

/// Identifies one active account selection. Results from an earlier selection
/// must be dropped, even when the same account signs back in.
struct AccountSelection: Hashable, Sendable {
  let accountID: String
  let generation: Int
}

/// The single decision that gates new workouts and checkout.
enum SubscriptionAccess: Equatable, Sendable {
  /// Pro verified through the given expiry date.
  case proVerified(expiresAt: Date)
  /// A fresh check verified that no Pro access is active.
  case verifiedInactive
  /// A check is in progress.
  case checking
  /// Access cannot be confirmed because the check failed or is unconfigured.
  /// Saved inactive records also map here, because checkout needs a fresh check.
  case unconfirmed
  /// A purchase is waiting for approval or a charge is unresolved.
  case pendingApproval

  /// A new workout needs Pro verified through a future date. Valid saved access counts offline.
  func allowsNewWorkout(at now: Date = .now) -> Bool {
    guard case .proVerified(let expiresAt) = self else { return false }
    return expiresAt > now
  }

  /// Checkout is offered only after a fresh verified-inactive result with no pending payment.
  var allowsCheckout: Bool {
    self == .verifiedInactive
  }
}

/// An access decision tagged with the selection it was produced for.
struct SubscriptionAccessResult: Equatable, Sendable {
  let selection: AccountSelection
  let access: SubscriptionAccess

  func applies(to current: AccountSelection?) -> Bool {
    selection == current
  }
}

/// A purchasable package, identified by its offering package identifier.
struct SubscriptionPackage: Hashable, Sendable {
  let id: String
}

enum SubscriptionOperationError: Error, Equatable, Sendable {
  case cancelled
  case linkedToAnotherAccount
  case operationInProgress
  case failed
}
