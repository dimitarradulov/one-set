import Foundation
import Testing
@testable import OneSet

@MainActor
struct CompletedSessionUploadTests {
  @Test
  func replacementDeviceRestoresCycleBoundaryAndOccurrenceMarksWithoutHistorySessions() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(
      preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    )
    let program = try #require(ProgramCatalog.bundled.program(id: setup.programID))
    let required = program.workouts.map(\.id)
    let summary = AccountProgress(
      cycleID: setup.cycleID, programID: setup.programID, currentTrainingWeek: 9,
      completedOccurrences: [.init(weekNumber: 9, workoutID: required[0])],
      workoutPeriods: required.map { .init(workoutID: $0, startsWeek: 1, endsWeek: nil) },
      requiredWorkoutIDs: required
    )
    let repositoryURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: repositoryURL)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(
      catalog: .bundled, setupService: StaticAccountSetupService(setup: setup),
      progressService: StaticAccountProgressService(progress: summary), workoutRepository: repository
    )

    await model.resolveAccountSetup(using: authentication)

    #expect(model.currentWorkoutWeek(programID: setup.programID) == 9)
    #expect(model.completedWorkoutIDs(programID: setup.programID, week: 9) == [required[0]])
    let next = try repository.nextOccurrence(
      accountID: "preview-user", cycleID: setup.cycleID, programID: setup.programID, workoutIDs: required
    )
    #expect(next.week == 9)
    #expect(next.workoutID == required[1])
    #expect(try repository.hasRestorableProgress(accountID: "another-account", cycleID: setup.cycleID) == false)
    let delayed = AccountProgress(
      cycleID: setup.cycleID, programID: setup.programID, currentTrainingWeek: 8,
      completedOccurrences: [.init(weekNumber: 8, workoutID: required[0])],
      workoutPeriods: [], requiredWorkoutIDs: required
    )
    try repository.restoreProgress(delayed, accountID: "preview-user")
    #expect(try repository.nextOccurrence(accountID: "preview-user", cycleID: setup.cycleID,
      programID: setup.programID, workoutIDs: required).week == 9)

    let reopened = try WorkoutRepository(databaseURL: repositoryURL)
    #expect(try reopened.completedOccurrenceIDs(accountID: "preview-user", cycleID: setup.cycleID, week: 9) == [required[0]])
    #expect(try reopened.hasRestorableProgress(accountID: "preview-user", cycleID: setup.cycleID))
    #expect(try reopened.completedOccurrenceIDs(accountID: "preview-user", cycleID: setup.cycleID, week: 8) == [required[0]])
    #expect(try reopened.nextOccurrence(accountID: "preview-user", cycleID: setup.cycleID,
      programID: setup.programID, workoutIDs: required).workoutID == required[1])
  }

  @Test
  func retryAfterAcceptsDelaySecondsAndHttpDate() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(CompletedSessionUploadRetryPolicy.serverRetryDate(headerValue: "120", at: now)
      == now.addingTimeInterval(120))
    #expect(CompletedSessionUploadRetryPolicy.serverRetryDate(
      headerValue: "Fri, 15 Jan 2027 08:02:00 GMT", at: now
    ) == Date(timeIntervalSince1970: 1_800_000_120))
    #expect(CompletedSessionUploadRetryPolicy.serverRetryDate(headerValue: "invalid", at: now) == nil)
  }

  @Test
  func setupAcknowledgmentWithLostResponseReusesCycleBeforeDependentSessionUpload() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let localSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body",
      cycleID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    )
    var progress = OnboardingProgress(
      weightUnit: localSetup.preferredUnit, trainingDays: localSetup.trainingDays,
      selectedProgramID: localSetup.programID, nextStep: .overview
    )
    progress.completed = CompletedOnboarding(setup: localSetup, needsUpload: true)
    try store.save(progress, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let setupService = SequencedAccountSetupService(
      lookupResult: nil, saveOutcomes: [.lostAcknowledgment, .returnSetup(localSetup)]
    )
    let sessionService = CompletedSessionUploadSpy()
    let model = OnboardingModel(
      catalog: .bundled, setupService: setupService,
      completedSessionUploadService: sessionService,
      progressStore: store, workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionID = try finishOneSession(repository: repository, model: model, setup: localSetup, startingAt: date)

    await model.retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: false)
    #expect(sessionService.uploads.isEmpty)

    await model.uploadCompletedSetup(using: authentication)
    #expect(model.hasPendingSetup)
    #expect(sessionService.uploads.isEmpty)

    let reopenedRepository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let restoredSetupService = SequencedAccountSetupService(
      lookupResult: nil, saveOutcomes: [.returnSetup(localSetup)]
    )
    let restoredSessionService = CompletedSessionUploadSpy()
    let restoredModel = OnboardingModel(
      catalog: .bundled, setupService: restoredSetupService,
      completedSessionUploadService: restoredSessionService,
      progressStore: store,
      workoutRepositoryFactory: { try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")) }
    )
    await restoredModel.resolveAccountSetup(using: authentication)
    #expect(restoredModel.hasPendingSetup)
    await restoredModel.retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: false)
    #expect(restoredSessionService.uploads.isEmpty)

    await restoredModel.uploadCompletedSetup(using: authentication)

    #expect(setupService.savedCycleIDs == [localSetup.cycleID])
    #expect(restoredSetupService.savedCycleIDs == [localSetup.cycleID])
    #expect(!restoredModel.hasPendingSetup)
    #expect(restoredSessionService.uploads.map(\.sessionID) == [sessionID])
    #expect(try reopenedRepository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func pendingCycleCreationBlocksOnlyItsOwnSessionsUntilAcknowledgedAfterRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "onboarding.json")
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let store = FileOnboardingProgressStore(fileURL: storeURL)
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let cycleService = RetryableCycleCreationService()
    let uploads = CompletedSessionUploadSpy()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: StaticAccountSetupService(setup: setup),
      cycleService: cycleService, completedSessionUploadService: uploads,
      progressStore: store, workoutRepository: repository)
    await model.resolveAccountSetup(using: authentication)
    await model.refreshCycleKnowledge(using: authentication)
    let target = try #require(model.programs.first(where: { $0.id != setup.programID }))
    model.switchToProgram(target.id, using: authentication)
    let newCycleID = try #require(model.restoredCycleID)
    let newSetup = AccountSetup(preferredUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      programID: target.id, cycleID: newCycleID)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let dependent = try finishOneSession(repository: repository, model: model, setup: newSetup, startingAt: date)
    let independent = try finishOneSession(repository: repository, model: model, setup: setup,
      startingAt: date.addingTimeInterval(60))
    let originalBody = try #require(repository.pendingSessionUpload(sessionID: dependent, accountID: "preview-user")?.body)

    await model.retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: false)
    #expect(uploads.uploads.map(\.sessionID) == [independent])
    #expect(try repository.pendingSessionUpload(sessionID: dependent, accountID: "preview-user")?.body == originalBody)
    await model.uploadPendingCycles(using: authentication)
    #expect(uploads.uploads.map(\.sessionID) == [independent])

    let reopenedRepository = try WorkoutRepository(databaseURL: databaseURL)
    let restored = OnboardingModel(catalog: .bundled, setupService: StaticAccountSetupService(setup: setup),
      cycleService: cycleService, completedSessionUploadService: uploads,
      progressStore: FileOnboardingProgressStore(fileURL: storeURL), workoutRepository: reopenedRepository)
    await restored.resolveAccountSetup(using: authentication)
    #expect(restored.restoredCycleID == newCycleID)
    await restored.retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: false)
    #expect(uploads.uploads.map(\.sessionID) == [independent])
    cycleService.available = true
    await restored.uploadPendingCycles(using: authentication, at: Date.now.addingTimeInterval(60))
    #expect(cycleService.attempts.allSatisfy { $0.cycleID == newCycleID })
    #expect(uploads.uploads.map(\.sessionID) == [independent, dependent])
    #expect(uploads.uploads.last?.body == originalBody)
    #expect(try reopenedRepository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func removedCycleRejectionRetainsWorkoutAndAllowsOtherUploadsAfterReopening() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "onboarding.json")
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let store = FileOnboardingProgressStore(fileURL: storeURL)
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let removed = AccountCycle(cycleID: UUID(), programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    progress.cycles = ProgramCycleState(selectedProgramID: removed.programID, selectedCycleID: removed.cycleID,
      knownCycles: [removed], discoveryComplete: true, pendingCreations: [removed],
      pendingActivations: [removed.cycleID])
    try store.save(progress, accountID: "preview-user")
    let service = RemovedCycleCreationService()
    let uploads = CompletedSessionUploadSpy()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: StaticAccountSetupService(setup: setup),
      cycleService: service, completedSessionUploadService: uploads, progressStore: store, workoutRepository: repository)
    await model.resolveAccountSetup(using: auth)
    let removedSetup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: removed.programID, cycleID: removed.cycleID)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let dependent = try finishOneSession(repository: repository, model: model, setup: removedSetup, startingAt: date)
    let independent = try finishOneSession(repository: repository, model: model, setup: setup, startingAt: date.addingTimeInterval(60))
    let body = try #require(repository.pendingSessionUpload(sessionID: dependent, accountID: "preview-user")?.body)
    await model.uploadPendingCycles(using: auth)
    await model.retryPendingSessionUploads(using: auth, at: date, scheduleRetries: false)
    #expect(uploads.uploads.map(\.sessionID) == [independent])
    #expect(model.restoredCycleID == removed.cycleID)
    #expect(model.cycleConflictMessage != nil)
    let reopenedRepository = try WorkoutRepository(databaseURL: databaseURL)
    let reopened = OnboardingModel(catalog: .bundled, setupService: StaticAccountSetupService(setup: setup),
      cycleService: service, completedSessionUploadService: uploads,
      progressStore: FileOnboardingProgressStore(fileURL: storeURL), workoutRepository: reopenedRepository)
    await reopened.resolveAccountSetup(using: auth)
    await reopened.uploadPendingCycles(using: auth)
    await reopened.retryPendingSessionUploads(using: auth, at: date, scheduleRetries: false)
    #expect(service.attempts == 1)
    #expect(reopened.restoredCycleID == removed.cycleID)
    #expect(try reopenedRepository.pendingSessionUpload(sessionID: dependent, accountID: "preview-user")?.body == body)
    #expect(try reopenedRepository.pendingSessionUploads(accountID: "preview-google").isEmpty)
    #expect(reopened.cycleConflictMessage != nil)
  }

  @Test
  func establishedCycleConflictRetainsOnlyItsSessionsAndSurvivesRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let localSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body",
      cycleID: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    )
    let establishedSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: localSetup.programID,
      cycleID: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
    )
    var progress = OnboardingProgress(
      weightUnit: localSetup.preferredUnit, trainingDays: localSetup.trainingDays,
      selectedProgramID: localSetup.programID, nextStep: .overview
    )
    progress.completed = CompletedOnboarding(setup: localSetup, needsUpload: true)
    try store.save(progress, accountID: "preview-user")
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let setupService = SequencedAccountSetupService(
      lookupResult: nil, saveOutcomes: [.returnSetup(establishedSetup)]
    )
    let sessionService = CompletedSessionUploadSpy()
    let model = OnboardingModel(
      catalog: .bundled, setupService: setupService,
      completedSessionUploadService: sessionService,
      progressStore: store, workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let conflictingSessionID = try finishOneSession(
      repository: repository, model: model, setup: localSetup, startingAt: date
    )
    let independentSessionID = try finishOneSession(
      repository: repository, model: model, setup: establishedSetup, startingAt: date.addingTimeInterval(60)
    )
    let localProgram = try #require(model.program(id: localSetup.programID))
    let nextLocalOccurrence = try repository.nextOccurrence(
      accountID: "preview-user", cycleID: localSetup.cycleID,
      programID: localProgram.id, workoutIDs: localProgram.workouts.map(\.id)
    )
    model.startWorkout(
      programID: localProgram.id, workoutID: nextLocalOccurrence.workoutID, accountID: "preview-user"
    )
    let activeSession = try #require(model.activeWorkoutSession)
    let activeExercise = try #require(activeSession.exercises.first)
    #expect(model.saveWorkoutDraft(slotID: activeExercise.slotID, weightInput: "55", repsInput: "8"))
    #expect(model.completeWorkoutSet(slotID: activeExercise.slotID))

    await model.uploadCompletedSetup(using: authentication)

    #expect(sessionService.uploads.map(\.sessionID) == [independentSessionID])
    #expect(model.activeWorkoutSession?.id == activeSession.id)
    #expect(model.activeWorkoutSession?.cycleID == localSetup.cycleID)
    #expect(model.sessionUploadErrorPresented)
    #expect(model.sessionUploadErrorMessage.contains("different cycle"))
    #expect(model.restoredCycleID == establishedSetup.cycleID)
    let retained = try #require(repository.sessionUploadQueue(accountID: "preview-user").first)
    #expect(retained.upload.sessionID == conflictingSessionID)
    #expect(retained.permanentFailure == .setupCycleConflict)
    let body = try #require(JSONSerialization.jsonObject(with: retained.upload.body) as? [String: Any])
    #expect(body["cycle_id"] as? String == localSetup.cycleID.uuidString.lowercased())

    model.sessionUploadErrorPresented = false
    #expect(model.finishActiveWorkout(note: nil, using: authentication))
    #expect(model.activeWorkoutSession == nil)
    #expect(model.sessionUploadErrorPresented)
    let blockedActiveSession = try #require(
      repository.sessionUploadQueue(accountID: "preview-user")
        .first(where: { $0.upload.sessionID == activeSession.id })
    )
    #expect(blockedActiveSession.permanentFailure == .setupCycleConflict)

    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    #expect(try reopened.sessionUploadQueue(accountID: "preview-user").first?.permanentFailure == .setupCycleConflict)
    let restoredModel = OnboardingModel(
      catalog: .bundled, setupService: setupService,
      completedSessionUploadService: CompletedSessionUploadSpy(),
      progressStore: store, workoutRepository: reopened
    )
    await restoredModel.resolveAccountSetup(using: authentication)
    #expect(restoredModel.sessionUploadErrorPresented)
    await restoredModel.retryPendingSessionUploads(
      using: authentication, at: date.addingTimeInterval(300), scheduleRetries: false
    )
    #expect(try reopened.sessionUploadQueue(accountID: "preview-user")
      .contains(where: { $0.upload.sessionID == conflictingSessionID }))
  }

  @Test
  func signOutRetainsDependentSetupAndSessionsForTheOriginalAccount() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
    )
    var progress = OnboardingProgress(
      weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview
    )
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: true)
    try store.save(progress, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let setupService = SequencedAccountSetupService(
      lookupResult: nil, saveOutcomes: [.returnSetup(setup)]
    )
    let uploadService = CompletedSessionUploadSpy()
    let model = OnboardingModel(
      catalog: .bundled, setupService: setupService,
      completedSessionUploadService: uploadService,
      progressStore: store, workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let sessionID = try finishOneSession(
      repository: repository, model: model, setup: setup,
      startingAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let originalBody = try #require(
      repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body
    )

    // Sign out can be tapped while the account setup screen is still resolving.
    model.resetAccount()
    await model.signOut(using: authentication)

    #expect(model.pendingSessionSignOutPresented)
    #expect(model.pendingSessionSignOutMessage.contains("setup they depend on"))
    #expect(authentication.signedInUser?.id == "preview-user")
    await model.confirmPendingSessionSignOut(using: authentication)

    #expect(authentication.signedInUser == nil)
    #expect(try store.load(accountID: "preview-user")?.completed?.needsUpload == true)
    #expect(try repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body == originalBody)

    await authentication.signInWithGoogle()
    await model.resolveAccountSetup(using: authentication)
    await model.retryPendingSessionUploads(using: authentication, scheduleRetries: false)
    #expect(authentication.signedInUser?.id == "preview-google")
    #expect(uploadService.uploads.isEmpty)
    #expect(try repository.pendingSessionUploads(accountID: "preview-google").isEmpty)

    await authentication.signOut()
    await model.resolveAccountSetup(using: authentication)
    let returningOwner = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: returningOwner)
    #expect(model.hasPendingSetup)
    await model.uploadCompletedSetup(using: returningOwner)

    #expect(!model.hasPendingSetup)
    #expect(setupService.savedCycleIDs == [setup.cycleID])
    #expect(uploadService.uploads.map(\.sessionID) == [sessionID])
    #expect(uploadService.uploads.first?.body == originalBody)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func pendingSessionConfirmationCannotSignOutAnAccountThatReplacedTheOwner() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!
    )
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: CompletedSessionUploadSpy(),
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    _ = try finishOneSession(
      repository: repository, model: model, setup: setup,
      startingAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    await model.signOut(using: authentication)
    #expect(model.pendingSessionSignOutPresented)
    await authentication.signOut()
    await authentication.signInWithGoogle()
    #expect(authentication.signedInUser?.id == "preview-google")

    await model.confirmPendingSessionSignOut(using: authentication)

    #expect(authentication.signedInUser?.id == "preview-google")
    #expect(!model.pendingSessionSignOutPresented)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").count == 1)
  }

  @Test
  func pendingSessionSignOutDiscardsSetupThatIsNotRequiredByQueuedWork() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let pendingSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "abababab-abab-4bab-8bab-abababababab")!
    )
    var progress = OnboardingProgress(
      weightUnit: pendingSetup.preferredUnit, trainingDays: pendingSetup.trainingDays,
      selectedProgramID: pendingSetup.programID, nextStep: .overview
    )
    progress.completed = CompletedOnboarding(setup: pendingSetup, needsUpload: true)
    try store.save(progress, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: SequencedAccountSetupService(lookupResult: nil, saveOutcomes: []),
      progressStore: store,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let unrelatedCycle = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd")!
    )
    let sessionID = try finishOneSession(
      repository: repository, model: model, setup: unrelatedCycle,
      startingAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    await model.signOut(using: authentication)

    #expect(model.pendingSessionSignOutPresented)
    #expect(model.pendingSessionSignOutMessage.contains("unsaved setup is not needed"))
    await model.confirmPendingSessionSignOut(using: authentication)

    #expect(authentication.signedInUser == nil)
    #expect(try store.load(accountID: "preview-user") == nil)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").map(\.sessionID) == [sessionID])
  }

  @Test
  func failedSignOutReconcilesAnInFlightSessionWithTheSameRequest() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
    )
    var progress = OnboardingProgress(
      weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
      selectedProgramID: setup.programID, nextStep: .overview
    )
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.save(progress, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let uploadService = CompletedSessionUploadSpy(
      outcomes: [.commitThenLoseResponse, .success], suspendNextUpload: true
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: uploadService,
      progressStore: store, workoutRepository: repository
    )
    let authentication = AuthenticationModel(
      service: PreviewAuthenticationService(startsSignedIn: true, signOutFails: true)
    )
    await model.resolveAccountSetup(using: authentication)
    let sessionID = try finishOneSession(
      repository: repository, model: model, setup: setup,
      startingAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let originalBody = try #require(
      repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body
    )
    let firstDrain = Task {
      await model.retryPendingSessionUploads(using: authentication, scheduleRetries: false)
    }
    for _ in 0..<1_000 where !uploadService.isUploadSuspended { await Task.yield() }
    #expect(uploadService.isUploadSuspended)

    await model.signOut(using: authentication)
    #expect(model.pendingSessionSignOutPresented)
    await model.confirmPendingSessionSignOut(using: authentication)

    #expect(model.signOutErrorPresented)
    #expect(model.signOutErrorMessage.contains("workouts are still saved on this device"))
    #expect(authentication.signedInUser?.id == "preview-user")
    let restoredProgress = try #require(store.load(accountID: "preview-user")?.completed)
    #expect(restoredProgress.setup.cycleID == setup.cycleID)
    #expect(try repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body == originalBody)

    uploadService.resumeSuspendedUpload()
    await firstDrain.value
    for _ in 0..<1_000 where uploadService.uploads.count < 2 { await Task.yield() }

    #expect(uploadService.uploads.map(\.sessionID) == [sessionID, sessionID])
    #expect(uploadService.uploads.allSatisfy { $0.body == originalBody })
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func httpFailuresSeparateAuthenticationPermanentAndTransientResponses() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let unauthorized = CompletedSessionUploadError.httpFailure(status: 401, retryAfter: nil, at: now)
    let forbidden = CompletedSessionUploadError.httpFailure(status: 403, retryAfter: nil, at: now)
    let conflict = CompletedSessionUploadError.httpFailure(status: 409, retryAfter: nil, at: now)
    let invalid = CompletedSessionUploadError.httpFailure(status: 422, retryAfter: nil, at: now)
    #expect(unauthorized?.errorDescription == CompletedSessionUploadError.authenticationRequired.errorDescription)
    #expect(forbidden?.errorDescription == CompletedSessionUploadError.forbidden.errorDescription)
    #expect(conflict?.errorDescription == CompletedSessionUploadError.conflict.errorDescription)
    #expect(invalid?.errorDescription == CompletedSessionUploadError.invalidSession.errorDescription)
    #expect(CompletedSessionUploadError.httpFailure(status: 404, retryAfter: nil, at: now) == nil)

    let rateLimited = CompletedSessionUploadError.httpFailure(
      status: 429, retryAfter: "120", at: now
    )
    if case let .temporary(retryAfter)? = rateLimited {
      #expect(retryAfter == now.addingTimeInterval(120))
    } else {
      Issue.record("A rate limit response must be retryable")
    }
    let unavailable = CompletedSessionUploadError.httpFailure(status: 503, retryAfter: nil, at: now)
    if case let .temporary(retryAfter)? = unavailable {
      #expect(retryAfter == nil)
    } else {
      Issue.record("A server failure must be retryable")
    }
  }

  @Test
  func drainContinuesAfterPermanentRejectionInOldestFirstOrder() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let service = CompletedSessionUploadSpy(outcomes: [.conflict, .success, .success, .success])
    let cycleID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionIDs = try finishSessions(repository: repository, model: model, setup: setup, startingAt: start, count: 4)

    await model.retryPendingSessionUploads(
      using: authentication, at: start.addingTimeInterval(300), scheduleRetries: false
    )

    #expect(service.uploads.map(\.sessionID) == sessionIDs)
    let uploadedWeeks = try service.uploads.map { upload -> Int in
      let payload = try #require(JSONSerialization.jsonObject(with: upload.body) as? [String: Any])
      return try #require(payload["week_number"] as? Int)
    }
    #expect(uploadedWeeks == [1, 1, 1, 2])
    let pending = try repository.sessionUploadQueue(accountID: "preview-user")
    #expect(pending.map(\.upload.sessionID) == [sessionIDs[0]])
    #expect(pending.first?.permanentFailure == .conflict)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").map(\.sessionID) == [sessionIDs[0]])
    #expect(model.workoutErrorPresented == false)
  }

  @Test
  func transientFailureLeavesASeparateLaterSessionFreeToUpload() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let service = CompletedSessionUploadSpy(outcomes: [.temporary(now.addingTimeInterval(60)), .success])
    let cycleID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let sessionIDs = try finishSessions(repository: repository, model: model, setup: setup, startingAt: now, count: 2)

    await model.retryPendingSessionUploads(using: authentication, at: now, scheduleRetries: false)

    #expect(service.uploads.map(\.sessionID) == sessionIDs)
    let retained = try repository.sessionUploadQueue(accountID: "preview-user")
    #expect(retained.map(\.upload.sessionID) == [sessionIDs[0]])
    #expect(retained.first?.attemptCount == 1)
    #expect(retained.first?.retryAfter == now.addingTimeInterval(60))
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").map(\.sessionID) == [sessionIDs[0]])
  }

  @Test
  func retryWaitsForPersistedBackoffAndReusesBodyAfterRepositoryReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let firstService = CompletedSessionUploadSpy(outcomes: [.commitThenLoseResponse])
    let cycleID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let firstModel = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: firstService,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await firstModel.resolveAccountSetup(using: authentication)
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionID = try finishOneSession(repository: repository, model: firstModel, setup: setup, startingAt: start)

    await firstModel.retryPendingSessionUploads(using: authentication, at: start, scheduleRetries: false)
    let originalBody = try #require(firstService.uploads.first?.body)
    let reopened = try WorkoutRepository(databaseURL: databaseURL)
    let persisted = try #require(reopened.sessionUploadQueue(accountID: "preview-user").first)
    #expect(persisted.upload.body == originalBody)
    #expect(persisted.attemptCount == 1)
    #expect(persisted.retryAfter == start.addingTimeInterval(15))

    let restoredModel = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: firstService,
      workoutRepository: reopened
    )
    await restoredModel.resolveAccountSetup(using: authentication)
    await restoredModel.retryPendingSessionUploads(
      using: authentication, at: start.addingTimeInterval(14), scheduleRetries: false
    )
    #expect(firstService.uploads.count == 1)

    await restoredModel.retryPendingSessionUploads(
      using: authentication, at: start.addingTimeInterval(15), scheduleRetries: false
    )
    #expect(firstService.uploads.map(\.sessionID) == [sessionID, sessionID])
    #expect(firstService.uploads.allSatisfy { $0.body == originalBody })
    #expect(try reopened.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func authenticationRequiredDefersUntilAuthenticatedRestoration() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy(outcomes: [.authenticationRequired, .success])
    let cycleID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try finishOneSession(repository: repository, model: model, setup: setup, startingAt: now)

    await model.retryPendingSessionUploads(using: authentication, at: now, scheduleRetries: false)
    #expect(try repository.sessionUploadQueue(accountID: "preview-user").first?.isAuthenticationDeferred == true)
    await model.retryPendingSessionUploads(
      using: authentication, at: now.addingTimeInterval(60), scheduleRetries: false
    )
    #expect(service.uploads.count == 1)

    await model.resumeDeferredSessionUploads(
      using: authentication, at: now.addingTimeInterval(60), scheduleRetries: false
    )
    #expect(service.uploads.count == 2)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func simultaneousDrainTriggersDoNotUploadTheSameRecordTwice() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy(suspendNextUpload: true)
    let cycleID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try finishOneSession(repository: repository, model: model, setup: setup, startingAt: now)

    let firstDrain = Task {
      await model.retryPendingSessionUploads(using: authentication, at: now, scheduleRetries: false)
    }
    for _ in 0..<1_000 where !service.isUploadSuspended { await Task.yield() }
    #expect(service.isUploadSuspended)
    await model.retryPendingSessionUploads(using: authentication, at: now, scheduleRetries: false)
    service.resumeSuspendedUpload()
    await firstDrain.value
    for _ in 0..<100 { await Task.yield() }

    #expect(service.uploads.count == 1)
    #expect(service.maximumConcurrentUploads == 1)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func lateUploadResponseAfterAccountChangeCannotAcknowledgeOtherAccountWork() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy(suspendNextUpload: true)
    let cycleID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionID = try finishOneSession(repository: repository, model: model, setup: setup, startingAt: now)
    let originalBody = try #require(repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body)

    let firstDrain = Task {
      await model.retryPendingSessionUploads(using: authentication, at: now, scheduleRetries: false)
    }
    for _ in 0..<1_000 where !service.isUploadSuspended { await Task.yield() }
    #expect(service.isUploadSuspended)
    await authentication.signOut()
    await model.resolveAccountSetup(using: authentication)
    await authentication.signInWithGoogle()
    await model.resolveAccountSetup(using: authentication)
    service.resumeSuspendedUpload()
    await firstDrain.value

    #expect(authentication.signedInUser?.id == "preview-google")
    #expect(try repository.pendingSessionUpload(sessionID: sessionID, accountID: "preview-user")?.body == originalBody)
    #expect(try repository.pendingSessionUploads(accountID: "preview-google").isEmpty)
  }

  @Test
  func appLifetimeWakeupsUseTheEarliestPersistedRetryDate() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy()
    let cycleID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    var scheduledDelays: [TimeInterval] = []
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      waitForSessionUploadRetry: { scheduledDelays.append($0) },
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionIDs = try finishSessions(repository: repository, model: model, setup: setup, startingAt: now, count: 2)
    try repository.recordTransientUploadFailure(
      sessionID: sessionIDs[0], accountID: "preview-user", retryAt: now.addingTimeInterval(15)
    )
    try repository.recordTransientUploadFailure(
      sessionID: sessionIDs[1], accountID: "preview-user", retryAt: now.addingTimeInterval(60)
    )

    await model.retryPendingSessionUploads(using: authentication, at: now)
    for _ in 0..<1_000 where service.uploads.count < 2 { await Task.yield() }

    #expect(scheduledDelays == [15, 45])
    #expect(service.uploads.map(\.sessionID) == sessionIDs)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func accountResetCancelsScheduledUploadRetry() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy()
    let retryWait = SessionUploadRetryWaitSpy()
    let cycleID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      waitForSessionUploadRetry: { try await retryWait.wait($0) },
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let sessionID = try finishOneSession(repository: repository, model: model, setup: setup, startingAt: now)
    try repository.recordTransientUploadFailure(
      sessionID: sessionID, accountID: "preview-user", retryAt: now.addingTimeInterval(60)
    )

    await model.retryPendingSessionUploads(using: authentication, at: now)
    for _ in 0..<1_000 where retryWait.delays.isEmpty { await Task.yield() }
    #expect(retryWait.delays == [60])
    model.resetAccount()
    for _ in 0..<1_000 where !retryWait.wasCancelled { await Task.yield() }
    #expect(retryWait.wasCancelled)
  }

  @Test(arguments: ["direct", "factory", "recoveredFactory"])
  func finishingSendsTheDurablePayloadAndAcknowledgesItLocally(repositoryPath: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let service = CompletedSessionUploadSpy()
    let cycleID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    var shouldFailOpening = repositoryPath == "recoveredFactory"
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repositoryPath == "direct" ? repository : nil,
      workoutRepositoryFactory: {
        if shouldFailOpening {
          shouldFailOpening = false
          throw CocoaError(.fileReadNoPermission)
        }
        return try WorkoutRepository(databaseURL: databaseURL)
      }
    )
    if repositoryPath == "recoveredFactory" {
      #expect(model.workoutStorageOpenFailed)
      model.retryWorkoutStorage()
      #expect(!model.workoutStorageOpenFailed)
    }
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "72.5", repsInput: "10"))
    #expect(model.completeWorkoutSet(slotID: slot.id))
    let sessionID = try #require(model.activeWorkoutSession?.id)

    #expect(model.finishActiveWorkout(note: "Felt strong", using: authentication))
    for _ in 0..<100 where service.uploads.isEmpty { await Task.yield() }
    for _ in 0..<100 where !(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty) {
      await Task.yield()
    }

    let uploaded = try #require(service.uploads.first)
    #expect(uploaded.sessionID == sessionID)
    #expect(uploaded.accountID == "preview-user")
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
    #expect(model.workoutErrorPresented == false)
  }

  @Test
  func failedImmediateUploadKeepsFinishedWorkPendingWithoutRoutineUi() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy(fails: true)
    let cycleID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    let setup = AccountSetup(
      preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "0", repsInput: "8"))
    #expect(model.completeWorkoutSet(slotID: slot.id))
    let sessionID = try #require(model.activeWorkoutSession?.id)

    #expect(model.finishActiveWorkout(note: nil, using: authentication))
    for _ in 0..<100 where service.uploads.isEmpty { await Task.yield() }

    #expect(service.uploads.first?.sessionID == sessionID)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").map(\.sessionID) == [sessionID])
    #expect(model.activeWorkoutSession == nil)
    #expect(model.workoutErrorPresented == false)
  }

  @Test
  func draftsAndDiscardedAttemptsNeverReachTheUploadService() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy()
    let cycleID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "70", repsInput: "8"))
    #expect(!model.finishActiveWorkout(note: nil, using: authentication))
    #expect(service.uploads.isEmpty)
    #expect(model.activeWorkoutSession != nil)

    model.discardActiveWorkout(accountID: "preview-user")
    #expect(model.activeWorkoutSession == nil)
    #expect(service.uploads.isEmpty)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }
}

