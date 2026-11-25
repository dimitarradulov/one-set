import Foundation
import Testing
@testable import OneSet

extension RevenueCatSubscriptionAccessServiceTests {
  // MARK: Account deletion billing cleanup

  @Test func billingCleanupDropsAccessAndRefusesBillingForTheDepartingAccount() async throws {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    let selection = select(service, "user_a")
    #expect(await service.currentAccess(for: selection).access == .proVerified(expiresAt: expiry))

    try SubscriptionBillingCleanup(accounts: service).erase(accountID: "user_a")

    #expect(service.selection == nil)
    let fetchesBefore = client.fetchCount
    #expect(await service.currentAccess(for: selection).access == .unconfirmed)
    #expect(client.fetchCount == fetchesBefore)
    #expect(await service.onPurchaseInitiated(for: selection) == false)
    #expect(await service.onRestoreInitiated(for: selection) == false)
    #expect(client.purchaseCalls.isEmpty)
  }

  @Test func billingCleanupLeavesAnotherAccountSelected() async throws {
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client)
    let selection = select(service, "user_b")
    _ = await service.currentAccess(for: selection)

    try SubscriptionBillingCleanup(accounts: service).erase(accountID: "user_a")

    #expect(service.selection == selection)
    #expect(await service.currentAccess(for: selection).access == .proVerified(expiresAt: expiry))
  }

  @Test func standardErasureClearsBillingAndSavedAccessForTheAccount() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "access.json")
    let client = FakePurchasesClient()
    client.nextSnapshot = .success(snapshot(active: true))
    let service = makeService(client: client, storeURL: storeURL)
    let selection = select(service, "user_a")
    _ = await service.currentAccess(for: selection)
    let access = FileSavedSubscriptionAccessStore(fileURL: storeURL)
    #expect(try access.load(accountID: "user_a", environment: .production) != nil)

    try LocalAccountErasure.standard(
      repository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")),
      onboardingProgress: FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json")),
      savedSubscriptionAccess: access,
      pendingSubscriptionOperations: FilePendingSubscriptionOperationStore(
        fileURL: directory.appending(path: "pending.json")),
      subscriptionAccounts: service
    ).erase(accountID: "user_a")

    #expect(service.selection == nil)
    #expect(try access.load(accountID: "user_a", environment: .production) == nil)
    #expect(await service.onPurchaseInitiated(for: selection) == false)
  }
}
