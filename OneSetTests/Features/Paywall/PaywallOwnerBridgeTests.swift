import Foundation
import Testing
@testable import OneSet

/// The paywall model driving the real account owner with a fake SDK client: every way an
/// approved operation can end must release the owner's single operation slot.
@MainActor
struct PaywallOwnerBridgeTests {
  private let expiry = Date(timeIntervalSince1970: 1_800_086_400)
  private let monthly = SubscriptionPackage(id: "$rc_monthly")

  private struct Harness {
    let model: PaywallModel
    let service: RevenueCatSubscriptionAccessService
    let approval: OwnerPaywallApproval
    let client: FakePurchasesClient
    let selection: AccountSelection
    let results: ResultLog
  }

  @MainActor final class ResultLog { var values: [PaywallResult] = [] }

  private func makeHarness() async -> Harness {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: false))
    var ticks = 0.0
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service = RevenueCatSubscriptionAccessService(
      client: client, apiKey: .configured(apiKey: "public-key"),
      store: FileSavedSubscriptionAccessStore(fileURL: directory.appendingPathComponent("saved.json")),
      pendingStore: FilePendingSubscriptionOperationStore(fileURL: directory.appendingPathComponent("pending.json")),
      acceptsSandboxSavedAccess: true, now: { ticks += 1; return start.addingTimeInterval(ticks) })
    let selection = service.selectAccount("user_a") ?? AccountSelection(accountID: "user_a", generation: -1)
    _ = await service.currentAccess(for: selection)
    let approval = OwnerPaywallApproval(owner: service)
    let results = ResultLog()
    let model = PaywallModel(
      selection: selection, currentSelection: { selection }, access: service,
      host: FakePaywallHost(), approval: approval, onResult: { results.values.append($0) })
    await model.start()
    return Harness(
      model: model, service: service, approval: approval, client: client, selection: selection, results: results)
  }

  private func snapshot(active: Bool) -> CustomerAccessSnapshot {
    CustomerAccessSnapshot(
      isActive: active, expiresAt: active ? expiry : nil, verification: .serverVerified, environment: .production)
  }

  /// The slot is free when a new purchase is approved, and held again until released.
  private func expectSlotFree(_ harness: Harness) async {
    harness.client.nextSnapshot = .success(snapshot(active: false))
    #expect(await harness.service.onPurchaseInitiated(for: harness.selection))
    _ = await harness.service.paywallOperationFinished(.cancelled, for: harness.selection)
  }

  @Test func approvedPurchaseHoldsTheSlotUntilReleased() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    #expect(await harness.service.onPurchaseInitiated(for: harness.selection) == false)
    harness.model.close()
    await harness.approval.waitForReleases()
    await expectSlotFree(harness)
  }

  @Test func successReleasesTheSlotAndVerifiesPro() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    harness.client.nextSnapshot = .success(snapshot(active: true))
    harness.model.events.purchaseCompleted()
    await harness.approval.waitForReleases()
    #expect(await harness.service.onRestoreInitiated(for: harness.selection))
  }

  @Test func cancelReleasesTheSlot() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    harness.model.events.purchaseCancelled()
    await harness.approval.waitForReleases()
    await expectSlotFree(harness)
  }

  @Test func failureReleasesTheSlot() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    harness.model.events.failed(.other)
    await harness.approval.waitForReleases()
    #expect(harness.model.banner == .purchaseFailed)
    await expectSlotFree(harness)
  }

  @Test func pendingReleasesTheSlotAndClosesCheckout() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    harness.model.events.purchasePending()
    await harness.approval.waitForReleases()
    #expect(harness.model.phase == .pending)
    #expect(await harness.service.onRestoreInitiated(for: harness.selection))
    _ = await harness.service.paywallOperationFinished(.cancelled, for: harness.selection)
    // Pending approval is recorded, so a new purchase stays blocked.
    #expect(await harness.approval.approvePurchase(monthly, for: harness.selection) == .pending)
  }

  @Test func closingWithoutACallbackReleasesTheSlot() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.restoreInitiated())
    harness.model.dismiss()
    await harness.approval.waitForReleases()
    #expect(harness.results.values == [.closed])
    await expectSlotFree(harness)
  }

  @Test func deniedApprovalNeverReleasesAnotherOperationsSlot() async {
    let harness = await makeHarness()
    #expect(await harness.model.events.purchaseInitiated(monthly))
    // A second paywall for the same selection is refused and must not free the first slot.
    let second = PaywallModel(
      selection: harness.selection, currentSelection: { harness.selection }, access: harness.service,
      host: FakePaywallHost(), approval: harness.approval, onResult: { _ in })
    await second.start()
    #expect(await second.events.purchaseInitiated(monthly) == false)
    second.close()
    await harness.approval.waitForReleases()
    #expect(await harness.service.onPurchaseInitiated(for: harness.selection) == false)
  }

  @Test func fakesFallBackToTheRefusingApproval() async {
    let approval = OwnerPaywallApproval.make(for: PreviewSubscriptionAccessService(preset: .inactive))
    let selection = AccountSelection(accountID: "preview", generation: 1)
    #expect(approval is UnconfiguredPaywallApproval)
    #expect(await approval.approvePurchase(monthly, for: selection) == .denied(.unavailable))
  }
}