@MainActor
private func finishOneSession(
  repository: WorkoutRepository,
  model: OnboardingModel,
  setup: AccountSetup,
  startingAt date: Date
) throws -> UUID {
  try finishSessions(repository: repository, model: model, setup: setup, startingAt: date, count: 1)[0]
}

@MainActor
private func finishSessions(
  repository: WorkoutRepository,
  model: OnboardingModel,
  setup: AccountSetup,
  startingAt date: Date,
  count: Int
) throws -> [UUID] {
  guard let program = model.program(id: setup.programID), !program.workouts.isEmpty else {
    throw WorkoutRepositoryError.invalidCompletedSession
  }
  return try (0..<count).map { index in
    let workoutIndex = index % program.workouts.count
    let workout = program.workouts[workoutIndex]
    let week = index / program.workouts.count + 1
    let day = workoutIndex + 1
    guard let slot = workout.exercises.first else { throw WorkoutRepositoryError.invalidCompletedSession }
    let sessionDate = date.addingTimeInterval(Double(index) * 60)
    let session = WorkoutSession(
      accountID: "preview-user", cycleID: setup.cycleID, program: program, workout: workout,
      week: week, day: day, weightUnit: setup.preferredUnit, startedAt: sessionDate
    )
    _ = try repository.start(session)
    _ = try repository.saveDraft(
      sessionID: session.id, accountID: session.accountID,
      slotID: slot.id, weightInput: "50", repsInput: "8"
    )
    _ = try repository.completeSet(
      sessionID: session.id, accountID: session.accountID, slotID: slot.id,
      at: sessionDate.addingTimeInterval(10)
    )
    _ = try repository.finish(
      sessionID: session.id, accountID: session.accountID, note: nil,
      at: sessionDate.addingTimeInterval(20)
    )
    return session.id
  }
}

