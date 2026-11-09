import Foundation
import Testing
@testable import OneSet

extension ProgramCatalogOnboardingTests {
  @Test
  func reselectingReofferedProgramRetriesItsRejectedCycle() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let old = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: setup.programID, selectedCycleID: setup.cycleID,
      knownCycles: [old], discoveryComplete: true, pendingCreations: [old],
      locallyKnownProgressCycleIDs: [old.cycleID], pendingActivations: [old.cycleID], rejectedCycleIDs: [old.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = RecordingCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    model.switchToProgram(old.programID, using: auth)
    await model.uploadPendingCycles(using: auth)
    #expect(service.created.contains(old.cycleID))
    #expect(model.cycleConflictMessage == nil)
  }

  @Test
  func rejectedIntermediateCycleDoesNotBlockFollowingCapturedPreferences() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = try #require(ProgramCatalog.bundled.program(id: "push-pull-legs"))
    let slot = try #require(target.workouts.first?.exercises.first?.id)
    let preference = CyclePreference(workoutExerciseID: slot, exerciseID: nil, note: "captured", restSeconds: 90)
    let intermediate = AccountCycle(cycleID: UUID(), programID: "bro-split",
      startedAt: "2026-01-01T00:00:00Z", preferences: [preference])
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: intermediate.programID, selectedCycleID: intermediate.cycleID,
      knownCycles: [intermediate], discoveryComplete: true, pendingCreations: [intermediate],
      locallyKnownProgressCycleIDs: [intermediate.cycleID], pendingActivations: [intermediate.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = RejectingCycleService(rejected: intermediate.cycleID)
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    model.switchToProgram(target.id, using: auth)
    let targetID = try #require(model.restoredCycleID)
    #expect(targetID != intermediate.cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.last?.preferences == [preference])
    await model.uploadPendingCycles(using: auth)
    #expect(service.creations.contains(targetID))
    #expect(service.payloads.first(where: { $0.cycleID == targetID })?.preferences == [preference])
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.contains(where: { $0.cycleID == intermediate.cycleID }) == true)
  }

  @Test
  func incompleteCyclePreferenceLookupIsRejected() throws {
    let data = Data("""
      {"selected_cycle_id":null,"cycles":[{"cycle_id":"11111111-1111-4111-8111-111111111111","program_id":"machine-full-body","started_at":"2026-01-01T00:00:00Z"}]}
      """.utf8)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(AccountCycles.self, from: data) }
  }

  @Test
  func resumingPreviousProgramRestoresItsCycleAndProgressAfterReopening() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let repositoryURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: repositoryURL)
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    try repository.restoreProgress(AccountProgress(cycleID: setup.cycleID, programID: setup.programID,
      currentTrainingWeek: 3, completedOccurrences: [.init(weekNumber: 3, workoutID: "machine-full-body-workout-a")],
      workoutPeriods: [], requiredWorkoutIDs: ["machine-full-body-workout-a", "machine-full-body-workout-b"]), accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store, workoutRepository: repository)
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram("bro-split", using: auth)
    #expect(model.selectedProgramID == "bro-split")
    model.switchToProgram(setup.programID, using: auth)
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.currentWorkoutWeek(programID: setup.programID) == 3)
    #expect(model.completedWorkoutIDs(programID: setup.programID, week: 3).contains("machine-full-body-workout-a"))
    #expect(model.weightUnit == .pounds)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: repositoryURL))
    await reopened.resolveAccountSetup(using: auth)
    #expect(reopened.selectedProgramID == setup.programID)
    #expect(reopened.restoredCycleID == setup.cycleID)
    #expect(reopened.currentWorkoutWeek(programID: setup.programID) == 3)
  }

  @Test
  func replacementDeviceRestoresOtherCycleProgressAndCanResumeOffline() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let previous = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    let cycles = RecordingCycleService()
    cycles.knownCycles = [AccountCycle(cycleID: setup.cycleID, programID: setup.programID,
      startedAt: "2026-02-01T00:00:00Z"), previous]
    let summary = AccountProgress(cycleID: previous.cycleID, programID: previous.programID,
      currentTrainingWeek: 3, completedOccurrences: [.init(weekNumber: 3, workoutID: "bro-split-workout-a")],
      workoutPeriods: [], requiredWorkoutIDs: ["bro-split-workout-a", "bro-split-workout-b"])
    let storeURL = directory.appending(path: "progress.json")
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(cycles, setup: setup), progressService: PerCycleProgressService(summaries: [previous.cycleID: summary], active: AccountProgress(
        cycleID: setup.cycleID, programID: setup.programID, currentTrainingWeek: 1,
        completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])),
      progressStore: FileOnboardingProgressStore(fileURL: storeURL),
      workoutRepository: try WorkoutRepository(databaseURL: databaseURL))
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram(previous.programID, using: auth)
    #expect(model.restoredCycleID == previous.cycleID)
    #expect(model.currentWorkoutWeek(programID: previous.programID) == 3)
    #expect(model.completedWorkoutIDs(programID: previous.programID, week: 3).contains("bro-split-workout-a"))
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: FileOnboardingProgressStore(fileURL: storeURL),
      workoutRepository: try WorkoutRepository(databaseURL: databaseURL))
    await reopened.resolveAccountSetup(using: auth)
    #expect(reopened.restoredCycleID == previous.cycleID)
    #expect(reopened.currentWorkoutWeek(programID: previous.programID) == 3)
  }

  @Test
  func delayedProgressCannotOverwriteNewSelection() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let previous = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    let service = RecordingCycleService()
    service.knownCycles = [previous]
    let progress = SuspendedCycleProgressService(summary: AccountProgress(cycleID: previous.cycleID,
      programID: previous.programID, currentTrainingWeek: 3, completedOccurrences: [],
      workoutPeriods: [], requiredWorkoutIDs: []), active: AccountProgress(cycleID: setup.cycleID,
      programID: setup.programID, currentTrainingWeek: 1, completedOccurrences: [],
      workoutPeriods: [], requiredWorkoutIDs: []))
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressService: progress,
      progressStore: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")),
      workoutRepository: repository)
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: auth)
    let refresh = Task { await model.refreshCycleKnowledge(using: auth) }
    await progress.waitUntilRequested()
    model.switchToProgram("push-pull-legs", using: auth)
    let selectedCycle = model.restoredCycleID
    progress.resume()
    await refresh.value
    #expect(model.selectedProgramID == "push-pull-legs")
    #expect(model.restoredCycleID == selectedCycle)
    #expect(try !repository.hasRestoredCycleSummary(accountID: "preview-user", cycleID: previous.cycleID))
  }

  @Test
  func delayedProgressFromPreviousAccountCannotChangeNewAccountStorage() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let previous = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    let service = RecordingCycleService()
    service.knownCycles = [previous]
    let delayed = SuspendedCycleProgressService(summary: AccountProgress(cycleID: previous.cycleID,
      programID: previous.programID, currentTrainingWeek: 3, completedOccurrences: [],
      workoutPeriods: [], requiredWorkoutIDs: []), active: AccountProgress(cycleID: setup.cycleID,
      programID: setup.programID, currentTrainingWeek: 1, completedOccurrences: [],
      workoutPeriods: [], requiredWorkoutIDs: []))
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressService: delayed,
      progressStore: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")),
      workoutRepository: repository)
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: auth)
    let refresh = Task { await model.refreshCycleKnowledge(using: auth) }
    await delayed.waitUntilRequested()
    await auth.signOut()
    await model.resolveAccountSetup(using: auth)
    await auth.signInWithGoogle()
    await model.resolveAccountSetup(using: auth)
    delayed.resume()
    await refresh.value
    #expect(auth.signedInUser?.id == "preview-google")
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(try !repository.hasRestoredCycleSummary(accountID: "preview-google", cycleID: previous.cycleID))
    #expect(try !repository.hasRestoredCycleSummary(accountID: "preview-user", cycleID: previous.cycleID))
  }

  @Test
  func failedResumeSaveKeepsCurrentCycleAndAllowsRetry() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SwitchFailingStore(file: FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json")))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram("bro-split", using: auth)
    let secondID = model.restoredCycleID
    store.fails = true
    model.switchToProgram(setup.programID, using: auth)
    #expect(model.selectedProgramID == "bro-split")
    #expect(model.restoredCycleID == secondID)
    #expect(model.cycleMessage != nil)
    store.fails = false
    model.switchToProgram(setup.programID, using: auth)
    #expect(model.restoredCycleID == setup.cycleID)
  }

  @Test
  func rapidRoundTripSendsTheFinalActivationAfterCycleCreation() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = RecordingCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram("bro-split", using: auth)
    let secondID = try #require(model.restoredCycleID)
    model.switchToProgram(setup.programID, using: auth)
    await model.uploadPendingCycles(using: auth)
    #expect(service.created == [secondID])
    #expect(service.activated == [secondID, setup.cycleID])
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingActivations?.isEmpty == true)
  }

  @Test
  func rejectedCreationIsRetainedWithoutBlockingLaterSelectionAfterRestart() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "progress.json")
    let store = FileOnboardingProgressStore(fileURL: fileURL)
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let removed = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: setup.programID, selectedCycleID: setup.cycleID,
      knownCycles: [removed], discoveryComplete: true, pendingCreations: [removed],
      pendingActivations: [removed.cycleID, setup.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = RejectingCycleService(rejected: removed.cycleID)
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.uploadPendingCycles(using: auth)
    await model.uploadPendingCycles(using: auth)
    #expect(service.creations == [removed.cycleID])
    #expect(service.activations == [setup.cycleID])
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations == [removed])
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: FileOnboardingProgressStore(fileURL: fileURL))
    await reopened.resolveAccountSetup(using: auth)
    await reopened.uploadPendingCycles(using: auth)
    #expect(service.creations == [removed.cycleID])
    #expect(reopened.restoredCycleID == setup.cycleID)
    #expect(reopened.cycleConflictMessage != nil)
  }

  @Test
  func rejectedActivationDoesNotRepeatOrBlockLaterActivation() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let removed = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: setup.programID, selectedCycleID: setup.cycleID,
      knownCycles: [removed], discoveryComplete: true, pendingCreations: [],
      pendingActivations: [removed.cycleID, setup.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = RejectingCycleService(rejected: removed.cycleID, rejectActivation: true)
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.uploadPendingCycles(using: auth)
    await model.uploadPendingCycles(using: auth)
    #expect(service.activations == [removed.cycleID, setup.cycleID])
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingActivations == [removed.cycleID])
    #expect(model.cycleConflictMessage != nil)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await reopened.resolveAccountSetup(using: auth)
    await reopened.uploadPendingCycles(using: auth)
    #expect(service.activations == [removed.cycleID, setup.cycleID])
    #expect(reopened.cycleConflictMessage != nil)
  }

  @Test
  func removalWhileBrowsingPreventsSwitchAndRestorationAllowsResume() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bundled = ProgramCatalog.bundled.programs
    let target = try #require(bundled.first(where: { $0.id == "bro-split" }))
    let service = MutableCatalogService()
    let catalog = ProgramCatalog(programs: bundled, service: service)
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: catalog, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(OfflineCycleService(), setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram(target.id, using: auth)
    let originalCycle = try #require(model.restoredCycleID)
    model.switchToProgram(setup.programID, using: auth)
    model.programPath = [.programs, .programDetail(target.id)]
    service.result = .snapshot(snapshot("removed", "removed", bundled.map { $0.id == target.id ? replacing($0, offered: false) : $0 }))
    await model.refreshCatalog()
    #expect(!model.programs.contains(where: { $0.id == target.id }))
    model.switchToProgram(target.id, using: auth)
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.programPath == [.programs, .programDetail(target.id)])
    service.result = .snapshot(snapshot("restored", "restored", bundled))
    await model.refreshCatalog()
    model.switchToProgram(target.id, using: auth)
    #expect(model.restoredCycleID == originalCycle)
  }

  @Test
  func newCatalogPublicationReleasesCurrentReofferedCycleForRetry() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bundled = ProgramCatalog.bundled.programs
    let catalogService = MutableCatalogService()
    let catalog = ProgramCatalog(programs: bundled, service: catalogService)
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let rejected = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: rejected.programID, selectedCycleID: rejected.cycleID,
      knownCycles: [rejected], discoveryComplete: true, pendingCreations: [rejected],
      pendingActivations: [rejected.cycleID], rejectedCycleIDs: [rejected.cycleID],
      unavailableAtPublication: [rejected.cycleID.uuidString: "old"])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let cycles = RecordingCycleService()
    let model = OnboardingModel(catalog: catalog, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(cycles, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    #expect(model.cycleConflictMessage != nil)
    catalogService.result = .snapshot(snapshot("new", "new", bundled))
    await model.refreshCatalog()
    await model.uploadPendingCycles(using: auth)
    #expect(cycles.created.contains(rejected.cycleID))
    #expect(model.cycleConflictMessage == nil)
  }

  @Test
  func cycleRetryBackoffSurvivesReopeningAndKeepsTheOriginalIdentity() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "progress.json")
    let store = FileOnboardingProgressStore(fileURL: fileURL)
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: target.programID, selectedCycleID: target.cycleID,
      knownCycles: [target], discoveryComplete: true, pendingCreations: [target],
      pendingActivations: [target.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = BackoffCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    await model.uploadPendingCycles(using: auth, at: now)
    #expect(service.attempts == [target.cycleID])

    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: FileOnboardingProgressStore(fileURL: fileURL))
    await reopened.resolveAccountSetup(using: auth)
    service.available = true
    await reopened.uploadPendingCycles(using: auth, at: now.addingTimeInterval(14))
    #expect(service.attempts == [target.cycleID])
    await reopened.uploadPendingCycles(using: auth, at: now.addingTimeInterval(15))
    #expect(service.attempts == [target.cycleID, target.cycleID])
    #expect(reopened.restoredCycleID == target.cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.isEmpty == true)
  }

  @Test
  func lostCreationResponseAndRoundTripKeepTheLastSelectionAfterRestart() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "progress.json")
    let store = FileOnboardingProgressStore(fileURL: fileURL)
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: setup.programID, selectedCycleID: setup.cycleID,
      knownCycles: [target], discoveryComplete: true, pendingCreations: [target],
      locallyKnownProgressCycleIDs: [setup.cycleID, target.cycleID],
      pendingActivations: [target.cycleID, setup.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = LostCycleResponseService(selected: setup.cycleID)
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    await model.uploadPendingCycles(using: auth, at: now)
    #expect(service.selected == target.cycleID)
    #expect(model.restoredCycleID == setup.cycleID)
    let reopened = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: FileOnboardingProgressStore(fileURL: fileURL))
    await reopened.resolveAccountSetup(using: auth)
    await reopened.uploadPendingCycles(using: auth, at: now.addingTimeInterval(15))
    #expect(service.created == [target.cycleID])
    #expect(service.selected == setup.cycleID)
    #expect(reopened.restoredCycleID == setup.cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingActivations?.isEmpty == true)
  }

  @Test
  func lateCycleAcknowledgmentAfterSignOutLeavesOwnerWorkPending() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: target.programID, selectedCycleID: target.cycleID,
      knownCycles: [target], discoveryComplete: true, pendingCreations: [target],
      pendingActivations: [target.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = SuspendedCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    let upload = Task { await model.uploadPendingCycles(using: auth) }
    await service.waitUntilStarted()
    await auth.signOut()
    await model.resolveAccountSetup(using: auth)
    service.finish()
    await upload.value
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.first?.cycleID == target.cycleID)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingActivations == [target.cycleID])
    #expect(try store.load(accountID: "other-user") == nil)
  }

  @Test
  func cycleAuthenticationFailureWaitsForSignInBeforeRetrying() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let target = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: target.programID, selectedCycleID: target.cycleID,
      knownCycles: [target], discoveryComplete: true, pendingCreations: [target],
      pendingActivations: [target.cycleID])
    try store.save(progress, accountID: "preview-user")
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let service = AuthenticationCycleService()
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store)
    await model.resolveAccountSetup(using: auth)
    await model.uploadPendingCycles(using: auth)
    service.authenticated = true
    await model.uploadPendingCycles(using: auth)
    #expect(service.attempts == 1)
    #expect(model.cycleMessage?.contains("Sign in") == true)
    await model.resumeDeferredSessionUploads(using: auth)
    #expect(service.attempts == 2)
    #expect(try store.load(accountID: "preview-user")?.cycles?.pendingCreations.isEmpty == true)
  }

  @Test
  func missingProgressForKnownCycleDoesNotResetOrSelectIt() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "progress.json"))
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let service = RecordingCycleService()
    service.knownCycles = [AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")]
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup),
      cycleService: CycleServiceWithSetup(service, setup: setup), progressStore: store, workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    await model.resolveAccountSetup(using: auth)
    await model.refreshCycleKnowledge(using: auth)
    model.switchToProgram("bro-split", using: auth)
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.cycleMessage != nil)
    #expect(service.created.isEmpty)
  }
}
