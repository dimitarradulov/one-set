import Foundation
import Testing
@testable import OneSet

extension ProgramCatalogOnboardingTests {
  @Test
  func failedCycleDiscoveryDoesNotTreatUnknownProgramAsNew() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: UnavailableCycleService(), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram("bro-split", using: auth)
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.cycleMessage != nil)
    #expect(try store.load(accountID: "preview-user")?.cycles == nil)
  }

  @Test
  func unfinishedWorkoutBlocksBrowsingAndSelectionAfterRestart() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let repositoryURL = directory.appending(path: "workouts.sqlite")
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: repositoryURL))
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    #expect(model.activeWorkoutSession != nil)
    model.showProgramSwitcher()
    #expect(model.switchBlockedPresented)
    model.switchToProgram("bro-split", using: auth)
    #expect(model.selectedProgramID == setup.programID)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: repositoryURL))
    await reopened.resolveAccountSetup(using: auth)
    reopened.showProgramSwitcher()
    #expect(reopened.switchBlockedPresented)
    #expect(reopened.activeWorkoutSession?.id == model.activeWorkoutSession?.id)
  }

  @Test
  func failedSwitchSaveKeepsPreviousSelection() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SwitchFailingStore(file: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: authentication)
    await model.refreshCycleKnowledge(using: authentication)
    let target = try #require(model.programs.first(where: { $0.id != setup.programID }))
    store.fails = true
    model.switchToProgram(target.id, using: authentication)
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.cycleMessage != nil)
    store.fails = false
    model.switchToProgram(target.id, using: authentication)
    #expect(model.selectedProgramID == target.id)
  }

  @Test
  func firstSwitchSurvivesReopeningWithTheSamePendingCycle() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = OfflineCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: authentication)
    await model.refreshCycleKnowledge(using: authentication)
    let target = try #require(model.programs.first(where: { $0.id != setup.programID }))
    model.showProgramSwitcher()
    model.switchToProgram(target.id, using: authentication)
    let cycleID = try #require(model.restoredCycleID)
    #expect(model.selectedProgramID == target.id)
    #expect(model.programPath.isEmpty)
    #expect(cycleID != setup.cycleID)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")))
    await reopened.resolveAccountSetup(using: authentication)
    #expect(reopened.selectedProgramID == target.id)
    #expect(reopened.restoredCycleID == cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.first?.cycleID == cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.first?.preferences == [])
  }

  @Test
  func restoredServerSelectionRequiresExplicitUpdate() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let server = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let old = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: server.preferredUnit, trainingDays: server.trainingDays,
      selectedProgramID: server.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: server, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: old.programID, selectedCycleID: old.cycleID,
      knownCycles: [old], discoveryComplete: true, pendingCreations: [], locallyKnownProgressCycleIDs: [old.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let oldSetup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: old.programID, cycleID: old.cycleID)
    let control = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: oldSetup),
      workoutRepository: repository)
    await control.resolveAccountSetup(using: auth)
    let workoutID = try #require(control.program(id: old.programID)?.workouts.first?.id)
    control.startWorkout(programID: old.programID, workoutID: workoutID, accountID: "preview-user")
    #expect(control.activeWorkoutSession != nil)
    control.discardActiveWorkout(accountID: "preview-user")
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: server),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: server), progressStore: store,
      workoutRepository: repository)
    await model.resolveAccountSetup(using: auth)
    #expect(model.selectedProgramID == old.programID)
    #expect(model.restoredCycleID == old.cycleID)
    #expect(model.requiresProgramUpdate)
    model.startWorkout(programID: old.programID, workoutID: workoutID, accountID: "preview-user")
    #expect(model.activeWorkoutSession == nil)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: nil),
      progressStore: store, workoutRepository: repository)
    await reopened.resolveAccountSetup(using: auth)
    #expect(reopened.selectedProgramID == old.programID)
    #expect(reopened.requiresProgramUpdate)
  }

  @Test
  func remoteUpdateRestoresProgressOnlyAfterExplicitAction() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let old = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    let remote = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    var progress = OnboardingProgress(weightUnit: old.preferredUnit, trainingDays: old.trainingDays,
      selectedProgramID: old.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: old, needsUpload: false)
    try store.save(progress, accountID: "preview-user")
    let summary = AccountProgress(cycleID: remote.cycleID, programID: remote.programID,
      currentTrainingWeek: 3, completedOccurrences: [], workoutPeriods: [],
      requiredWorkoutIDs: ["machine-full-body-workout-a"])
    let oldSummary = AccountProgress(cycleID: old.cycleID, programID: old.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    let cycle = AccountCycle(cycleID: remote.cycleID, programID: remote.programID,
      startedAt: "2026-01-01T00:00:00Z")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: remote),
      cycleService: SelectedCycleService(cycle: cycle),
      progressService: PerCycleProgressService(summaries: [old.cycleID: oldSummary, remote.cycleID: summary], active: summary),
      progressStore: store, workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: auth)
    #expect(model.requiresProgramUpdate)
    #expect(model.selectedProgramID == old.programID)
    await model.updateRemoteProgram(using: auth)
    #expect(!model.requiresProgramUpdate)
    #expect(model.selectedProgramID == remote.programID)
    #expect(model.restoredCycleID == remote.cycleID)
    #expect(model.currentWorkoutWeek(programID: remote.programID) == 3)
  }

  @Test
  func supersededRemoteSelectionCanBeConfirmedBackToCurrentCycle() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let old = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let changed = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    var progress = OnboardingProgress(weightUnit: old.preferredUnit, trainingDays: old.trainingDays,
      selectedProgramID: old.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: old, needsUpload: false)
    try store.save(progress, accountID: "preview-user")
    let cycle = AccountCycle(cycleID: old.cycleID, programID: old.programID, startedAt: "2026-01-01T00:00:00Z")
    let summary = AccountProgress(cycleID: old.cycleID, programID: old.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [],
      requiredWorkoutIDs: ["machine-full-body-workout-a"])
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: changed),
      cycleService: SelectedCycleService(cycle: cycle),
      progressService: PerCycleProgressService(summaries: [old.cycleID: summary], active: summary),
      progressStore: store, workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: auth)
    #expect(model.requiresProgramUpdate)
    await model.refreshCycleKnowledge(using: auth)
    #expect(model.requiresProgramUpdate)
    await model.updateRemoteProgram(using: auth)
    #expect(!model.requiresProgramUpdate)
    #expect(model.restoredCycleID == old.cycleID)
  }

  @Test
  func failedDiscoverySaveKeepsConfirmedChangeBlockedInCurrentSession() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let store = FailDiscoverySaveStore(file: file)
    let old = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let changed = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    var progress = OnboardingProgress(weightUnit: old.preferredUnit, trainingDays: old.trainingDays,
      selectedProgramID: old.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: old, needsUpload: false)
    try file.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    try repository.restoreProgress(AccountProgress(cycleID: old.cycleID, programID: old.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: []), accountID: "preview-user")
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: changed),
      progressStore: store, workoutRepository: repository)
    await model.resolveAccountSetup(using: auth)
    #expect(model.requiresProgramUpdate)
    #expect(model.programUpdateMessage != nil)
    #expect(model.selectedProgramID == old.programID)
    #expect(try file.load(accountID: "preview-user")?.pendingRemoteSelection == nil)
  }

  @Test(arguments: [false, true])
  func overlappingDiscoveryCannotEraseNewerSelection(firstFails: Bool) async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let old = AccountCycle(cycleID: setup.cycleID, programID: setup.programID, startedAt: "2026-01-01T00:00:00Z")
    let changed = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    let service = InterleavedDiscoveryService()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: service, progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: auth)
    let first = Task { await model.refreshCycleKnowledge(using: auth) }
    await service.waitForRequests(1)
    let second = Task { await model.refreshCycleKnowledge(using: auth) }
    await service.waitForRequests(2)
    service.respond(1, result: .success(AccountCycles(cycles: [changed], selectedCycleID: changed.cycleID)))
    await second.value
    #expect(model.requiresProgramUpdate)
    let stale: Result<AccountCycles, any Error> = firstFails ? .failure(AccountCycleError.unavailable)
      : .success(AccountCycles(cycles: [old], selectedCycleID: old.cycleID))
    service.respond(0, result: stale)
    await first.value
    #expect(model.requiresProgramUpdate)
    #expect(try store.load(accountID: "preview-user")?.pendingRemoteSelection?.cycleID == changed.cycleID)
    model.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    #expect(model.activeWorkoutSession == nil)
  }

  @Test
  func overlappingUnchangedDiscoveriesDoNotBlockWorkouts() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let current = AccountCycle(cycleID: setup.cycleID, programID: setup.programID, startedAt: "2026-01-01T00:00:00Z")
    let service = InterleavedDiscoveryService()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: service, progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: auth)
    let first = Task { await model.refreshCycleKnowledge(using: auth) }
    await service.waitForRequests(1)
    #expect(try store.load(accountID: "preview-user")?.pendingRemoteSelection == nil)
    let second = Task { await model.refreshCycleKnowledge(using: auth) }
    await service.waitForRequests(2)
    let unchanged = AccountCycles(cycles: [current], selectedCycleID: current.cycleID)
    service.respond(1, result: .success(unchanged))
    await second.value
    service.respond(0, result: .success(unchanged))
    await first.value
    #expect(!model.requiresProgramUpdate)
    #expect(try store.load(accountID: "preview-user")?.pendingRemoteSelection == nil)
    model.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    #expect(model.activeWorkoutSession != nil)
  }

  @Test
  func newerDiscoveryPreventsOlderUpdateFromApplyingAnotherCycle() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let old = AccountSetup(preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body", cycleID: UUID())
    let pending = AccountSetup(preferredUnit: .kilograms, trainingDays: 3, programID: "bro-split", cycleID: UUID())
    let newerCycle = AccountCycle(cycleID: pending.cycleID, programID: pending.programID, startedAt: "2026-01-01T00:00:00Z")
    let otherCycle = AccountCycle(cycleID: UUID(), programID: "machine-full-body", startedAt: "2026-01-01T00:00:00Z")
    var saved = OnboardingProgress(weightUnit: old.preferredUnit, trainingDays: old.trainingDays, selectedProgramID: old.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: old, needsUpload: false)
    saved.pendingRemoteSelection = pending
    try store.save(saved, accountID: "preview-user")
    let active = AccountProgress(cycleID: old.cycleID, programID: old.programID, currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    let other = AccountProgress(cycleID: otherCycle.cycleID, programID: otherCycle.programID, currentTrainingWeek: 2, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    let progress = SelectivelySuspendedProgressService(active: active, suspended: other)
    let cycles = MutableSelectedCycleService(cycle: otherCycle)
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    try repository.restoreProgress(active, accountID: "preview-user")
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: nil), cycleService: cycles,
      progressService: progress, progressStore: store, workoutRepository: repository)
    await model.resolveAccountSetup(using: auth)
    let update = Task { await model.updateRemoteProgram(using: auth) }
    await progress.waitUntilRequested()
    cycles.cycle = newerCycle
    await model.refreshCycleKnowledge(using: auth)
    progress.resume()
    await update.value
    #expect(model.requiresProgramUpdate)
    #expect(model.restoredCycleID == old.cycleID)
    #expect(try store.load(accountID: "preview-user")?.pendingRemoteSelection?.cycleID == pending.cycleID)
  }

  @Test
  func discoveryWriteFailureRestoresActiveWorkout() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let repositoryURL = directory.appending(path: "workouts.sqlite")
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let remote = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let original = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      progressStore: file, workoutRepository: try WorkoutRepository(databaseURL: repositoryURL))
    await original.resolveAccountSetup(using: auth)
    original.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    let sessionID = try #require(original.activeWorkoutSession?.id)
    let store = FailOnSaveStore(file: file, failOnSave: 1)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: remote),
      progressStore: store, workoutRepository: try WorkoutRepository(databaseURL: repositoryURL))
    await reopened.resolveAccountSetup(using: auth)
    #expect(reopened.selectedProgramID == setup.programID)
    #expect(reopened.activeWorkoutSession?.id == sessionID)
    #expect(reopened.requiresProgramUpdate)
    #expect(reopened.programUpdateMessage != nil)
    let slotID = try #require(reopened.activeWorkoutSession?.exercises.first?.slotID)
    reopened.scheduleWorkoutEdit(sessionID: sessionID, slotID: slotID, input: .init(weight: "50", reps: "8"))
    #expect(await reopened.flushWorkoutEdits(sessionID: sessionID))
    reopened.discardActiveWorkout(accountID: "preview-user")
    #expect(reopened.activeWorkoutSession == nil)
    #expect(reopened.requiresProgramUpdate)
  }

  @Test
  func detectedChangePreservesActiveWorkoutUntilDiscardAndExplicitUpdate() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SwitchFailingStore(file: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    let summary = AccountProgress(cycleID: target.cycleID, programID: target.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    let service = MutableSelectedCycleService(cycle: target)
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.file.save(progress, accountID: "preview-user")
    let initial = AccountProgress(cycleID: setup.cycleID, programID: setup.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    let workable = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: service, progressService: PerCycleProgressService(summaries: [target.cycleID: summary], active: initial),
      progressStore: store, workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await workable.resolveAccountSetup(using: auth)
    workable.previewWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a")
    workable.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    let sessionID = try #require(workable.activeWorkoutSession?.id)
    await workable.refreshCycleKnowledge(using: auth)
    #expect(workable.requiresProgramUpdate)
    await workable.updateRemoteProgram(using: auth)
    #expect(workable.activeWorkoutSession?.id == sessionID)
    #expect(workable.programUpdateMessage?.contains("Finish or discard") == true)
    workable.discardActiveWorkout(accountID: "preview-user")
    #expect(workable.requiresProgramUpdate)
    store.fails = true
    await workable.updateRemoteProgram(using: auth)
    #expect(workable.requiresProgramUpdate)
    #expect(workable.selectedProgramID == setup.programID)
    store.fails = false
    await workable.updateRemoteProgram(using: auth)
    #expect(!workable.requiresProgramUpdate)
    #expect(workable.restoredCycleID == target.cycleID)
  }
}