@MainActor
private final class SessionUploadRetryWaitSpy {
  private(set) var delays: [TimeInterval] = []
  private(set) var wasCancelled = false

  func wait(_ delay: TimeInterval) async throws {
    delays.append(delay)
    do {
      try await Task.sleep(for: .seconds(3_600))
    } catch {
      wasCancelled = true
      throw error
    }
  }
}

@MainActor
private final class CompletedSessionUploadSpy: CompletedSessionUploadService {
  enum Outcome {
    case success
    case offline
    case commitThenLoseResponse
    case authenticationRequired
    case forbidden
    case conflict
    case invalidSession
    case temporary(Date?)
  }

  private var outcomes: [Outcome]
  private var suspendNextUpload: Bool
  private var suspendedUpload: CheckedContinuation<Void, Never>?
  private var activeUploads = 0
  private var committedBodies: [UUID: Data] = [:]
  private(set) var maximumConcurrentUploads = 0
  private(set) var isUploadSuspended = false
  private(set) var uploads: [PendingSessionUpload] = []

  init(fails: Bool = false, outcomes: [Outcome] = [], suspendNextUpload: Bool = false) {
    self.outcomes = fails ? [.offline] : outcomes
    self.suspendNextUpload = suspendNextUpload
  }

  func resumeSuspendedUpload() {
    suspendedUpload?.resume()
    suspendedUpload = nil
  }

