import Foundation
import Testing
@testable import OneSet

@MainActor
final class FakePaywallApproval: PaywallApproving {
  var purchaseDecision: PaywallApprovalDecision = .approved
  var restoreDecision: PaywallApprovalDecision = .approved
  private(set) var releaseCount = 0
  private(set) var approvedPurchases: [SubscriptionPackage] = []
  private(set) var restoreApprovals = 0

  func approvePurchase(_ package: SubscriptionPackage, for selection: AccountSelection) async
    -> PaywallApprovalDecision {
    approvedPurchases.append(package)
    return purchaseDecision
  }

  func approveRestore(for selection: AccountSelection) async -> PaywallApprovalDecision {
    restoreApprovals += 1
    return restoreDecision
  }

  func release(for selection: AccountSelection) { releaseCount += 1 }
}

@MainActor
struct PaywallModelTests {
  private let selection = AccountSelection(accountID: "user", generation: 1)
  private let future = Date(timeIntervalSince1970: 4_102_444_800)

  private struct Harness {
    let model: PaywallModel
    let service: ControllableSubscriptionAccessService
    let host: FakePaywallHost
    let approval: FakePaywallApproval
    let results: ResultLog
  }

  @MainActor final class ResultLog { var values: [PaywallResult] = [] }

  private func makeHarness(
    offering: Result<PaywallOffering, PaywallOfferingError> = .success(.complete)
  ) -> Harness {
    let service = ControllableSubscriptionAccessService()
    let host = FakePaywallHost(offering: offering)
    let approval = FakePaywallApproval()
    let results = ResultLog()
    let selection = selection
    let model = PaywallModel(
      selection: selection, currentSelection: { selection }, access: service, host: host,
      approval: approval, onResult: { results.values.append($0) })
    return Harness(model: model, service: service, host: host, approval: approval, results: results)
  }

  private func settle() async {
    for _ in 0..<5 { await Task.yield() }
  }

  @Test func loadsNamedOfferingWithBothPackages() async {
    let harness = makeHarness()
    await harness.model.start()
    #expect(harness.model.phase == .ready)
    #expect(harness.host.loadCount == 1)
  }

  @Test func missingOfferingKeepsParentControlsAndRetries() async {
    let harness = makeHarness(offering: .failure(.missingOffering))
    await harness.model.start()
    #expect(harness.model.phase == .unavailable)
    #expect(!harness.model.isBusy)
    harness.host.offering = .success(.complete)
    await harness.model.tryAgain()
    #expect(harness.model.phase == .ready)
  }

  @Test func missingPackageIsUnavailable() async {
    let partial = PaywallOffering(identifier: "default", packageIDs: [PaywallCatalog.monthlyPackageID])
    let harness = makeHarness(offering: .success(partial))
    await harness.model.start()
    #expect(harness.model.phase == .unavailable)
    #expect(partial.missingPackageIDs == [PaywallCatalog.annualPackageID])
  }

  @Test func closeWorksWithoutOfferingAndReportsClosed() async {
    let harness = makeHarness(offering: .failure(.loadFailed))
    await harness.model.start()
    harness.model.close()
    #expect(harness.results.values == [.closed])
    harness.model.dismiss()
    #expect(harness.results.values == [.closed])
  }

  @Test func cancelledPurchaseReleasesAndReportsClosed() async {
    let harness = makeHarness()
    await harness.model.start()
    let proceed = await harness.model.events.purchaseInitiated(SubscriptionPackage(id: "$rc_monthly"))
    #expect(proceed)
    harness.model.events.purchaseCancelled()
    #expect(harness.approval.releaseCount == 1)
    #expect(harness.model.phase == .ready)
    harness.model.close()
    #expect(harness.results.values == [.closed])
  }

  @Test func purchaseRoutesThroughApprovalHook() async {
    let harness = makeHarness()
    await harness.model.start()
    harness.approval.purchaseDecision = .denied(.operationInProgress)
    let proceed = await harness.model.events.purchaseInitiated(SubscriptionPackage(id: "$rc_annual"))
    #expect(!proceed)
    #expect(harness.approval.approvedPurchases == [SubscriptionPackage(id: "$rc_annual")])
    #expect(harness.model.banner == .checkoutUnavailable)
    #expect(harness.model.phase == .ready)
  }

