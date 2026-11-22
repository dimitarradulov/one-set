import Foundation
import Testing
@testable import OneSet

extension RevenueCatSubscriptionAccessServiceTests {
  // MARK: Purchases and restores

  private var monthly: SubscriptionPackage { SubscriptionPackage(id: "$rc_monthly") }

  /// A service whose account is selected and verified inactive, ready to buy.
  private func makeReadyService(
    client: FakePurchasesClient, pendingURL: URL? = nil, accountID: String = "user_a"
  ) async -> (RevenueCatSubscriptionAccessService, AccountSelection) {
    client.nextSnapshot = .success(snapshot(active: false))
    let service = makeService(client: client, pendingURL: pendingURL)
    let selection = select(service, accountID)
    _ = await service.currentAccess(for: selection)
    return (service, selection)
  }

  @Test func purchaseRefreshesAccessForTheInitiatingSelection() async throws {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.holdsOperations = true
    let purchase = Task { try await service.purchase(monthly, for: selection) }
    await client.waitForHeldPurchase()
    client.nextSnapshot = .success(snapshot(active: true))
    client.releasePurchases(with: .success(.purchased))
    let result = try await purchase.value
    #expect(client.purchaseCalls == ["$rc_monthly"])
    #expect(result.selection == selection)
    #expect(result.access == .proVerified(expiresAt: expiry))
  }

