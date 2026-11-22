import Foundation
import Testing
@testable import OneSet

@MainActor
struct WorkoutStartGateTests {
  private let future = Date(timeIntervalSince1970: 4_102_444_800)
  private let workoutID = "machine-full-body-workout-a"

  private struct Harness {
    let model: OnboardingModel
    let service: ControllableSubscriptionAccessService
    let authentication: AuthenticationModel
    let repository: WorkoutRepository
    let directory: URL
    let route: OnboardingRoute
  }

  private func harness(service: ControllableSubscriptionAccessService = .init(),
                       uploads: CompletedSessionUploadSpy? = nil) async throws -> Harness {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID())
    let model = OnboardingModel(catalog: .bundled, setupService: GateSetupStub(setup: setup),
      completedSessionUploadService: uploads, subscriptionAccess: service,
      paywallHost: FakePaywallHost(), paywallApproval: PreviewPaywallApproval(), workoutRepository: repository)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    model.previewWorkout(programID: setup.programID, workoutID: workoutID)
    return Harness(model: model, service: service, authentication: authentication, repository: repository,
      directory: directory, route: .workoutPreview(programID: setup.programID, workoutID: workoutID))
  }

  private func tapStart(_ ctx: Harness) async {
    await ctx.model.startWorkout(programID: "machine-full-body", workoutID: workoutID, accountID: "preview-user")
  }

  /// Starts a tap and waits until its check is running.
  private func tapStartPending(_ ctx: Harness) async -> Task<Void, Never> {
    let task = Task { await tapStart(ctx) }
    await ctx.service.waitForPendingCheck()
    return task
  }

  @Test func activeProStartsTheWorkoutAndLeavesNoGate() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    let session = try #require(ctx.model.activeWorkoutSession)
    #expect(ctx.model.programPath.last == .workoutRecording(session.id))
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test(arguments: [
    (SubscriptionAccess.verifiedInactive, WorkoutStartStatus.proRequired),
    (.unconfirmed, .unconfirmed),
    (.pendingApproval, .pendingApproval),
    (.proVerified(expiresAt: Date(timeIntervalSince1970: 1_000)), .unconfirmed)
  ])
  func nonActiveResultsBlockTheStartAndShowTheirState(access: SubscriptionAccess, status: WorkoutStartStatus)
    async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(access)
    await tap.value
    #expect(ctx.model.activeWorkoutSession == nil)
    #expect(try ctx.repository.activeSession(accountID: "preview-user") == nil)
    #expect(ctx.model.workoutStartGate?.status == status)
    #expect(ctx.model.programPath.last == ctx.route)
  }

  @Test func checkoutOpensOnlyAfterVerifiedInactivity() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let selection = try #require(ctx.model.currentAccountSelection)
    let tap = await tapStartPending(ctx)
    ctx.service.fail()
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    #expect(ctx.model.paywall == nil)
    ctx.service.set(.pendingApproval, for: selection)
    await tapStart(ctx)
    #expect(ctx.model.workoutStartGate?.status == .pendingApproval)
    ctx.model.presentPlans(for: ctx.route)
    #expect(ctx.model.paywall == nil)
    ctx.service.set(.verifiedInactive, for: selection)
    await tapStart(ctx)
    ctx.model.presentPlans(for: ctx.route)
    #expect(ctx.model.paywall != nil)
    #expect(ctx.model.paywallRoute == ctx.route)
  }

  @Test func startTapDuringACheckWaitsAndOnlyStartsOnce() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let first = await tapStartPending(ctx)
    #expect(ctx.model.workoutStartGate?.status == .checking)
    await tapStart(ctx)
    #expect(ctx.service.checkCount == 1)
    #expect(ctx.model.activeWorkoutSession == nil)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await first.value
    #expect(try ctx.repository.activeSession(accountID: "preview-user") != nil)
    let started = try #require(ctx.model.activeWorkoutSession)
    await tapStart(ctx)
    #expect(ctx.model.activeWorkoutSession?.id == started.id)
  }

  @Test func staleReplyAfterAccountChangeIsDropped() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.model.resetAccount()
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    #expect(ctx.model.activeWorkoutSession == nil)
    #expect(try ctx.repository.activeSession(accountID: "preview-user") == nil)
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test func staleReplyAfterProgramChangeIsDropped() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.model.selectedProgramID = "bro-split"
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    #expect(try ctx.repository.activeSession(accountID: "preview-user") == nil)
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test func replyIsDroppedWhenAnotherSessionAppearedMeanwhile() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    let program = try #require(ProgramCatalog.bundled.program(id: "machine-full-body"))
    let session = WorkoutSession(accountID: "preview-user", cycleID: try #require(ctx.model.restoredCycleID),
      program: program, workout: program.workouts[0], week: 1, day: 1, weightUnit: .kilograms, startedAt: .now)
    _ = try ctx.repository.start(session)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    #expect(ctx.model.activeWorkoutSession == nil)
    #expect(ctx.model.programPath.last == ctx.route)
  }

  @Test func replyIsDroppedWhenTheCycleChangedMeanwhile() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.model.restoredCycleID = UUID()
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    #expect(ctx.model.activeWorkoutSession == nil)
    #expect(try ctx.repository.activeSession(accountID: "preview-user") == nil)
  }

  @Test func replyIsDroppedWhenThePreviewWasLeft() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.model.programPath.removeLast()
    ctx.service.resolve(.proVerified(expiresAt: future))
    await tap.value
    #expect(try ctx.repository.activeSession(accountID: "preview-user") == nil)
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test func retryChecksAgainWithoutStartingAndThenStartIsAnExplicitTap() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    var tap = await tapStartPending(ctx)
    ctx.service.fail()
    await tap.value
    #expect(ctx.model.workoutStartGate?.status == .unconfirmed)
    let retry = Task { await ctx.model.recheckWorkoutAccess(route: ctx.route) }
    await ctx.service.waitForPendingCheck()
    #expect(ctx.model.workoutStartGate?.status == .checking)
    ctx.service.resolve(.proVerified(expiresAt: future))
    await retry.value
    #expect(ctx.model.workoutStartGate?.status == .proActive)
    #expect(ctx.model.activeWorkoutSession == nil)
    tap = Task { await tapStart(ctx) }
    await tap.value
    #expect(ctx.model.activeWorkoutSession != nil)
  }

  /// Opens checkout from a verified-inactive start and completes a purchase that verifies as `access`.
  private func checkout(_ ctx: Harness, verifying access: SubscriptionAccess) async throws {
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.verifiedInactive)
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    let paywall = try #require(ctx.model.paywall)
    await paywall.start()
    #expect(await paywall.events.purchaseInitiated(SubscriptionPackage(id: "$rc_monthly")))
    paywall.events.purchaseCompleted()
    await ctx.service.waitForPendingCheck()
    ctx.service.resolve(access)
    while paywall.phase != .active { await Task.yield() }
    await Task.yield()
  }

  @Test func purchaseReturnsToTheStillValidPreviewWithoutStarting() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    try await checkout(ctx, verifying: .proVerified(expiresAt: future))
    ctx.model.paywall?.done()
    for _ in 0..<50 where ctx.model.workoutStartGate?.status != .proActive { await Task.yield() }
    #expect(ctx.model.paywall == nil)
    #expect(ctx.model.programPath.last == ctx.route)
    #expect(ctx.model.workoutStartGate?.status == .proActive)
    #expect(ctx.model.activeWorkoutSession == nil)
    await tapStart(ctx)
    #expect(ctx.model.activeWorkoutSession != nil)
  }

  @Test func pendingPurchaseReturnsToPreviewWithApprovalState() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.verifiedInactive)
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    let paywall = try #require(ctx.model.paywall)
    await paywall.start()
    paywall.events.purchasePending()
    paywall.close()
    await ctx.service.waitForPendingCheck()
    ctx.service.resolve(.pendingApproval)
    for _ in 0..<50 where ctx.model.workoutStartGate?.status != .pendingApproval { await Task.yield() }
    #expect(ctx.model.workoutStartGate?.status == .pendingApproval)
    #expect(ctx.model.paywall == nil)
  }

  @Test func closingCheckoutKeepsTheProRequiredFooter() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.verifiedInactive)
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    ctx.model.paywall?.close()
    #expect(ctx.model.paywall == nil)
    #expect(ctx.model.workoutStartGate?.status == .proRequired)
  }

  @Test func accountChangeClearsSubscriptionPresentation() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.verifiedInactive)
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    ctx.model.resetAccount()
    #expect(ctx.model.workoutStartGate == nil)
    #expect(ctx.model.paywall == nil)
  }

  @Test func checkoutResultForAnEarlierAccountSelectionIsIgnored() async throws {
    let ctx = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    ctx.service.resolve(.verifiedInactive)
    await tap.value
    ctx.model.presentPlans(for: ctx.route)
    let paywall = try #require(ctx.model.paywall)
    ctx.model.resetAccount()
    paywall.close()
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test func resumingFinishingAndSyncingNeedNoProAfterExpiry() async throws {
    let service = ControllableSubscriptionAccessService()
    let uploads = CompletedSessionUploadSpy()
    let ctx = try await harness(service: service, uploads: uploads)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let tap = await tapStartPending(ctx)
    service.resolve(.proVerified(expiresAt: future))
    await tap.value
    let session = try #require(ctx.model.activeWorkoutSession)
    let slot = try #require(session.exercises.first).slotID
    // Pro lapses after the session began.
    service.set(.verifiedInactive, for: try #require(ctx.model.currentAccountSelection))
    let checksBefore = service.checkCount
    ctx.model.programPath.removeLast()
    #expect(ctx.model.resumeWorkout(programID: session.programID, workoutID: session.workoutID,
      accountID: "preview-user", week: nil))
    #expect(ctx.model.programPath.last == .workoutRecording(session.id))
    ctx.model.scheduleWorkoutEdit(sessionID: session.id, slotID: slot, input: .init(weight: "50", reps: "10"))
    #expect(await ctx.model.applyWorkoutEdit(sessionID: session.id, slotID: slot) {
      ctx.model.completeWorkoutSet(slotID: slot)
    })
    #expect(await ctx.model.applyWorkoutEdit(sessionID: session.id) {
      ctx.model.finishActiveWorkout(note: nil, using: ctx.authentication)
    })
    for _ in 0..<200 where uploads.uploads.isEmpty { await Task.yield() }
    #expect(uploads.uploads.first?.sessionID == session.id)
    #expect(service.checkCount == checksBefore)
    #expect(ctx.model.workoutStartGate == nil)
  }

  @Test func withoutAServiceTheStartIsNotGated() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID())
    let model = OnboardingModel(catalog: .bundled, setupService: GateSetupStub(setup: setup),
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true)))
    await model.startWorkout(programID: setup.programID, workoutID: workoutID, accountID: "preview-user")
    #expect(model.activeWorkoutSession != nil)
  }
}

@MainActor
private struct GateSetupStub: AccountSetupService {
  let setup: AccountSetup
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { self.setup }
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { setup }
}