  @Test func pendingApprovalBlocksCheckoutAndReportsUnresolved() async {
    let harness = makeHarness()
    await harness.model.start()
    harness.approval.purchaseDecision = .pending
    let proceed = await harness.model.events.purchaseInitiated(SubscriptionPackage(id: "$rc_monthly"))
    #expect(!proceed)
    #expect(harness.model.phase == .pending)
    #expect(harness.approval.releaseCount == 1)
    harness.model.close()
    #expect(harness.results.values == [.unresolved])
  }

  @Test func restoreAlsoGoesThroughApproval() async {
    let harness = makeHarness()
    await harness.model.start()
    harness.approval.restoreDecision = .pending
    await harness.model.restorePurchases()
    #expect(harness.approval.restoreApprovals == 1)
    #expect(harness.model.phase == .pending)
  }

  @Test func purchaseShowsSpinnerThenVerifiedProAfterDone() async {
    let harness = makeHarness()
    await harness.model.start()
    _ = await harness.model.events.purchaseInitiated(SubscriptionPackage(id: "$rc_monthly"))
    harness.model.events.purchaseCompleted()
    await harness.service.waitForPendingCheck()
    #expect(harness.model.phase == .verifying(.purchase))
    #expect(harness.model.isBusy)
    harness.service.resolve(.proVerified(expiresAt: future))
    await settle()
    #expect(harness.model.phase == .active)
    harness.model.done()
    #expect(harness.results.values == [.verifiedPro])
  }

  @Test func verificationFailureThenTryAgainDoesNotReopenCheckout() async {
    let harness = makeHarness()
    await harness.model.start()
    _ = await harness.model.events.purchaseInitiated(SubscriptionPackage(id: "$rc_annual"))
    harness.model.events.purchaseCompleted()
    await harness.service.waitForPendingCheck()
    harness.service.fail()
    await settle()
    #expect(harness.model.phase == .verifyFailed(.purchase))

    let retry = Task { await harness.model.tryAgain() }
    await harness.service.waitForPendingCheck()
    #expect(harness.model.phase == .verifying(.purchase))
    harness.service.resolve(.proVerified(expiresAt: future))
    await retry.value
    #expect(harness.model.phase == .active)
    #expect(harness.approval.approvedPurchases.count == 1)
  }

  @Test func closingAfterFailedVerificationIsUnresolved() async {
    let harness = makeHarness()
    await harness.model.start()
    harness.model.events.purchaseCompleted()
    await harness.service.waitForPendingCheck()
    harness.service.fail()
    await settle()
    harness.model.close()
    #expect(harness.results.values == [.unresolved])
  }

  @Test func restoreWithNothingToRestoreShowsBannerAndKeepsCheckout() async {
    let harness = makeHarness()
    await harness.model.start()
    harness.service.restoreResult = .success(.verifiedInactive)
    await harness.model.restorePurchases()
    #expect(harness.model.banner == .noPurchase)
    #expect(harness.model.phase == .ready)
  }

  @Test func restoreLinkedToAnotherAccountShowsMismatch() async {
    let harness = makeHarness(offering: .failure(.missingOffering))
    await harness.model.start()
    harness.service.restoreResult = .failure(.linkedToAnotherAccount)
    await harness.model.restorePurchases()
    #expect(harness.model.banner == .linkedToAnotherAccount)
    #expect(harness.model.phase == .unavailable)
    #expect(harness.approval.releaseCount == 1)
  }

  @Test func restoreSucceedingActivatesPro() async {
    let harness = makeHarness(offering: .failure(.missingOffering))
    await harness.model.start()
    harness.service.restoreResult = .success(.proVerified(expiresAt: future))
    await harness.model.restorePurchases()
    #expect(harness.model.phase == .active)
    harness.model.close()
    #expect(harness.results.values == [.verifiedPro])
  }

  @Test func staleSelectionClosesWithoutApplyingResults() async {
    let service = ControllableSubscriptionAccessService()
    var current: AccountSelection? = selection
    let results = ResultLog()
    let model = PaywallModel(
      selection: selection, currentSelection: { current }, access: service, host: FakePaywallHost(),
      approval: FakePaywallApproval(), onResult: { results.values.append($0) })
    await model.start()
    model.events.purchaseCompleted()
    await service.waitForPendingCheck()
    current = AccountSelection(accountID: "user", generation: 2)
    service.resolve(.proVerified(expiresAt: future))
    await settle()
    #expect(results.values == [.closed])
    #expect(model.phase != .active)
  }
}
