import Foundation
import Testing
@testable import OneSet

@MainActor
private final class FakeAccountSetupService: AccountSetupService {
  var lookupResult: AccountSetup?
  private(set) var updates: [AccountPreferences] = []

  init(lookupResult: AccountSetup?) { self.lookupResult = lookupResult }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { lookupResult }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { setup }
  func updatePreferences(_ preferences: AccountPreferences, for user: AuthenticatedUser) async throws -> AccountPreferences {
    updates.append(preferences)
    return preferences
  }
}

@MainActor
struct PreferenceRestoreSignOutTests {
  private static let accountID = "preview-user"

  @MainActor private struct Context {
    let model: OnboardingModel
    let service: FakeAccountSetupService
    let store: FileOnboardingProgressStore
    let authentication: AuthenticationModel
    let directory: URL
    let local: AccountSetup
  }

  private func prefs(_ unit: WeightUnit, _ days: Int) -> AccountPreferences {
    AccountPreferences(preferredUnit: unit, trainingDays: days)
  }

  /// A device whose account document holds acknowledged setup (kg, 3 days) and optionally a pending
  /// preference update. The server reports `server` for the account.
  private func context(
    pending: PendingPreferenceUpdate? = nil, local localPreferences: AccountPreferences? = nil,
    server: AccountPreferences, withRepository: Bool = false, resolve: Bool = true
  ) async throws -> Context {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let cycleID = UUID()
    let shown = localPreferences ?? prefs(.kilograms, 3)
    let local = AccountSetup(preferredUnit: shown.preferredUnit, trainingDays: shown.trainingDays,
      programID: "machine-full-body", cycleID: cycleID)
    var progress = OnboardingProgress(weightUnit: local.preferredUnit, trainingDays: local.trainingDays,
      selectedProgramID: local.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: local, needsUpload: false)
    if withRepository {
      progress.cycles = ProgramCycleState(selectedProgramID: local.programID, selectedCycleID: cycleID,
        knownCycles: [], discoveryComplete: false, pendingCreations: [], locallyKnownProgressCycleIDs: [cycleID])
    }
    progress.pendingPreferenceUpdate = pending
    try store.save(progress, accountID: Self.accountID)
    let remote = AccountSetup(preferredUnit: server.preferredUnit, trainingDays: server.trainingDays,
      programID: local.programID, cycleID: cycleID)
    let service = FakeAccountSetupService(lookupResult: remote)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: withRepository
        ? try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")) : nil)
    if resolve { await model.resolveAccountSetup(using: authentication) }
    return Context(model: model, service: service, store: store, authentication: authentication,
      directory: directory, local: local)
  }

  // MARK: Restore