  func upload(_ pending: PendingSessionUpload, for user: AuthenticatedUser) async throws {
    #expect(pending.accountID == user.id)
    uploads.append(pending)
    if let committedBody = committedBodies[pending.sessionID] {
      #expect(committedBody == pending.body)
    }
    activeUploads += 1
    maximumConcurrentUploads = max(maximumConcurrentUploads, activeUploads)
    if suspendNextUpload {
      suspendNextUpload = false
      isUploadSuspended = true
      await withCheckedContinuation { suspendedUpload = $0 }
      isUploadSuspended = false
    }
    activeUploads -= 1
    let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
    switch outcome {
    case .success:
      committedBodies[pending.sessionID] = pending.body
      return
    case .offline: throw URLError(.notConnectedToInternet)
    case .commitThenLoseResponse:
      committedBodies[pending.sessionID] = pending.body
      throw URLError(.networkConnectionLost)
    case .authenticationRequired: throw CompletedSessionUploadError.authenticationRequired
    case .forbidden: throw CompletedSessionUploadError.forbidden
    case .conflict: throw CompletedSessionUploadError.conflict
    case .invalidSession: throw CompletedSessionUploadError.invalidSession
    case .temporary(let retryAfter): throw CompletedSessionUploadError.temporary(retryAfter: retryAfter)
    }
  }
}

