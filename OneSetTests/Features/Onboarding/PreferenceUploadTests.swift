import Foundation
import Testing
@testable import OneSet

@MainActor
private final class FakePreferenceService: AccountSetupService {
  enum Outcome { case succeed, temporaryFailure, rejected, suspend }

  let setup: AccountSetup
  var outcomes: [Outcome] = []
  private(set) var saved: [AccountSetup] = []
  private(set) var updates: [AccountPreferences] = []
  /// Replaces what `save` returns, e.g. to model older values acknowledged by the server.
  var saveResult: AccountSetup?
  var suspendSave = false
  private var suspendedSave: CheckedContinuation<Void, Never>?
  private var suspendedUpdate: CheckedContinuation<Void, Never>?
  private var updateStartedWaiters: [CheckedContinuation<Void, Never>] = []
  private var saveStartedWaiters: [CheckedContinuation<Void, Never>] = []

  init(setup: AccountSetup) { self.setup = setup }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { setup }

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    saved.append(setup)
    if suspendSave {
      saveStartedWaiters.forEach { $0.resume() }
      saveStartedWaiters = []
      await withCheckedContinuation { suspendedSave = $0 }
    }
    return saveResult ?? setup
  }

  func updatePreferences(_ preferences: AccountPreferences, for user: AuthenticatedUser) async throws -> AccountPreferences {
    updates.append(preferences)
    let outcome = outcomes.isEmpty ? Outcome.succeed : outcomes.removeFirst()
    switch outcome {
    case .succeed: return preferences
    case .temporaryFailure: throw AccountSetupError.unavailable
    case .rejected: throw AccountSetupError.invalidPreferences
    case .suspend:
      updateStartedWaiters.forEach { $0.resume() }
      updateStartedWaiters = []
      await withCheckedContinuation { suspendedUpdate = $0 }
      return preferences
    }
  }

  func waitUntilUpdateStarts() async {
    guard updates.isEmpty || suspendedUpdate == nil else { return }
    await withCheckedContinuation { updateStartedWaiters.append($0) }
  }
  func waitUntilSaveStarts() async {
    guard suspendedSave == nil else { return }
    await withCheckedContinuation { saveStartedWaiters.append($0) }
  }
  func resumeUpdate() { suspendedUpdate?.resume(); suspendedUpdate = nil }
  func resumeSave() { suspendedSave?.resume(); suspendedSave = nil }
}

@MainActor
struct PreferenceUploadTests {
  @MainActor private struct Context {
    let model: OnboardingModel
    let service: FakePreferenceService
    let store: FileOnboardingProgressStore
    let authentication: AuthenticationModel
    let directory: URL
    let setup: AccountSetup
    func pending() throws -> PendingPreferenceUpdate? {
      try store.load(accountID: "preview-user")?.pendingPreferenceUpdate
    }
  }

