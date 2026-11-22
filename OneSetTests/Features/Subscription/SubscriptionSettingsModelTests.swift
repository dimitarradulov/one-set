import Foundation
import Testing
@testable import OneSet

/// Holds a restore approval until the test releases it.
@MainActor
private final class GatedApproval: PaywallApproving {
  private var continuation: CheckedContinuation<PaywallApprovalDecision, Never>?

  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision { .approved }

  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    await withCheckedContinuation { continuation = $0 }
  }

  func release(for selection: AccountSelection) {}

  func waitForRequest() async {
    while continuation == nil { await Task.yield() }
  }

  func approve() {
    continuation?.resume(returning: .approved)
    continuation = nil
  }
}

@MainActor
struct SubscriptionSettingsModelTests {
  private let selection = AccountSelection(accountID: "user", generation: 1)
  private let future = Date(timeIntervalSince1970: 4_102_444_800)

  private final class SelectionBox {
    var value: AccountSelection?
    init(_ value: AccountSelection?) { self.value = value }
  }

  private struct Harness {
    let model: SubscriptionSettingsModel
    let service: ControllableSubscriptionAccessService
    let approval: FakePaywallApproval
    let box: SelectionBox
  }

  private func makeHarness(selection: AccountSelection? = nil) -> Harness {
    let box = SelectionBox(selection ?? self.selection)
    let service = ControllableSubscriptionAccessService()
    let approval = FakePaywallApproval()
    let model = SubscriptionSettingsModel(
      access: service, host: FakePaywallHost(), approval: approval, currentSelection: { box.value })
    return Harness(model: model, service: service, approval: approval, box: box)
  }

  private func settle() async {
    for _ in 0..<5 { await Task.yield() }
  }

  /// Starts a load and resolves its check with `access`.
  private func load(_ harness: Harness, resolving access: SubscriptionAccess) async {
    let task = Task { await harness.model.load() }
    await harness.service.waitForPendingCheck()
    harness.service.resolve(access)
    await task.value
  }

  @Test func showsCheckingUntilTheCheckResolves() async {
    let harness = makeHarness()
    let task = Task { await harness.model.load() }
    await harness.service.waitForPendingCheck()
    #expect(harness.model.status == .checking)
    #expect(harness.model.isBusy)
    #expect(harness.model.primaryAction == nil)
    harness.service.resolve(.proVerified(expiresAt: future))
    await task.value
    #expect(harness.model.status == .active)
    #expect(!harness.model.isBusy)
  }

  @Test(arguments: [
    (SubscriptionAccess.verifiedInactive, SubscriptionSettingsModel.Status.inactive, SubscriptionSettingsModel.PrimaryAction.seePlans),
    (.unconfirmed, .unconfirmed, .tryAgain),
    (.pendingApproval, .pending, .checkStatus)
  ])
  func mapsEachDecisionToItsStatusAndAction(
    access: SubscriptionAccess, status: SubscriptionSettingsModel.Status,
    action: SubscriptionSettingsModel.PrimaryAction
  ) async {
    let harness = makeHarness()
    await load(harness, resolving: access)
    #expect(harness.model.status == status)
    #expect(harness.model.primaryAction == action)
  }

  @Test func expiredProIsNotActive() async {
    let harness = makeHarness()
    await load(harness, resolving: .proVerified(expiresAt: Date(timeIntervalSince1970: 1)))
    #expect(harness.model.status == .unconfirmed)
  }

  @Test func noSelectionCannotBeConfirmed() async {
    let harness = makeHarness()
    harness.box.value = nil
    await harness.model.load()
    #expect(harness.model.status == .unconfirmed)
  }

  @Test func retryRunsAFreshCheck() async {
    let harness = makeHarness()
    await load(harness, resolving: .unconfirmed)
    let retry = Task { await harness.model.refresh() }
    await harness.service.waitForPendingCheck()
    #expect(harness.model.status == .checking)
    harness.service.resolve(.verifiedInactive)
    await retry.value
    #expect(harness.model.status == .inactive)
  }