  @Test func serverValuesReplaceLocalOnesWhenNothingIsUnsent() async throws {
    let ctx = try await context(server: prefs(.pounds, 5))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.weightUnit == .pounds)
    #expect(ctx.model.trainingDays == 5)
    let saved = try #require(try ctx.store.load(accountID: Self.accountID))
    #expect(saved.weightUnit == .pounds)
    #expect(saved.trainingDays == 5)
    #expect(saved.completed?.setup.preferredUnit == .pounds)
    #expect(saved.pendingPreferenceUpdate == nil)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates.isEmpty)
  }

  @Test func serverValuesApplyWhenRestoringFromASavedAccountInTheBackground() async throws {
    let ctx = try await context(server: prefs(.pounds, 5), withRepository: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.weightUnit == .pounds)
    #expect(ctx.model.trainingDays == 5)
    let saved = try #require(try ctx.store.load(accountID: Self.accountID))
    #expect(saved.completed?.setup.trainingDays == 5)
    #expect(saved.completed?.setup.programID == ctx.local.programID)
  }

  @Test func anUnsentLocalChangeWinsOverServerValuesAndIsUploaded() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 4), sequence: 1)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 4), server: prefs(.kilograms, 2))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.weightUnit == .pounds)
    #expect(ctx.model.trainingDays == 4)
    #expect(ctx.model.hasUnsentPreferenceUpdate)
    let saved = try #require(try ctx.store.load(accountID: Self.accountID))
    #expect(saved.weightUnit == .pounds)
    #expect(saved.completed?.setup.trainingDays == 4)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 4)])
    #expect(!ctx.model.hasUnsentPreferenceUpdate)
    #expect(try ctx.store.load(accountID: Self.accountID)?.pendingPreferenceUpdate == nil)
  }

  @Test func anUnsentLocalChangeWinsWhenRestoringFromASavedAccountInTheBackground() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 4), sequence: 1)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 4), server: prefs(.kilograms, 2),
      withRepository: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.weightUnit == .pounds)
    #expect(ctx.model.trainingDays == 4)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 4)])
  }

  @Test func aRejectedChangeNeverUploadsSoServerValuesReplaceIt() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 4), sequence: 1, rejected: true)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 4), server: prefs(.kilograms, 2))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(ctx.model.weightUnit == .kilograms)
    #expect(ctx.model.trainingDays == 2)
    #expect(try ctx.store.load(accountID: Self.accountID)?.pendingPreferenceUpdate == nil)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates.isEmpty)
  }

  // MARK: Sign-out

  @Test func signOutWithAnUnsentChangeWarnsBeforeDiscardingAndCancelKeepsItForUpload() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 3), sequence: 1)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 3), server: prefs(.pounds, 3))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    await ctx.model.signOut(using: ctx.authentication)
    #expect(ctx.model.discardSetupPresented)
    #expect(ctx.model.discardsOnlyPreferenceChanges)
    #expect(!ctx.model.signOutConfirmationPresented)
    #expect(ctx.authentication.signedInUser != nil)
    // Cancel changes nothing: the alert only dismisses.
    ctx.model.discardSetupPresented = false
    #expect(try ctx.store.load(accountID: Self.accountID)?.pendingPreferenceUpdate != nil)
    await ctx.model.uploadCompletedSetup(using: ctx.authentication)
    #expect(ctx.service.updates == [prefs(.pounds, 3)])
    #expect(try ctx.store.load(accountID: Self.accountID)?.pendingPreferenceUpdate == nil)
  }

  @Test func confirmingSignOutDiscardsTheUnsentChange() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 3), sequence: 1)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 3), server: prefs(.pounds, 3))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    await ctx.model.signOut(using: ctx.authentication)
    #expect(ctx.model.discardSetupPresented)
    await ctx.model.signOut(using: ctx.authentication, discardPending: true)
    #expect(ctx.authentication.signedInUser == nil)
    #expect(try ctx.store.load(accountID: Self.accountID) == nil)
    #expect(ctx.service.updates.isEmpty)
  }

  @Test func signOutWithNothingUnsentUsesOnlyTheOrdinaryConfirmation() async throws {
    let ctx = try await context(server: prefs(.kilograms, 3))
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    await ctx.model.signOut(using: ctx.authentication)
    #expect(!ctx.model.discardSetupPresented)
    #expect(ctx.model.signOutConfirmationPresented)
  }

  @Test func aRejectedChangeIsNotUnsentSoSignOutDoesNotWarnAboutIt() async throws {
    let pending = PendingPreferenceUpdate(preferences: prefs(.pounds, 3), sequence: 1, rejected: true)
    let ctx = try await context(pending: pending, local: prefs(.pounds, 3), server: prefs(.pounds, 3),
      resolve: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    await ctx.model.resolveAccountSetup(using: ctx.authentication)
    await ctx.model.signOut(using: ctx.authentication)
    #expect(!ctx.model.discardSetupPresented)
    #expect(ctx.model.signOutConfirmationPresented)
  }

  @Test func pendingSetupStillUsesTheSetupDiscardMessage() async throws {
    let ctx = try await context(server: prefs(.kilograms, 3), resolve: false)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    var progress = try #require(try ctx.store.load(accountID: Self.accountID))
    progress.completed = CompletedOnboarding(setup: ctx.local, needsUpload: true)
    try ctx.store.save(progress, accountID: Self.accountID)
    ctx.service.lookupResult = nil
    await ctx.model.resolveAccountSetup(using: ctx.authentication)
    await ctx.model.signOut(using: ctx.authentication)
    #expect(ctx.model.discardSetupPresented)
    #expect(!ctx.model.discardsOnlyPreferenceChanges)
  }
}
