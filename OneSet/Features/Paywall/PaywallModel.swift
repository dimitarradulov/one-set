import Foundation
import Observation

/// Coordinates the parent-owned checkout sheet: offering checks, approval hooks, purchase
/// and restore verification. Callers read one `PaywallResult` through `onResult`.
@MainActor @Observable
final class PaywallModel: Identifiable {
  enum Operation: Equatable {
    case purchase, restore
  }

  enum Phase: Equatable {
    case loading
    case ready
    case unavailable
    case verifying(Operation)
    case verifyFailed(Operation)
    case pending
    case active
  }

  enum Banner: Equatable {
    case noPurchase
    case linkedToAnotherAccount
    case purchaseFailed
    case restoreFailed
    case checkoutUnavailable

    var title: String {
      switch self {
      case .noPurchase: "No active purchases found"
      case .linkedToAnotherAccount: "Restore unavailable"
      case .purchaseFailed: "Purchase did not complete"
      case .restoreFailed: "Restore did not complete"
      case .checkoutUnavailable: "Checkout is not available"
      }
    }

    var message: String {
      switch self {
      case .noPurchase: "We did not find an active Apple subscription for this Apple Account."
      case .linkedToAnotherAccount:
        "This subscription is linked to another OneSet account. Sign in to that account to use Pro."
      case .purchaseFailed, .restoreFailed: "Nothing was charged. Please try again."
      case .checkoutUnavailable: "Close this screen and try again in a moment."
      }
    }
  }

  static let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")

  let id = UUID()
  private(set) var phase: Phase = .loading
  private(set) var banner: Banner?
  private(set) var offering: PaywallOffering?
  private(set) var result: PaywallResult?

  let host: any PaywallHost
  private let selection: AccountSelection
  private let currentSelection: @MainActor () -> AccountSelection?
  private let access: any SubscriptionAccessService
  private let approval: any PaywallApproving
  private let onResult: @MainActor (PaywallResult) -> Void
  private var hasStarted = false
  private var purchaseConfirmed = false
  private var operationInFlight = false
  /// True only while an approved purchase or embedded restore holds the owner's operation slot.
  private var holdsSlot = false

  init(
    selection: AccountSelection,
    currentSelection: @escaping @MainActor () -> AccountSelection?,
    access: any SubscriptionAccessService,
    host: any PaywallHost,
    approval: any PaywallApproving,
    onResult: @escaping @MainActor (PaywallResult) -> Void
  ) {
    self.selection = selection
    self.currentSelection = currentSelection
    self.access = access
    self.host = host
    self.approval = approval
    self.onResult = onResult
  }

  /// True while Restore Purchases must stay disabled.
  var isBusy: Bool {
    if case .verifying = phase { return true }
    return phase == .active || operationInFlight
  }

  /// Hands the embedded paywall's callbacks to the host.
  var events: PaywallEvents {
    PaywallEvents(
      purchaseInitiated: { [weak self] package in await self?.beginPurchase(package) ?? false },
      restoreInitiated: { [weak self] in await self?.beginPaywallRestore() ?? false },
      purchaseCompleted: { [weak self] in self?.purchaseDidComplete() },
      purchaseCancelled: { [weak self] in self?.endOperation(.cancelled) },
      purchasePending: { [weak self] in self?.moveToPending() },
      restoreCompleted: { [weak self] in self?.restoreDidComplete() },
      failed: { [weak self] in self?.operationDidFail($0) },
      dismissRequested: { [weak self] in self?.close() }
    )
  }

  // MARK: Loading

  func start() async {
    guard !hasStarted else { return }
    hasStarted = true
    await loadOffering()
  }

  func retryOffering() async {
    guard phase == .unavailable else { return }
    phase = .loading
    await loadOffering()
  }

  private func loadOffering() async {
    do {
      let loaded = try await host.loadOffering()
      guard isCurrent else { return }
      offering = loaded
      phase = loaded.missingPackageIDs.isEmpty ? .ready : .unavailable
    } catch {
      guard isCurrent else { return }
      offering = nil
      phase = .unavailable
    }
  }

  // MARK: Parent controls

  /// Verifies Pro again without reopening checkout.
  func tryAgain() async {
    switch phase {
    case .verifyFailed(let operation): await verify(after: operation)
    case .pending: await verify(after: .purchase, fromPending: true)
    case .unavailable: await retryOffering()
    default: break
    }
  }

