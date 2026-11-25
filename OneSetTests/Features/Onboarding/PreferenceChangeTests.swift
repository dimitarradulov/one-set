import Foundation
import Testing
@testable import OneSet

@MainActor
struct PreferenceChangeTests {
  private struct Harness {
    let model: OnboardingModel
    let store: FileOnboardingProgressStore
    let authentication: AuthenticationModel
    let directory: URL
    let setup: AccountSetup
  }

  private func harness(
    needsUpload: Bool = false,
    store makeStore: ((FileOnboardingProgressStore) -> any OnboardingProgressStore)? = nil,
    activeSession: Bool = false
  ) async throws -> (Harness, OnboardingModel) {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: needsUpload)
    try file.save(progress, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    if activeSession {
      let program = try #require(ProgramCatalog.bundled.program(id: setup.programID))
      let session = WorkoutSession(accountID: "preview-user", cycleID: setup.cycleID, program: program,
        workout: program.workouts[0], week: 1, day: 1)
      _ = try repository.start(session, exerciseLibrary: ProgramCatalog.bundled.exerciseLibrary)
    }
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      progressStore: makeStore?(file) ?? file, workoutRepository: repository)
    await model.resolveAccountSetup(using: authentication)
    return (Harness(model: model, store: file, authentication: authentication, directory: directory,
      setup: setup), model)
  }

  @Test func changingUnitSavesLocallyAndUpdatesDisplayUnit() async throws {
    let (ctx, model) = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(model.setPreferredUnit(.pounds))
    #expect(model.weightUnit == .pounds)
    let saved = try #require(try ctx.store.load(accountID: "preview-user"))
    #expect(saved.weightUnit == .pounds)
    #expect(saved.completed?.setup.preferredUnit == .pounds)
    #expect(saved.completed?.setup.programID == ctx.setup.programID)
    #expect(saved.completed?.setup.cycleID == ctx.setup.cycleID)
  }

  @Test func changingFrequencyReordersProgramsWithoutTouchingTheCurrentProgram() async throws {
    let (ctx, model) = try await harness()
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let cycleID = model.restoredCycleID
    for days in 2...5 {
      #expect(model.setTrainingDays(days))
      let first = try #require(model.programs.first)
      #expect(first.trainingDaysPerWeek == days || !model.programs.contains { $0.trainingDaysPerWeek == days })
    }
    #expect(model.selectedProgramID == ctx.setup.programID)
    #expect(model.restoredCycleID == cycleID)
    let saved = try #require(try ctx.store.load(accountID: "preview-user"))
    #expect(saved.trainingDays == 5)
    #expect(saved.completed?.setup.trainingDays == 5)
  }

  @Test func failedLocalSaveKeepsThePreviousValueAndReportsIt() async throws {
    let (ctx, model) = try await harness(store: { SwitchFailingStore(file: $0) })
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let store = try #require(model.progressStore as? SwitchFailingStore)
    store.fails = true
    #expect(!model.setPreferredUnit(.pounds))
    #expect(!model.setTrainingDays(5))
    #expect(model.weightUnit == .kilograms)
    #expect(model.trainingDays == 3)
    #expect(model.progressErrorPresented)
    #expect(try ctx.store.load(accountID: "preview-user")?.weightUnit == .kilograms)
  }

  @Test func changeKeepsPendingSetupMarkedForUpload() async throws {
    let (ctx, model) = try await harness(needsUpload: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(model.setPreferredUnit(.pounds))
    #expect(model.setTrainingDays(4))
    let completed = try #require(try ctx.store.load(accountID: "preview-user")?.completed)
    #expect(completed.needsUpload)
    #expect(completed.setup.preferredUnit == .pounds)
    #expect(completed.setup.trainingDays == 4)
  }

  @Test func unitsAreUnavailableDuringAnActiveSessionAndAvailableAfterwards() async throws {
    let (ctx, model) = try await harness(activeSession: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    #expect(!model.canChangeUnits)
    #expect(!model.setPreferredUnit(.pounds))
    #expect(model.weightUnit == .kilograms)
    #expect(try ctx.store.load(accountID: "preview-user")?.weightUnit == .kilograms)
    #expect(model.setTrainingDays(4))
    model.activeWorkoutSession = nil
    #expect(model.canChangeUnits)
    #expect(model.setPreferredUnit(.pounds))
  }

  @Test func activeSessionKeepsTheUnitCapturedAtStartWhenPreferencesAreAdopted() async throws {
    let (ctx, model) = try await harness(activeSession: true)
    defer { try? FileManager.default.removeItem(at: ctx.directory) }
    let session = try #require(model.activeWorkoutSession)
    #expect(session.weightUnit == .kilograms)
    let server = AccountSetup(preferredUnit: .pounds, trainingDays: 4,
      programID: ctx.setup.programID, cycleID: ctx.setup.cycleID)
    try model.adoptServerPreferences(server, accountID: "preview-user")
    #expect(model.weightUnit == .pounds)
    #expect(model.activeWorkoutSession?.weightUnit == .kilograms)
    #expect(try model.workoutRepository?.activeSession(accountID: "preview-user")?.weightUnit == .kilograms)
  }
}
