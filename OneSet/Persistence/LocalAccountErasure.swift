import Foundation

/// One step of erasing a departing account from this device.
@MainActor
protocol AccountDeletionCleanup {
  /// Removes everything this step holds for the account. Other accounts are never touched.
  func erase(accountID: String) throws
}

/// Reports every step that failed after all steps ran.
struct LocalAccountErasureError: Error, LocalizedError {
  let failures: [any Error]

  var errorDescription: String? {
    "Some data for this account could not be removed from this device."
  }
}

/// Runs each cleanup step for the account. A failing step never stops the later steps, so a
/// failure cannot leave the device half-erased. New steps are added to the list, not to this type.
@MainActor
struct LocalAccountErasure {
  private let steps: [any AccountDeletionCleanup]

  init(steps: [any AccountDeletionCleanup]) {
    self.steps = steps
  }

  /// Runs every step, then throws `LocalAccountErasureError` if any step failed.
  func erase(accountID: String) throws {
    var failures: [any Error] = []
    for step in steps {
      do {
        try step.erase(accountID: accountID)
      } catch {
        failures.append(error)
      }
    }
    if !failures.isEmpty { throw LocalAccountErasureError(failures: failures) }
  }

  /// The steps every account needs: billing for the account, workout data, onboarding progress,
  /// saved subscription access, and pending subscription operations.
  static func standard(
    repository: WorkoutRepository,
    onboardingProgress: any OnboardingProgressStore,
    savedSubscriptionAccess: any SavedSubscriptionAccessStore,
    pendingSubscriptionOperations: any PendingSubscriptionOperationStore,
    subscriptionAccounts: (any SubscriptionAccountSelecting)? = nil
  ) -> LocalAccountErasure {
    LocalAccountErasure(steps: [
      SubscriptionBillingCleanup(accounts: subscriptionAccounts),
      repository,
      OnboardingProgressCleanup(store: onboardingProgress),
      SavedSubscriptionAccessCleanup(store: savedSubscriptionAccess),
      PendingSubscriptionOperationCleanup(store: pendingSubscriptionOperations),
    ])
  }
}

extension WorkoutRepository: AccountDeletionCleanup {
  func erase(accountID: String) throws {
    try eraseAccount(accountID: accountID)
  }
}

private struct OnboardingProgressCleanup: AccountDeletionCleanup {
  let store: any OnboardingProgressStore
  func erase(accountID: String) throws { try store.remove(accountID: accountID) }
}

/// Clears the departing account's subscription selection. Purchases and restores for that
/// selection are then refused, and its access held in memory is dropped, even if sign-out fails.
struct SubscriptionBillingCleanup: AccountDeletionCleanup {
  let accounts: (any SubscriptionAccountSelecting)?
  func erase(accountID: String) throws {
    guard let accounts, accounts.selection?.accountID == accountID else { return }
    accounts.selectAccount(nil)
  }
}

private struct SavedSubscriptionAccessCleanup: AccountDeletionCleanup {
  let store: any SavedSubscriptionAccessStore
  func erase(accountID: String) throws { try store.removeAll(accountID: accountID) }
}

private struct PendingSubscriptionOperationCleanup: AccountDeletionCleanup {
  let store: any PendingSubscriptionOperationStore
  func erase(accountID: String) throws { try store.remove(accountID: accountID) }
}