  @Test func seePlansChecksAccessBeforeOpeningCheckout() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let open = Task { await harness.model.seePlans() }
    await harness.service.waitForPendingCheck()
    #expect(harness.model.paywall == nil)
    harness.service.resolve(.verifiedInactive)
    await open.value
    #expect(harness.model.paywall != nil)
  }

  @Test func seePlansDoesNotOpenWhenTheFreshCheckFindsPro() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let open = Task { await harness.model.seePlans() }
    await harness.service.waitForPendingCheck()
    harness.service.resolve(.proVerified(expiresAt: future))
    await open.value
    #expect(harness.model.paywall == nil)
    #expect(harness.model.status == .active)
  }

  @Test func seePlansDoesNotOpenWhenTheFreshCheckFails() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let open = Task { await harness.model.seePlans() }
    await harness.service.waitForPendingCheck()
    harness.service.fail()
    await open.value
    #expect(harness.model.paywall == nil)
    #expect(harness.model.status == .unconfirmed)
  }

  @Test func seePlansIsUnavailableUnlessInactive() async {
    let harness = makeHarness()
    await load(harness, resolving: .unconfirmed)
    await harness.model.seePlans()
    #expect(harness.model.paywall == nil)
    #expect(harness.service.checkCount == 1)
  }

  @Test func closingCheckoutRechecksAccess() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let open = Task { await harness.model.seePlans() }
    await harness.service.waitForPendingCheck()
    harness.service.resolve(.verifiedInactive)
    await open.value
    harness.model.paywall?.close()
    await harness.service.waitForPendingCheck()
    harness.service.resolve(.proVerified(expiresAt: future))
    await settle()
    #expect(harness.model.status == .active)
  }

  // MARK: Restore

  @Test func restoreGoesThroughApprovalAndReportsRestoredPro() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.service.restoreResult = .success(.proVerified(expiresAt: future))
    await harness.model.restorePurchases()
    #expect(harness.approval.restoreApprovals == 1)
    #expect(harness.approval.releaseCount == 1)
    #expect(harness.model.restore == .restored)
    #expect(harness.model.status == .active)
  }

  @Test func restoreWithoutPurchaseKeepsPlansAvailable() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.service.restoreResult = .success(.verifiedInactive)
    await harness.model.restorePurchases()
    #expect(harness.model.restore == .noPurchase)
    #expect(harness.model.primaryAction == .seePlans)
  }

  @Test func restoreLinkedToAnotherAccountShowsThatMessage() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.service.restoreResult = .failure(.linkedToAnotherAccount)
    await harness.model.restorePurchases()
    #expect(harness.model.restore == .linkedToAnotherAccount)
    #expect(harness.approval.releaseCount == 1)
  }

  @Test func failedRestoreIsReported() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.service.restoreResult = .failure(.failed)
    await harness.model.restorePurchases()
    #expect(harness.model.restore == .failed)
  }

  @Test func cancelledRestoreShowsNothing() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.service.restoreResult = .failure(.cancelled)
    await harness.model.restorePurchases()
    #expect(harness.model.restore == .idle)
  }

  @Test func restoreAwaitingApprovalMovesToPending() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.approval.restoreDecision = .pending
    await harness.model.restorePurchases()
    #expect(harness.model.status == .pending)
    #expect(harness.model.restore == .idle)
    #expect(harness.approval.releaseCount == 1)
  }

  @Test func deniedRestoreFails() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    harness.approval.restoreDecision = .denied(.operationInProgress)
    await harness.model.restorePurchases()
    #expect(harness.model.restore == .failed)
    #expect(harness.approval.releaseCount == 1)
  }

  @Test func restoreIsDisabledWhileCheckingAccess() async {
    let harness = makeHarness()
    let task = Task { await harness.model.load() }
    await harness.service.waitForPendingCheck()
    await harness.model.restorePurchases()
    #expect(harness.approval.restoreApprovals == 0)
    harness.service.resolve(.verifiedInactive)
    await task.value
  }

  @Test func accountChangeDropsALateRestoreApproval() async {
    let box = SelectionBox(selection)
    let service = ControllableSubscriptionAccessService()
    let approval = GatedApproval()
    let model = SubscriptionSettingsModel(
      access: service, host: FakePaywallHost(), approval: approval, currentSelection: { box.value })
    let loading = Task { await model.load() }
    await service.waitForPendingCheck()
    service.resolve(.verifiedInactive)
    await loading.value
    service.restoreResult = .success(.proVerified(expiresAt: future))
    let restoring = Task { await model.restorePurchases() }
    await approval.waitForRequest()
    #expect(model.restore == .restoring)
    box.value = AccountSelection(accountID: "other", generation: 2)
    service.resolve(.checking)
    let reload = Task { await model.load() }
    await service.waitForPendingCheck()
    approval.approve()
    await restoring.value
    #expect(model.status == .checking)
    #expect(model.restore == .idle)
    service.resolve(.verifiedInactive)
    await reload.value
    #expect(model.status == .inactive)
  }

  @Test func newAccountResetsStatusAndClosesCheckout() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let open = Task { await harness.model.seePlans() }
    await harness.service.waitForPendingCheck()
    harness.service.resolve(.verifiedInactive)
    await open.value
    harness.box.value = AccountSelection(accountID: "other", generation: 2)
    harness.service.resolve(.checking)
    let reload = Task { await harness.model.load() }
    await harness.service.waitForPendingCheck()
    #expect(harness.model.paywall == nil)
    #expect(harness.model.status == .checking)
    harness.service.resolve(.pendingApproval)
    await reload.value
    #expect(harness.model.status == .pending)
  }

  @Test func ignoresDecisionsForAnotherSelection() async {
    let harness = makeHarness()
    await load(harness, resolving: .verifiedInactive)
    let observing = Task { await harness.model.observeUpdates() }
    await settle()
    harness.service.set(.pendingApproval, for: AccountSelection(accountID: "user", generation: 0))
    await settle()
    #expect(harness.model.status == .inactive)
    harness.service.set(.pendingApproval, for: selection)
    await settle()
    #expect(harness.model.status == .pending)
    observing.cancel()
  }
}