@MainActor
private struct StaticAccountSetupService: AccountSetupService {
  let setup: AccountSetup

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    self.setup
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    setup
  }
}

@MainActor
private struct StaticAccountProgressService: AccountProgressService {
  let progress: AccountProgress?

  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? {
    progress
  }
}

@MainActor
private final class SequencedAccountSetupService: AccountSetupService {
  enum SaveOutcome {
    case lostAcknowledgment
    case returnSetup(AccountSetup)
  }

  let lookupResult: AccountSetup?
  private var saveOutcomes: [SaveOutcome]
  private(set) var savedCycleIDs: [UUID] = []

  init(lookupResult: AccountSetup?, saveOutcomes: [SaveOutcome]) {
    self.lookupResult = lookupResult
    self.saveOutcomes = saveOutcomes
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    lookupResult
  }

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    savedCycleIDs.append(setup.cycleID)
    guard !saveOutcomes.isEmpty else { return setup }
    switch saveOutcomes.removeFirst() {
    case .lostAcknowledgment:
      throw AccountSetupError.unavailable
    case .returnSetup(let established):
      return established
    }
  }
}

@MainActor
private final class RetryableCycleCreationService: AccountCycleService {
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
  var available = false
  private(set) var attempts: [AccountCycle] = []

  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }

  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    attempts.append(cycle)
    if !available { throw AccountCycleError.unavailable }
  }
}

@MainActor
private final class RemovedCycleCreationService: AccountCycleService {
  var attempts = 0
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    attempts += 1
    throw AccountCycleError.programUnavailable
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}
