import Foundation
import Testing
@testable import OneSet

extension CompletedSessionUploadTests {
  @Test
  func setupAcknowledgmentWithLostResponseReusesCycleBeforeDependentSessionUpload() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let localSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body",
      cycleID: try #require(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
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
      cycleService: CycleServiceWithSetup(cycleService, setup: setup), completedSessionUploadService: uploads,
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
      cycleService: CycleServiceWithSetup(cycleService, setup: setup), completedSessionUploadService: uploads,
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
      cycleID: try #require(UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"))
    )
    let establishedSetup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: localSetup.programID,
      cycleID: try #require(UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"))
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
    model.scheduleWorkoutEdit(sessionID: activeSession.id, slotID: activeExercise.slotID,
                              input: .init(weight: "55", reps: "8"))
    #expect(await model.flushWorkoutEdits(sessionID: activeSession.id))
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
      cycleID: try #require(UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd"))
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
      cycleID: try #require(UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff"))
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
      cycleID: try #require(UUID(uuidString: "abababab-abab-4bab-8bab-abababababab"))
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
      cycleID: try #require(UUID(uuidString: "cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd"))
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
      cycleID: try #require(UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"))
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
}