  @Test func purchaseRechecksInactivityBeforeBuying() async {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.nextSnapshot = .success(snapshot(active: true))
    await #expect(throws: SubscriptionOperationError.checkoutUnavailable) {
      try await service.purchase(monthly, for: selection)
    }
    #expect(client.purchaseCalls.isEmpty)
    #expect(await service.onPurchaseInitiated(for: selection) == false)
  }

  @Test func purchaseIsRefusedWhenTheLatestCheckCannotConfirmInactivity() async {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.nextSnapshot = .failure(SubscriptionOperationError.failed)
    #expect(await service.onPurchaseInitiated(for: selection) == false)
    // The refused attempt released the slot.
    client.nextSnapshot = .success(snapshot(active: false))
    #expect(await service.onPurchaseInitiated(for: selection))
  }

  @Test func doubleTapAllowsOnePurchaseOrRestoreAtATime() async throws {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.holdsOperations = true
    let first = Task { try await service.purchase(monthly, for: selection) }
    await client.waitForHeldPurchase()
    await #expect(throws: SubscriptionOperationError.operationInProgress) {
      try await service.purchase(monthly, for: selection)
    }
    await #expect(throws: SubscriptionOperationError.operationInProgress) {
      try await service.restore(for: selection)
    }
    #expect(await service.onPurchaseInitiated(for: selection) == false)
    #expect(await service.onRestoreInitiated(for: selection) == false)
    #expect(client.purchaseCalls.count == 1)
    #expect(client.restoreCount == 0)
    client.nextSnapshot = .success(snapshot(active: true))
    client.releasePurchases(with: .success(.purchased))
    #expect(try await first.value.access == .proVerified(expiresAt: expiry))
    // Success released the slot.
    client.holdsOperations = false
    #expect(try await service.restore(for: selection).access == .proVerified(expiresAt: expiry))
  }

  @Test func cancellationAndFailureReleaseTheOperation() async throws {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.nextPurchase = .failure(SubscriptionOperationError.cancelled)
    await #expect(throws: SubscriptionOperationError.cancelled) {
      try await service.purchase(monthly, for: selection)
    }
    client.nextPurchase = .failure(SubscriptionOperationError.failed)
    await #expect(throws: SubscriptionOperationError.failed) {
      try await service.purchase(monthly, for: selection)
    }
    client.nextRestore = .failure(SubscriptionOperationError.failed)
    await #expect(throws: SubscriptionOperationError.failed) {
      try await service.restore(for: selection)
    }
    client.nextRestore = .success(())
    #expect(try await service.restore(for: selection).selection == selection)
  }

  @Test func switchDuringPurchaseDelaysTheIdentitySwitchAndIgnoresTheOldResult() async throws {
    let client = FakePurchasesClient()
    let (service, first) = await makeReadyService(client: client)
    client.holdsOperations = true
    let purchase = Task { try await service.purchase(monthly, for: first) }
    await client.waitForHeldPurchase()

    let second = select(service, "user_b")
    #expect(service.selection == second)
    // The old account's access is gone at once, but the SDK stays on the old identity.
    #expect(await service.currentAccess(for: first).access == .unconfirmed)
    let secondCheck = Task { await service.currentAccess(for: second) }
    for _ in 0..<20 { await Task.yield() }
    #expect(client.loginCalls.isEmpty)
    #expect(client.currentAppUserID == "user_a")

    client.nextSnapshot = .success(snapshot(active: false))
    client.releasePurchases(with: .success(.purchased))
    let stale = try await purchase.value
    #expect(stale.selection == first)
    #expect(stale.access == .unconfirmed)
    let result = await secondCheck.value
    #expect(client.loginCalls == ["user_b"])
    #expect(result.selection == second)
    #expect(result.access == .verifiedInactive)
  }

  @Test func lateCallbackAfterSwitchAndReentryDoesNotTouchTheNewSelection() async {
    let client = FakePurchasesClient()
    let (service, first) = await makeReadyService(client: client)
    #expect(await service.onPurchaseInitiated(for: first))
    service.selectAccount(nil)
    let again = select(service, "user_a")
    #expect(again.generation > first.generation)
    // The slot is still held by the earlier selection, so the new one cannot start.
    #expect(await service.onRestoreInitiated(for: again) == false)

    let fetches = client.fetchCount
    client.nextSnapshot = .success(snapshot(active: true))
    let late = await service.paywallOperationFinished(.succeeded, for: first)
    #expect(late.selection == first)
    #expect(late.access == .unconfirmed)
    #expect(client.fetchCount == fetches)
    // A callback for the new selection cannot finish an operation it never started.
    #expect(await service.paywallOperationFinished(.cancelled, for: again).access == .unconfirmed)
    // The slot is free again.
    #expect(await service.onRestoreInitiated(for: again))
  }

  @Test func paywallSuccessRefreshesAccessAndReleasesTheOperation() async {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    #expect(await service.onPurchaseInitiated(for: selection))
    client.nextSnapshot = .success(snapshot(active: true))
    let result = await service.paywallOperationFinished(.succeeded, for: selection)
    #expect(result.access == .proVerified(expiresAt: expiry))
    #expect(await service.onRestoreInitiated(for: selection))
  }

  @Test func staleSelectionCannotStartAnOperation() async {
    let client = FakePurchasesClient()
    let (service, first) = await makeReadyService(client: client)
    _ = select(service, "user_b")
    #expect(await service.onPurchaseInitiated(for: first) == false)
    #expect(await service.onRestoreInitiated(for: first) == false)
    #expect((try? await service.purchase(monthly, for: first))?.access == .unconfirmed)
    #expect(client.purchaseCalls.isEmpty)
  }

  @Test func explicitSignOutWaitsForTheOperationToClear() async {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    #expect(await service.onRestoreInitiated(for: selection))
    var cleared = false
    let signOut = Task {
      await service.waitUntilNoInteractiveOperation()
      cleared = true
    }
    for _ in 0..<20 { await Task.yield() }
    #expect(!cleared)
    await service.paywallOperationFinished(.cancelled, for: selection)
    await signOut.value
    #expect(cleared)
  }

  @Test func pendingApprovalPersistsForTheInitiatingAccountAcrossRelaunch() async throws {
    let pendingURL = makeStoreURL()
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client, pendingURL: pendingURL)
    client.nextPurchase = .success(.pendingApproval)
    let pending = try await service.purchase(monthly, for: selection)
    #expect(pending.access == .pendingApproval)
    #expect(!pending.access.allowsCheckout)
    #expect(await service.currentAccess(for: selection).access == .pendingApproval)

    // Relaunch: a new service reads the same stores.
    let relaunchedClient = FakePurchasesClient()
    relaunchedClient.nextSnapshot = .success(snapshot(active: false))
    let relaunched = makeService(client: relaunchedClient, pendingURL: pendingURL)
    let again = select(relaunched, "user_a")
    #expect(await relaunched.currentAccess(for: again).access == .pendingApproval)
    await #expect(throws: SubscriptionOperationError.checkoutUnavailable) {
      try await relaunched.purchase(monthly, for: again)
    }
    #expect(relaunchedClient.purchaseCalls.isEmpty)

    // The pending purchase belongs to account A alone.
    let other = select(relaunched, "user_b")
    #expect(await relaunched.currentAccess(for: other).access == .verifiedInactive)

    // Approval arrives: the status check verifies Pro and clears the pending state.
    let backToA = select(relaunched, "user_a")
    relaunchedClient.nextSnapshot = .success(snapshot(active: true))
    #expect(await relaunched.checkPendingStatus(for: backToA).access == .proVerified(expiresAt: expiry))
    relaunchedClient.nextSnapshot = .success(snapshot(active: false))
    #expect(await relaunched.refresh(for: backToA).access == .verifiedInactive)
  }

  @Test func pendingApprovalShowsOfflineAfterRelaunch() async throws {
    let pendingURL = makeStoreURL()
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client, pendingURL: pendingURL)
    client.nextPurchase = .success(.pendingApproval)
    _ = try await service.purchase(monthly, for: selection)
    let offline = makeService(client: FakePurchasesClient(), pendingURL: pendingURL)
    #expect(await offline.currentAccess(for: select(offline, "user_a")).access == .pendingApproval)
  }

  @Test func confirmedChargeWithoutVerifiedProKeepsCheckoutClosed() async throws {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    // Apple confirms the charge but the entitlement is not visible yet.
    let result = try await service.purchase(monthly, for: selection)
    #expect(result.access == .pendingApproval)
    await #expect(throws: SubscriptionOperationError.checkoutUnavailable) {
      try await service.purchase(monthly, for: selection)
    }
  }

  @Test func paywallPendingResultIsRecordedForTheInitiatingAccount() async {
    let pendingURL = makeStoreURL()
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client, pendingURL: pendingURL)
    #expect(await service.onPurchaseInitiated(for: selection))
    let result = await service.paywallOperationFinished(.pendingApproval, for: selection)
    #expect(result.access == .pendingApproval)
    let relaunchedClient = FakePurchasesClient()
    relaunchedClient.nextSnapshot = .success(snapshot(active: false))
    let relaunched = makeService(client: relaunchedClient, pendingURL: pendingURL)
    #expect(await relaunched.currentAccess(for: select(relaunched, "user_a")).access == .pendingApproval)
  }

  @Test func receiptLinkedToAnotherAccountShowsTheExactMessage() async {
    let client = FakePurchasesClient()
    let (service, selection) = await makeReadyService(client: client)
    client.nextPurchase = .failure(SubscriptionOperationError.linkedToAnotherAccount)
    do {
      _ = try await service.purchase(monthly, for: selection)
      Issue.record("Expected the purchase to fail")
    } catch {
      #expect(error.localizedDescription
        == "This subscription is linked to another OneSet account. Sign in to that account to use Pro.")
    }
    client.nextRestore = .failure(SubscriptionOperationError.linkedToAnotherAccount)
    await #expect(throws: SubscriptionOperationError.linkedToAnotherAccount) {
      try await service.restore(for: selection)
    }
    #expect(SubscriptionOperationError.linkedToAnotherAccount.errorDescription
      == SubscriptionOperationError.linkedToAnotherAccountMessage)
  }
}