  private func context(needsUpload: Bool) async throws -> Context {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: needsUpload)
    try store.save(progress, accountID: "preview-user")
    let service = FakePreferenceService(setup: setup)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: authentication)
    return Context(model: model, service: service, store: store, authentication: authentication,
      directory: directory, setup: setup)
  }

  private func prefs(_ unit: WeightUnit, _ days: Int) -> AccountPreferences {
    AccountPreferences(preferredUnit: unit, trainingDays: days)
  }

  @Test func changeWhileSetupIsPendingFoldsIntoThePendingSetupPayload() async throws {
    let ctx = try await context(needsUpload: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.setPreferredUnit(.pounds))
    #expect(ctx.model.setTrainingDays(5))
    #expect(try ctx.pending() == nil)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.saved.count == 1)
    #expect(ctx.service.saved.first?.preferredUnit == .pounds)
    #expect(ctx.service.saved.first?.trainingDays == 5)
    #expect(ctx.service.saved.first?.cycleID == ctx.setup.cycleID)
    #expect(ctx.service.updates.isEmpty)
  }

  @Test func changeAfterAcknowledgmentIsRecordedAndSentWithTheUpdateOperation() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.setPreferredUnit(.pounds))
    #expect(try ctx.pending()?.preferences == prefs(.pounds, 3))
    #expect(ctx.model.hasUnsentPreferenceUpdate)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 3)])
    #expect(ctx.service.saved.isEmpty)
    #expect(try ctx.pending() == nil)
    #expect(!ctx.model.hasUnsentPreferenceUpdate)
    #expect(ctx.model.weightUnit == .pounds)
  }

  @Test func aNewerChangeReplacesAnUnsentOlderOneSoOnlyTheLatestValuesAreSent() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.setPreferredUnit(.pounds))
    #expect(ctx.model.setTrainingDays(5))
    #expect(ctx.model.setTrainingDays(2))
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 2)])
    #expect(try ctx.pending() == nil)
  }

  @Test func temporaryFailureKeepsTheUpdatePendingAndTheNextTriggerRetriesIt() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    ctx.service.outcomes = [.temporaryFailure, .temporaryFailure, .succeed]
    #expect(ctx.model.setTrainingDays(4))
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(try ctx.pending()?.preferences == prefs(.kilograms, 4))
    #expect(ctx.model.trainingDays == 4)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == Array(repeating: prefs(.kilograms, 4), count: 3))
    #expect(try ctx.pending() == nil)
  }

  @Test func aRejectedUpdateKeepsTheLocalValueAndStopsRetryingUntilANewerChange() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    ctx.service.outcomes = [.rejected]
    #expect(ctx.model.setTrainingDays(4))
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates.count == 1)
    #expect(ctx.model.trainingDays == 4)
    #expect(try ctx.store.load(accountID: "preview-user")?.trainingDays == 4)
    #expect(try ctx.pending()?.rejected == true)
    #expect(!ctx.model.hasUnsentPreferenceUpdate)
    #expect(ctx.model.setTrainingDays(5))
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.kilograms, 4), prefs(.kilograms, 5)])
    #expect(try ctx.pending() == nil)
  }

  @Test func lateResponseDoesNotClearANewerChangeAndTheLatestValuesAreSentNext() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    ctx.service.outcomes = [.suspend]
    #expect(ctx.model.setTrainingDays(4))
    let upload = Task { await ctx.model.uploadCompletedSetup(using: ctx.authentication) }
    await ctx.service.waitUntilUpdateStarts()
    #expect(ctx.model.setTrainingDays(2))
    ctx.service.resumeUpdate()
    await upload.value
    #expect(ctx.service.updates == [prefs(.kilograms, 4), prefs(.kilograms, 2)])
    #expect(try ctx.pending() == nil)
    #expect(ctx.model.trainingDays == 2)
  }

  @Test func lateResponseAfterTheAccountChangedLeavesTheStoredUpdateAlone() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    ctx.service.outcomes = [.suspend]
    #expect(ctx.model.setTrainingDays(4))
    let upload = Task { await ctx.model.uploadCompletedSetup(using: ctx.authentication) }
    await ctx.service.waitUntilUpdateStarts()
    ctx.model.resetAccount()
    ctx.service.resumeUpdate()
    await upload.value
    #expect(try ctx.pending()?.preferences == prefs(.kilograms, 4))
    #expect(ctx.model.savedProgress == nil)
    #expect(ctx.service.updates.count == 1)
  }

  @Test func changeDuringSetupUploadSurvivesAnAcknowledgmentWithOlderValues() async throws {
    let ctx = try await context(needsUpload: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    ctx.service.suspendSave = true
    let upload = Task { await ctx.model.uploadCompletedSetup(using: ctx.authentication) }
    await ctx.service.waitUntilSaveStarts()
    #expect(ctx.model.setPreferredUnit(.pounds))
    ctx.service.suspendSave = false
    ctx.service.resumeSave()
    await upload.value
    #expect(ctx.service.saved.first?.preferredUnit == .kilograms)
    #expect(ctx.service.updates == [prefs(.pounds, 3)])
    #expect(ctx.model.weightUnit == .pounds)
    let saved = try #require(try ctx.store.load(accountID: "preview-user"))
    #expect(saved.weightUnit == .pounds)
    #expect(saved.completed?.needsUpload == false)
    #expect(saved.pendingPreferenceUpdate == nil)
  }

  @Test func theUpdateIsKeptPerAccountAndSurvivesRestart() async throws {
    let ctx = try await context(needsUpload: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.setPreferredUnit(.pounds))
    #expect(try ctx.store.load(accountID: "preview-user")?.pendingPreferenceUpdate?.preferences == prefs(.pounds, 3))
    #expect(try ctx.store.load(accountID: "other-user") == nil)
    let restarted = OnboardingModel(catalog: .bundled, setupService: ctx.service, progressStore: ctx.store)
    await restarted.resolveAccountSetup(using: ctx.authentication)
    #expect(restarted.hasUnsentPreferenceUpdate)
    await restarted.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 3)])
  }
}