  func restorePurchases() async {
    guard !isBusy, phase != .loading else { return }
    let previous = phase
    banner = nil
    operationInFlight = true
    switch await approval.preflightRestore(for: selection) {
    case .approved: break
    case .pending: moveToPending(); return
    case .denied(let denial): handleDenial(denial); return
    }
    guard isCurrent else { return }
    phase = .verifying(.restore)
    do {
      let outcome = try await access.restore(for: selection)
      guard isCurrent, outcome.applies(to: selection) else { return }
      endOperation()
      apply(outcome.access, after: .restore) {
        self.phase = previous
        self.banner = .noPurchase
      }
    } catch {
      guard isCurrent else { return }
      endOperation()
      phase = previous
      switch error as? SubscriptionOperationError {
      case .cancelled: banner = nil
      case .linkedToAnotherAccount: banner = .linkedToAnotherAccount
      default: banner = .restoreFailed
      }
    }
  }

  func close() {
    finish(closeResult)
  }

  /// Reports the sheet disappearing, for example by swipe, when no result was sent yet.
  func dismiss() {
    close()
  }

  func done() {
    finish(phase == .active ? .verifiedPro : closeResult)
  }

  private var closeResult: PaywallResult {
    switch phase {
    case .active: .verifiedPro
    case .pending, .verifyFailed, .verifying: .unresolved
    default: purchaseConfirmed ? .unresolved : .closed
    }
  }

  // MARK: Embedded paywall events

  private func beginPurchase(_ package: SubscriptionPackage) async -> Bool {
    guard phase == .ready, !operationInFlight else {
      banner = .checkoutUnavailable
      return false
    }
    banner = nil
    operationInFlight = true
    switch await approval.approvePurchase(package, for: selection) {
    case .approved:
      holdsSlot = true
      guard isCurrent, phase == .ready else {
        endOperation(.cancelled)
        return false
      }
      return true
    case .pending:
      moveToPending()
      return false
    case .denied(let denial):
      handleDenial(denial)
      return false
    }
  }

  private func beginPaywallRestore() async -> Bool {
    guard phase == .ready else { return false }
    banner = nil
    switch await approval.approveRestore(for: selection) {
    case .approved:
      operationInFlight = true
      holdsSlot = true
      guard isCurrent else {
        endOperation(.cancelled)
        return false
      }
      return true
    case .pending:
      moveToPending()
      return false
    case .denied(let denial):
      handleDenial(denial)
      return false
    }
  }

  private func purchaseDidComplete() {
    purchaseConfirmed = true
    endOperation(.succeeded)
    Task { await verify(after: .purchase) }
  }

  private func restoreDidComplete() {
    endOperation(.succeeded)
    Task { await verify(after: .restore) }
  }

  private func moveToPending() {
    endOperation(.pendingApproval)
    guard isCurrent else { return }
    phase = .pending
  }

  private func operationDidFail(_ failure: PaywallFailure) {
    endOperation(.failed(failure == .linkedToAnotherAccount ? .linkedToAnotherAccount : .failed))
    banner = failure == .linkedToAnotherAccount ? .linkedToAnotherAccount : .purchaseFailed
  }

  private func handleDenial(_ denial: PaywallDenial) {
    endOperation()
    guard isCurrent else { return }
    if denial == .alreadyActive {
      Task { await verify(after: .restore) }
    } else {
      banner = .checkoutUnavailable
    }
  }

  // MARK: Verification

  private func verify(after operation: Operation, fromPending: Bool = false) async {
    guard isCurrent else { return }
    phase = .verifying(operation)
    let outcome = await access.refresh(for: selection)
    guard isCurrent, outcome.applies(to: selection) else { return }
    apply(outcome.access, after: operation) {
      // A fresh check found nothing pending and no Pro, so checkout may start again.
      if fromPending { self.phase = self.offering == nil ? .unavailable : .ready }
    }
  }

  /// `onInactive` handles a verified-inactive result; without it, inactivity after payment is a failure.
  private func apply(_ decision: SubscriptionAccess, after operation: Operation, onInactive: () -> Void) {
    switch decision {
    case .proVerified where decision.allowsNewWorkout():
      phase = .active
      banner = nil
    case .pendingApproval:
      phase = .pending
    case .verifiedInactive:
      phase = .verifyFailed(operation)
      onInactive()
    default:
      phase = .verifyFailed(operation)
    }
  }

  // MARK: Helpers

  private var isCurrent: Bool {
    guard result == nil else { return false }
    if currentSelection() == selection { return true }
    finish(.closed)
    return false
  }

  /// Clears the busy state and, when this paywall holds the owner's slot, releases it once.
  private func endOperation(_ result: PaywallOperationResult = .cancelled) {
    operationInFlight = false
    guard holdsSlot else { return }
    holdsSlot = false
    approval.release(result, for: selection)
  }

  private func finish(_ outcome: PaywallResult) {
    guard result == nil else { return }
    endOperation(.cancelled)
    result = outcome
    onResult(outcome)
  }
}
