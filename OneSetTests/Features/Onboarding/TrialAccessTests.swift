import Foundation
import Testing
@testable import OneSet

@MainActor
struct TrialAccessTests {
  private let future = Date(timeIntervalSince1970: 4_102_444_800)
  private let programID = "machine-full-body"

  private struct Harness {
    let model: OnboardingModel
    let service: ControllableSubscriptionAccessService
    let authentication: AuthenticationModel
    let store: FlakyProgressStore
    let setup: SetupCounter
  }

  private func harness() async -> Harness {
    let service = ControllableSubscriptionAccessService()
    let store = FlakyProgressStore()
    let setup = SetupCounter()
    let model = OnboardingModel(
      catalog: .bundled, setupService: setup, subscriptionAccess: service,
      paywallHost: FakePaywallHost(), paywallApproval: PreviewPaywallApproval(), progressStore: store)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    model.path = [.preferences, .programs, .programDetail(programID)]
    model.selectProgram(programID)
    return Harness(model: model, service: service, authentication: authentication, store: store, setup: setup)
  }

  /// Starts the trial screen's task and waits until its first check is running.
  private func openTrial(_ ctx: Harness) async -> Task<Void, Never> {
    let task = Task { await ctx.model.watchTrialAccess(programID: programID, using: ctx.authentication) }
    await ctx.service.waitForPendingCheck()
    return task
  }

