import Foundation
import Testing
@testable import OneSet

@MainActor
struct RevenueCatSubscriptionAccessServiceTests {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let expiry = Date(timeIntervalSince1970: 1_800_086_400)

  func makeStoreURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathComponent("saved.json")
  }

  func makeService(
    client: FakePurchasesClient,
    apiKey: RevenueCatAPIKeyConfiguration = .configured(apiKey: "public-key"),
    storeURL: URL? = nil,
    pendingURL: URL? = nil,
    acceptsSandbox: Bool = true
  ) -> RevenueCatSubscriptionAccessService {
    let url = storeURL ?? makeStoreURL()
    let start = now
    var ticks = 0.0
    // Each read moves the clock forward so a later check is newer than an earlier one.
    return RevenueCatSubscriptionAccessService(
      client: client, apiKey: apiKey, store: FileSavedSubscriptionAccessStore(fileURL: url),
      pendingStore: FilePendingSubscriptionOperationStore(fileURL: pendingURL ?? makeStoreURL()),
      acceptsSandboxSavedAccess: acceptsSandbox, now: { ticks += 1; return start.addingTimeInterval(ticks) }
    )
  }

  func select(_ service: RevenueCatSubscriptionAccessService, _ accountID: String) -> AccountSelection {
    service.selectAccount(accountID) ?? AccountSelection(accountID: accountID, generation: -1)
  }

  func snapshot(
    active: Bool, verification: CustomerAccessSnapshot.Verification = .serverVerified,
    environment: BillingEnvironment = .production
  ) -> CustomerAccessSnapshot {
    CustomerAccessSnapshot(
      isActive: active, expiresAt: active ? expiry : nil, verification: verification, environment: environment
    )
  }

  @Test func configuresOnceWithResolvedAccountAndReportsVerifiedAccess() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    #expect(client.configureCalls.isEmpty)
    let selection = select(service, "user_a")
    let result = await service.currentAccess(for: selection)
    #expect(result.access == .proVerified(expiresAt: expiry))
    _ = await service.refresh(for: selection)
    #expect(client.configureCalls.count == 1)
    #expect(client.configureCalls.first?.appUserID == "user_a")
    #expect(client.configureCalls.first?.apiKey == "public-key")
    #expect(client.loginCalls.isEmpty)
  }

  @Test func unconfiguredKeyCannotConfirmAccessAndNeverTouchesTheSDK() async {
    let client = FakePurchasesClient()
    let service = makeService(client: client, apiKey: .unconfigured)
    let selection = select(service, "user_a")
    let result = await service.currentAccess(for: selection)
    #expect(result.access == .unconfirmed)
    #expect(client.configureCalls.isEmpty)
    #expect(client.fetchCount == 0)
  }

  @Test func serverVerifiedInactiveAllowsCheckout() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: false))
    let service = makeService(client: client)
    let result = await service.currentAccess(for: select(service, "user_a"))
    #expect(result.access == .verifiedInactive)
    #expect(result.access.allowsCheckout)
  }

  @Test func accountSwitchLogsInAndIncrementsGeneration() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    let first = select(service, "user_a")
    _ = await service.currentAccess(for: first)
    let second = select(service, "user_b")
    #expect(second.generation > first.generation)
    let result = await service.currentAccess(for: second)
    #expect(client.loginCalls == ["user_b"])
    #expect(client.currentAppUserID == "user_b")
    #expect(result.selection == second)
    #expect(await service.currentAccess(for: first).access == .unconfirmed)
  }

  @Test func accountSwitchDuringCheckDropsTheStaleReply() async {
    let client = FakePurchasesClient()
    client.holdsFetches = true
    let service = makeService(client: client)
    let first = select(service, "user_a")
    let pending = Task { await service.currentAccess(for: first) }
    await client.waitForHeldFetch()
    let second = select(service, "user_b")
    client.releaseFetches(with: .success(snapshot(active: true)))
    let stale = await pending.value
    #expect(stale.selection == first)
    #expect(stale.access == .unconfirmed)
    #expect(second != first)
    client.holdsFetches = false
    client.nextSnapshot = .success(snapshot(active: false))
    #expect(await service.currentAccess(for: second).access == .verifiedInactive)
  }

  @Test func sameAccountReentryIgnoresRepliesFromTheEarlierSelection() async {
    let client = FakePurchasesClient()
    client.holdsFetches = true
    let service = makeService(client: client)
    let first = select(service, "user_a")
    let pending = Task { await service.currentAccess(for: first) }
    await client.waitForHeldFetch()
    #expect(service.selectAccount(nil) == nil)
    let again = select(service, "user_a")
    #expect(again.accountID == first.accountID)
    #expect(again.generation > first.generation)
    client.releaseFetches(with: .success(snapshot(active: true)))
    let stale = await pending.value
    #expect(stale.access == .unconfirmed)
    #expect(stale.selection == first)
    client.holdsFetches = false
    client.nextSnapshot = .success(snapshot(active: false))
    #expect(await service.currentAccess(for: again).access == .verifiedInactive)
  }

  @Test func losingIdentityRemovesInMemoryAccessImmediately() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    let selection = select(service, "user_a")
    #expect(await service.currentAccess(for: selection).access == .proVerified(expiresAt: expiry))
    service.selectAccount(nil)
    #expect(service.selection == nil)
    #expect(await service.currentAccess(for: selection).access == .unconfirmed)
  }

  @Test func concurrentCallersShareOneCheck() async {
    let client = FakePurchasesClient()
    client.holdsFetches = true
    let service = makeService(client: client)
    let selection = select(service, "user_a")
    async let first = service.currentAccess(for: selection)
    async let second = service.refresh(for: selection)
    await client.waitForHeldFetch()
    client.releaseFetches(with: .success(snapshot(active: true)))
    let results = await [first, second]
    #expect(client.fetchCount == 1)
    #expect(results.allSatisfy { $0.access == .proVerified(expiresAt: expiry) })
  }

  @Test func failedCheckFallsBackToSavedExpiryOtherwiseUnconfirmed() async {
    let url = makeStoreURL()
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let online = makeService(client: client, storeURL: url)
    _ = await online.currentAccess(for: select(online, "user_a"))

    let offlineClient = FakePurchasesClient()
    let offline = makeService(client: offlineClient, storeURL: url)
    let selection = select(offline, "user_a")
    #expect(await offline.currentAccess(for: selection).access == .proVerified(expiresAt: expiry))

    let stranger = select(offline, "user_b")
    #expect(await offline.currentAccess(for: stranger).access == .unconfirmed)
  }

  @Test func onDeviceOnlyResultNeverExtendsSavedAccess() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true, verification: .onDeviceOnly))
    let service = makeService(client: client)
    let selection = select(service, "user_a")
    let result = await service.currentAccess(for: selection)
    #expect(result.access == .unconfirmed)
    #expect(!result.access.allowsNewWorkout(at: now))
  }

  @Test func verifiedInactiveReplacesSavedAccess() async {
    let url = makeStoreURL()
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client, storeURL: url)
    let selection = select(service, "user_a")
    _ = await service.currentAccess(for: selection)
    client.nextSnapshot = .success(snapshot(active: false))
    #expect(await service.refresh(for: selection).access == .verifiedInactive)

    client.nextSnapshot = .failure(SubscriptionOperationError.failed)
    #expect(await service.refresh(for: selection).access == .unconfirmed)
  }

  @Test func sandboxAccessIsSavedSeparatelyAndIgnoredByPublicBuilds() async {
    let url = makeStoreURL()
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true, environment: .sandbox))
    let service = makeService(client: client, storeURL: url)
    _ = await service.currentAccess(for: select(service, "user_a"))

    let publicService = makeService(client: FakePurchasesClient(), storeURL: url, acceptsSandbox: false)
    #expect(await publicService.currentAccess(for: select(publicService, "user_a")).access == .unconfirmed)
    let testService = makeService(client: FakePurchasesClient(), storeURL: url, acceptsSandbox: true)
    #expect(await testService.currentAccess(for: select(testService, "user_a")).access == .proVerified(expiresAt: expiry))
  }

  @Test func failedLoginCannotConfirmAccessAndDoesNotFetch() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    _ = await service.currentAccess(for: select(service, "user_a"))
    client.loginError = SubscriptionOperationError.failed
    let fetches = client.fetchCount
    let result = await service.currentAccess(for: select(service, "user_b"))
    #expect(result.access == .unconfirmed)
    #expect(client.fetchCount == fetches)
  }

  @Test func foregroundRefreshRunsANewCheck() async {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    let selection = select(service, "user_a")
    var updates = service.updates(for: selection).makeAsyncIterator()
    service.appDidReturnToForeground()
    let result = await updates.next()
    #expect(result?.access == .proVerified(expiresAt: expiry))
    #expect(client.fetchCount == 1)
  }
}
