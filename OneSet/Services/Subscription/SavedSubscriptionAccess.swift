import Foundation

/// Applies the saved-expiry rules on top of a store. The owner declares the established
/// account selection; records are written and read only for that selection.
@MainActor
final class SavedSubscriptionAccess {
  private let store: any SavedSubscriptionAccessStore
  private let environment: BillingEnvironment
  private var current: AccountSelection?

  init(store: any SavedSubscriptionAccessStore, environment: BillingEnvironment) {
    self.store = store
    self.environment = environment
  }

  /// Declares the signed-in account selection, or nil when none is established.
  func select(_ selection: AccountSelection?) {
    current = selection
  }

  /// Accepts an observation for the current selection. Returns whether the saved record changed.
  @discardableResult
  func record(_ observation: SubscriptionObservation, checkedAt: Date, for selection: AccountSelection) -> Bool {
    guard selection == current else { return false }
    let status: SavedSubscriptionRecord.Status
    switch observation {
    case .verifiedActive(let expiresAt): status = .active(expiresAt: expiresAt)
    case .verifiedInactive: status = .inactive
    case .onDeviceOnly, .failed: return false
    }
    if let saved = try? store.load(accountID: selection.accountID, environment: environment),
      saved.checkedAt >= checkedAt {
      return false
    }
    let record = SavedSubscriptionRecord(checkedAt: checkedAt, status: status)
    do {
      try store.save(record, accountID: selection.accountID, environment: environment)
      return true
    } catch {
      return false
    }
  }

  /// The offline decision. Only an unexpired saved active record grants access. Inactive,
  /// expired, missing, unreadable, or mismatched-selection records yield `.unconfirmed`,
  /// so checkout still needs a fresh check.
  func access(for selection: AccountSelection, now: Date = .now) -> SubscriptionAccess {
    guard selection == current,
      let saved = try? store.load(accountID: selection.accountID, environment: environment),
      case .active(let expiresAt) = saved.status,
      expiresAt > now
    else { return .unconfirmed }
    return .proVerified(expiresAt: expiresAt)
  }

  /// Removes saved access after a confirmed sign-out.
  func removeAfterConfirmedSignOut(accountID: String) throws {
    try store.removeAll(accountID: accountID)
  }

  /// Entry point for account deletion (#103).
  func removeForDeletedAccount(accountID: String) throws {
    try store.removeAll(accountID: accountID)
  }
}
