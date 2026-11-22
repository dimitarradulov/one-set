import Foundation
import Testing
@testable import OneSet

@MainActor
struct SubscriptionAccessTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let future = Date(timeIntervalSince1970: 1_800_086_400)
  private let past = Date(timeIntervalSince1970: 1_799_913_600)

  @Test func proVerifiedThroughFutureDateAllowsWorkoutButNotCheckout() {
    let access = SubscriptionAccess.proVerified(expiresAt: future)
    #expect(access.allowsNewWorkout(at: now))
    #expect(!access.allowsCheckout)
  }

  @Test func expiredProAllowsNeitherWorkoutNorCheckout() {
    let access = SubscriptionAccess.proVerified(expiresAt: past)
    #expect(!access.allowsNewWorkout(at: now))
    #expect(!access.allowsCheckout)
  }

  @Test func freshInactiveAllowsCheckoutButNotWorkout() {
    #expect(SubscriptionAccess.verifiedInactive.allowsCheckout)
    #expect(!SubscriptionAccess.verifiedInactive.allowsNewWorkout(at: now))
  }

  @Test(arguments: [SubscriptionAccess.checking, .unconfirmed, .pendingApproval])
  func unresolvedStatesBlockWorkoutAndCheckout(access: SubscriptionAccess) {
    #expect(!access.allowsNewWorkout(at: now))
    #expect(!access.allowsCheckout)
  }

  @Test func resultsApplyOnlyToTheirOwnSelection() {
    let first = AccountSelection(accountID: "user", generation: 1)
    let second = AccountSelection(accountID: "user", generation: 2)
    let result = SubscriptionAccessResult(selection: first, access: .verifiedInactive)
    #expect(result.applies(to: first))
    #expect(!result.applies(to: second))
    #expect(!result.applies(to: nil))
  }

  @Test func presetsMapToDecisionsAndLaunchArguments() async throws {
    let selection = AccountSelection(accountID: "user", generation: 1)
    for preset in SubscriptionAccessPreset.allCases {
      #expect(SubscriptionAccessPreset(arguments: ["--ui-subscription-\(preset.rawValue)"]) == preset)
    }
    #expect(SubscriptionAccessPreset(arguments: ["--ui-main-tabs"]) == nil)
    let inactive = PreviewSubscriptionAccessService(preset: .inactive)
    #expect(await inactive.currentAccess(for: selection).access == .verifiedInactive)
    #expect(try await inactive.purchase(SubscriptionPackage(id: "$rc_monthly"), for: selection)
      .access.allowsNewWorkout(at: now))
    #expect(await PreviewSubscriptionAccessService(preset: .failed).refresh(for: selection).access == .unconfirmed)
    #expect(await PreviewSubscriptionAccessService(preset: .pending).currentAccess(for: selection).access
      == .pendingApproval)
    #expect(await UnconfiguredSubscriptionAccessService().currentAccess(for: selection).access == .unconfirmed)
  }

  @Test func launchConfigurationReadsSubscriptionPreset() {
    #expect(AppLaunchConfiguration(arguments: ["--ui-subscription-pending"]).subscriptionPreset == .pending)
    #expect(AppLaunchConfiguration(arguments: []).subscriptionPreset == nil)
  }

  @Test func controllableFakeSharesChecksAndResolvesLater() async {
    let selection = AccountSelection(accountID: "user", generation: 1)
    let service = ControllableSubscriptionAccessService()
    async let first = service.currentAccess(for: selection)
    async let second = service.currentAccess(for: selection)
    await service.waitForPendingCheck()
    service.resolve(.proVerified(expiresAt: future))
    let results = await [first, second]
    #expect(results.allSatisfy { $0.access == .proVerified(expiresAt: future) })
    #expect(service.checkCount == 1)
  }

  @Test func controllableFakeFailsAndPublishesStateChanges() async {
    let selection = AccountSelection(accountID: "user", generation: 1)
    let service = ControllableSubscriptionAccessService()
    var updates = service.updates(for: selection).makeAsyncIterator()
    async let refreshed = service.refresh(for: selection)
    await service.waitForPendingCheck()
    service.fail()
    #expect(await refreshed.access == .unconfirmed)
    service.set(.pendingApproval, for: selection)
    #expect(await updates.next()?.access == .pendingApproval)
  }
}
