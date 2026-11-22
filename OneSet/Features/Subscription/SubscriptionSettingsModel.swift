import Foundation
import Observation

/// Coordinates the Settings Subscription screen: the access status, Restore Purchases through
/// the shared account owner's approval, and the checkout sheet. Results from an earlier account
/// selection are dropped.
@MainActor @Observable
final class SubscriptionSettingsModel {
  enum Status: Equatable {
    case checking, active, inactive, unconfirmed, pending
  }

  enum Restore: Equatable {
    case idle, restoring, restored, noPurchase, linkedToAnotherAccount, failed
  }

  private(set) var status: Status = .checking
  private(set) var restore: Restore = .idle
  /// The checkout sheet, presented through `paywallSheet(model:)`.
  var paywall: PaywallModel?

  private let access: any SubscriptionAccessService
  private let host: any PaywallHost
  private let approval: any PaywallApproving
  private let currentSelection: @MainActor () -> AccountSelection?
  private var loadedSelection: AccountSelection?
  /// Bumps when the account changes or a newer check starts, so older replies are ignored.
  private var epoch = 0

  init(
    access: any SubscriptionAccessService,
    host: any PaywallHost,
    approval: any PaywallApproving,
    currentSelection: @escaping @MainActor () -> AccountSelection?
  ) {
    self.access = access
    self.host = host
    self.approval = approval
    self.currentSelection = currentSelection
  }

  /// Uses the selection owned by `access` when it tracks one.
  convenience init(access: any SubscriptionAccessService, host: any PaywallHost, approval: any PaywallApproving) {
    self.init(access: access, host: host, approval: approval) {
      (access as? any SubscriptionAccountSelecting)?.selection
    }
  }

  /// True while Restore Purchases must stay disabled.
  var isBusy: Bool {
    status == .checking || restore == .restoring
  }

  /// The one action beside the status: plans, a retry, or a status check.
  var primaryAction: PrimaryAction? {
    guard restore != .restoring else { return nil }
    switch status {
    case .inactive: return .seePlans
    case .unconfirmed: return .tryAgain
    case .pending: return .checkStatus
    case .checking, .active: return nil
    }
  }

  enum PrimaryAction: Equatable {
    case seePlans, tryAgain, checkStatus

    var title: String {
      switch self {
      case .seePlans: "See plans"
      case .tryAgain: "Try Again"
      case .checkStatus: "Check status"
      }
    }
  }

  // MARK: Loading

  /// Loads access for the current account. A different account resets all earlier state.
  func load() async {
    guard let selection = currentSelection() else {
      reset()
      loadedSelection = nil
      status = .unconfirmed
      return
    }
    if selection != loadedSelection {
      reset()
      loadedSelection = selection
      status = .checking
    }
    let token = epoch
    let result = await access.currentAccess(for: selection)
    guard token == epoch, result.applies(to: currentSelection()) else { return }
    apply(result.access)
  }

  /// Applies later decisions, such as pending approval resolving outside the app.
  func observeUpdates() async {
    guard let selection = currentSelection() else { return }
    for await result in access.updates(for: selection) {
      guard result.applies(to: currentSelection()), restore != .restoring, paywall == nil else { continue }
      apply(result.access)
    }
  }

  /// Runs a fresh check. Retry and Check status use it.
  func refresh() async {
    guard let selection = currentSelection() else {
      status = .unconfirmed
      return
    }
    guard restore != .restoring else { return }
    loadedSelection = selection
    epoch += 1
    let token = epoch
    restore = .idle
    status = .checking
    let result = await access.refresh(for: selection)
    guard token == epoch, result.applies(to: currentSelection()) else { return }
    apply(result.access)
  }

  // MARK: Restore

  func restorePurchases() async {
    guard !isBusy, let selection = currentSelection() else { return }
    let token = epoch
    restore = .restoring
    let decision = await approval.approveRestore(for: selection)
    // Approval holds the operation until released; every outcome below ends it.
    defer { approval.release(for: selection) }
    guard token == epoch, selection == currentSelection() else { return }
    guard await handleApproval(decision) else { return }
    do {
      let outcome = try await access.restore(for: selection)
      guard token == epoch, outcome.applies(to: currentSelection()) else { return }
      applyRestore(outcome.access)
    } catch {
      guard token == epoch, selection == currentSelection() else { return }
      switch error as? SubscriptionOperationError {
      case .cancelled: restore = .idle
      case .linkedToAnotherAccount: restore = .linkedToAnotherAccount
      default: restore = .failed
      }
    }
  }

  /// Returns true when the restore may run.
  private func handleApproval(_ decision: PaywallApprovalDecision) async -> Bool {
    switch decision {
    case .approved:
      return true
    case .pending:
      restore = .idle
      status = .pending
    case .denied(.alreadyActive):
      restore = .idle
      await refresh()
    case .denied(.accountChanged):
      restore = .idle
    case .denied:
      restore = .failed
    }
    return false
  }

  private func applyRestore(_ decision: SubscriptionAccess) {
    switch decision {
    case .proVerified where decision.allowsNewWorkout():
      status = .active
      restore = .restored
    case .verifiedInactive:
      status = .inactive
      restore = .noPurchase
    default:
      restore = .idle
      apply(decision)
    }
  }

  // MARK: Checkout

  /// Settings checks access first: plans open only after a fresh check verifies no active Pro.
  func seePlans() async {
    guard status == .inactive, restore != .restoring, paywall == nil, let selection = currentSelection() else { return }
    loadedSelection = selection
    epoch += 1
    let token = epoch
    status = .checking
    let result = await access.refresh(for: selection)
    guard token == epoch, result.applies(to: currentSelection()) else { return }
    apply(result.access)
    guard result.access.allowsCheckout else { return }
    paywall = PaywallModel(
      selection: selection, currentSelection: currentSelection, access: access, host: host,
      approval: approval,
      onResult: { [weak self] _ in
        // Whatever the sheet reported, show what a fresh check says.
        Task { await self?.refresh() }
      })
  }

  // MARK: Helpers

  private func reset() {
    epoch += 1
    restore = .idle
    paywall = nil
  }

  private func apply(_ decision: SubscriptionAccess) {
    switch decision {
    case .proVerified where decision.allowsNewWorkout(): status = .active
    case .proVerified, .unconfirmed: status = .unconfirmed
    case .verifiedInactive: status = .inactive
    case .checking: status = .checking
    case .pendingApproval: status = .pending
    }
  }
}