  @Test func checkingShowsProgressUntilTheCheckResolves() async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    #expect(ctx.model.trialStatus(for: programID) == .checking)
    ctx.service.resolve(.verifiedInactive)
    await settle()
    #expect(ctx.model.trialStatus(for: programID) == .offer)
    task.cancel()
    await task.value
  }

  @Test func activeProSavesSetupOnceAndOpensTheProgram() async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await task.value
    #expect(ctx.model.hasCompletedSetup)
    #expect(ctx.model.path == [.programOverview(programID)])
    #expect(ctx.model.trialGate == nil)
    #expect(ctx.store.completedSaves == 1)
  }

  @Test(arguments: [
    (SubscriptionAccess.verifiedInactive, TrialAccessStatus.offer),
    (.unconfirmed, .unconfirmed),
    (.pendingApproval, .pendingApproval),
    (.proVerified(expiresAt: Date(timeIntervalSince1970: 1_000)), .unconfirmed)
  ])
  func otherResultsKeepTheTrialScreenAndSaveNothing(access: SubscriptionAccess, status: TrialAccessStatus)
    async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(access)
    await settle()
    #expect(ctx.model.trialStatus(for: programID) == status)
    #expect(!ctx.model.hasCompletedSetup)
    #expect(ctx.model.path.last == .trialPreview(programID))
    #expect(ctx.store.completedSaves == 0)
    task.cancel()
    await task.value
  }

  @Test func failedCheckRetriesWithoutOpeningCheckout() async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.fail()
    await settle()
    #expect(ctx.model.trialStatus(for: programID) == .unconfirmed)
    ctx.model.presentTrialPlans(programID: programID, using: ctx.authentication)
    #expect(ctx.model.paywall == nil)
    let retry = Task { await ctx.model.retryTrialAccess(programID: programID, using: ctx.authentication) }
    await ctx.service.waitForPendingCheck()
    #expect(ctx.model.trialStatus(for: programID) == .checking)
    ctx.service.resolve(.verifiedInactive)
    await retry.value
    #expect(ctx.model.trialStatus(for: programID) == .offer)
    task.cancel()
    await task.value
  }

  @Test func pendingApprovalResolvedByALaterUpdateCompletesSetupOnce() async throws {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(.pendingApproval)
    await settle()
    let selection = try #require(ctx.model.currentAccountSelection)
    ctx.service.set(.proVerified(expiresAt: future), for: selection)
    ctx.service.set(.proVerified(expiresAt: future), for: selection)
    await task.value
    #expect(ctx.model.hasCompletedSetup)
    #expect(ctx.store.completedSaves == 1)
  }

  @Test func staleReplyAfterAProgramChangeCannotCompleteSetup() async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.model.path = [.preferences, .programs, .programDetail("full-body")]
    ctx.model.selectProgram("full-body")
    ctx.service.resolve(.proVerified(expiresAt: future))
    await settle()
    #expect(!ctx.model.hasCompletedSetup)
    #expect(ctx.model.selectedProgramID == "full-body")
    #expect(ctx.model.path.last == .trialPreview("full-body"))
    #expect(ctx.store.completedSaves == 0)
    task.cancel()
    await task.value
  }

  @Test func closingCheckoutKeepsTheTrialScreen() async throws {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(.verifiedInactive)
    await settle()
    ctx.model.presentTrialPlans(programID: programID, using: ctx.authentication)
    let paywall = try #require(ctx.model.paywall)
    #expect(ctx.model.paywallRoute == .trialPreview(programID))
    paywall.close()
    #expect(ctx.model.paywall == nil)
    #expect(!ctx.model.hasCompletedSetup)
    #expect(ctx.model.trialStatus(for: programID) == .offer)
    task.cancel()
    await task.value
  }

  @Test func verifiedPurchaseThroughCheckoutCompletesSetup() async throws {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(.verifiedInactive)
    await settle()
    ctx.model.presentTrialPlans(programID: programID, using: ctx.authentication)
    let paywall = try #require(ctx.model.paywall)
    await paywall.start()
    _ = await paywall.events.purchaseInitiated(SubscriptionPackage(id: "$rc_monthly"))
    paywall.events.purchaseCompleted()
    await ctx.service.waitForPendingCheck()
    ctx.service.resolve(.proVerified(expiresAt: future))
    await settle()
    paywall.done()
    #expect(ctx.model.hasCompletedSetup)
    #expect(ctx.model.path == [.programOverview(programID)])
    #expect(ctx.model.paywall == nil)
    #expect(ctx.store.completedSaves == 1)
    task.cancel()
    await task.value
  }

  @Test func setupSaveRetriesAfterConfirmedPaymentWithoutCheckingOrPayingAgain() async {
    let ctx = await harness()
    ctx.store.failsCompletedSaves = true
    let task = await openTrial(ctx)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await settle()
    #expect(ctx.model.trialStatus(for: programID) == .saveFailed)
    #expect(!ctx.model.hasCompletedSetup)
    #expect(ctx.model.path.last == .trialPreview(programID))
    #expect(!ctx.model.progressErrorPresented)
    ctx.model.presentTrialPlans(programID: programID, using: ctx.authentication)
    #expect(ctx.model.paywall == nil)
    let checks = ctx.service.checkCount

    ctx.store.failsCompletedSaves = false
    ctx.model.retryTrialSetupSave(programID: programID, using: ctx.authentication)
    #expect(ctx.model.hasCompletedSetup)
    #expect(ctx.model.path == [.programOverview(programID)])
    #expect(ctx.service.checkCount == checks)
    #expect(ctx.store.completedSaves == 1)
    task.cancel()
    await task.value
  }

  @Test func accountResetClearsTheTrialGateAndCheckout() async {
    let ctx = await harness()
    let task = await openTrial(ctx)
    ctx.service.resolve(.verifiedInactive)
    await settle()
    ctx.model.presentTrialPlans(programID: programID, using: ctx.authentication)
    #expect(ctx.model.paywall != nil)
    ctx.model.clearSubscriptionPresentation()
    #expect(ctx.model.paywall == nil)
    #expect(ctx.model.trialGate == nil)
    task.cancel()
    await task.value
  }

  private func settle() async {
    for _ in 0..<20 { await Task.yield() }
  }
}

@MainActor
final class SetupCounter: AccountSetupService {
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { setup }
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { nil }
}

/// Counts completed-setup saves and can fail them while the user retries.
@MainActor
final class FlakyProgressStore: OnboardingProgressStore {
  var failsCompletedSaves = false
  private(set) var completedSaves = 0
  private var stored: [String: OnboardingProgress] = [:]

  func load(accountID: String) throws -> OnboardingProgress? { stored[accountID] }

  func save(_ progress: OnboardingProgress, accountID: String) throws {
    if let completed = progress.completed {
      if failsCompletedSaves { throw CocoaError(.fileWriteOutOfSpace) }
      // Saves that mark an upload as finished are not new setup completions.
      if completed.needsUpload { completedSaves += 1 }
    }
    stored[accountID] = progress
  }

  func remove(accountID: String) throws { stored[accountID] = nil }
}
