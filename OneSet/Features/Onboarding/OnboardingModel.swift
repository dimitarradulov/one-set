import Foundation
import Observation

@MainActor
@Observable
final class OnboardingModel {
  var path: [OnboardingRoute]
  var programPath: [OnboardingRoute]
  var settingsPath: [SettingsDestination]
  var selectedMainTab: MainTab
  var weightUnit: WeightUnit = .kilograms
  var trainingDays = 3
  private(set) var selectedProgramID: TrainingProgram.ID?

  enum SetupResolution {
    case idle
    case loading
    case failed(String)
  }

  private(set) var setupResolution: SetupResolution = .idle
  private(set) var restoredCycleID: UUID?
  var discardSetupPresented = false
  var pendingSessionSignOutPresented = false
  private(set) var pendingSessionSignOutMessage = ""
  private var pendingSessionSignOutDiscardsSetup = false
  private var pendingSessionSignOutAccountID: String?
  private(set) var uploadMessage: String?
  private(set) var programSelectionMessage: String?
  private var uploadingGeneration: Int?
  var hasCompletedSetup: Bool { savedProgress?.completed != nil || restoredCycleID != nil }
  var hasPendingSetup: Bool { savedProgress?.completed?.needsUpload == true }
  var signOutErrorPresented = false
  private(set) var signOutErrorMessage = ""
  var progressErrorPresented = false
  private(set) var progressErrorMessage = ""
  private let progressStore: (any OnboardingProgressStore)?
  private var savedProgress: OnboardingProgress?
  private var isSigningOut = false
  private var didResolveInitialAccount = false
  private let setupService: (any AccountSetupService)?
  private let previousPerformanceService: (any PreviousPerformanceService)?
  private let progressService: (any AccountProgressService)?
  private var lookupGeneration = 0
  private var resolvedAccountID: String?
  private let catalog: ProgramCatalog
  private var workoutRepository: WorkoutRepository?
  private var completedSessionUploadCoordinator: CompletedSessionUploadCoordinator?
  private let completedSessionUploadService: (any CompletedSessionUploadService)?
  private let sessionHistoryService: (any SessionHistoryService)?
  private let waitForSessionUploadRetry: @MainActor (TimeInterval) async throws -> Void
  private let workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)?
  private(set) var activeWorkoutSession: WorkoutSession?
  var workoutErrorPresented = false
  private(set) var workoutErrorMessage = ""
  var sessionUploadErrorPresented = false
  private(set) var sessionUploadErrorMessage = ""
  private(set) var workoutStorageOpenFailed = false
  private(set) var previousPerformanceUnavailable = false

  init(
    catalog: ProgramCatalog,
    setupService: (any AccountSetupService)? = nil,
    previousPerformanceService: (any PreviousPerformanceService)? = nil,
    progressService: (any AccountProgressService)? = nil,
    completedSessionUploadService: (any CompletedSessionUploadService)? = nil,
    sessionHistoryService: (any SessionHistoryService)? = nil,
    waitForSessionUploadRetry: @escaping @MainActor (TimeInterval) async throws -> Void = { delay in
      try await Task.sleep(for: .seconds(delay))
    },
    progressStore: (any OnboardingProgressStore)? = nil,
    workoutRepository: WorkoutRepository? = nil,
    workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil,
    initialProgramPath: [OnboardingRoute] = [],
    initialSettingsPath: [SettingsDestination] = [],
    initialMainTab: MainTab = .program
  ) {
    self.catalog = catalog
    self.setupService = setupService
    self.previousPerformanceService = previousPerformanceService
    self.progressService = progressService
    self.progressStore = progressStore
    self.workoutRepositoryFactory = workoutRepositoryFactory
    self.completedSessionUploadService = completedSessionUploadService
    self.sessionHistoryService = sessionHistoryService
    self.waitForSessionUploadRetry = waitForSessionUploadRetry
    do {
      self.workoutRepository = try workoutRepository ?? workoutRepositoryFactory?()
    } catch {
      self.workoutRepository = nil
      workoutStorageOpenFailed = true
      workoutErrorMessage = "Workout storage couldn’t be opened. Your saved workouts are still on this device. Try opening storage again.\n\(error.localizedDescription)"
      workoutErrorPresented = true
    }
    path = initialPath
    selectedProgramID = initialSelectedProgramID
    programPath = initialProgramPath
    settingsPath = initialSettingsPath
    selectedMainTab = initialMainTab
    configureCompletedSessionUploads()
  }

  private func configureCompletedSessionUploads() {
    completedSessionUploadCoordinator?.cancelPendingWork()
    completedSessionUploadCoordinator = nil
    if let repository = workoutRepository, let completedSessionUploadService {
      completedSessionUploadCoordinator = CompletedSessionUploadCoordinator(
        repository: repository,
        service: completedSessionUploadService,
        waitForRetry: waitForSessionUploadRetry
      )
    }
  }

  func resolveAccountSetup(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser else {
      if resolvedAccountID != nil || !isSetupIdle { resetAccount() }
      return
    }
    guard !isSigningOut, resolvedAccountID != user.id, let setupService else { return }
    resetAccount(preservingNavigation: !didResolveInitialAccount)
    didResolveInitialAccount = true
    lookupGeneration += 1
    let generation = lookupGeneration
    setupResolution = .loading
    do {
      await catalog.refresh()
      savedProgress = try progressStore?.load(accountID: user.id)
      if let savedProgress { try validate(savedProgress) }
      let setup = try await setupService.lookup(for: user)
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if let setup {
        if let pending = savedProgress?.completed, pending.needsUpload,
           pending.setup.cycleID != setup.cycleID {
          _ = try workoutRepository?.blockSessionUploadsForSetupCycle(
            accountID: user.id, cycleID: pending.setup.cycleID, establishedCycleID: setup.cycleID
          )
        }
        try storeCompleted(setup, needsUpload: false, accountID: user.id)
        apply(setup)
        if let progressService {
          do {
            let summary = try await progressService.lookup(for: user)
            guard !Task.isCancelled, generation == lookupGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            guard let summary,
                  summary.cycleID == setup.cycleID, summary.programID == setup.programID else {
              throw AccountSetupError.unavailable
            }
            try workoutRepository?.restoreProgress(summary, accountID: user.id)
          } catch {
            guard !Task.isCancelled, generation == lookupGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            guard try workoutRepository?.hasRestorableProgress(accountID: user.id, cycleID: setup.cycleID) == true else {
              setupResolution = .failed("Your training progress couldn’t be restored. Retry to continue.")
              return
            }
          }
        }
      } else if let savedProgress {
        restore(savedProgress)
      } else {
        let progress = OnboardingProgress(
          weightUnit: .kilograms, trainingDays: 3, selectedProgramID: nil, nextStep: .preferences
        )
        try progressStore?.save(progress, accountID: user.id)
        savedProgress = progress
        weightUnit = .kilograms
        trainingDays = 3
        selectedProgramID = nil
        restoredCycleID = nil
        path = [.preferences]
      }
      resolvedAccountID = user.id
      activeWorkoutSession = try workoutRepository?.activeSession(accountID: user.id)
      if let activeWorkoutSession {
        selectedMainTab = .program
        programPath = [.workoutRecording(activeWorkoutSession.id)]
      }
      presentSessionUploadErrorIfNeeded(accountID: user.id)
      setupResolution = .idle
      await refreshPreviousPerformances(for: user, generation: generation, authentication: authentication)
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if let savedProgress, (try? validate(savedProgress)) != nil,
         !(error is CocoaError), !(error is DecodingError),
         (error as? AccountSetupError) != .invalidSetup {
        restore(savedProgress)
        resolvedAccountID = user.id
        setupResolution = .idle
        await refreshPreviousPerformances(for: user, generation: generation, authentication: authentication)
      } else {
        setupResolution = .failed(error.localizedDescription)
      }
    }
  }

  private var isSetupIdle: Bool {
    if case .idle = setupResolution { return true }
    return false
  }

  func signOut(
    using authentication: AuthenticationModel,
    discardPending: Bool = false,
    retainingPendingSessions: Bool = false
  ) async {
    guard !isSigningOut, let accountID = authentication.signedInUser?.id else { return }
    if activeWorkoutSession != nil {
      signOutErrorMessage = "Finish or discard your current workout first."
      signOutErrorPresented = true
      return
    }

    let progress: OnboardingProgress?
    do {
      if let progressStore {
        progress = try progressStore.load(accountID: accountID)
      } else {
        progress = savedProgress
      }
    } catch {
      signOutErrorMessage = "Your workouts are still saved on this device, but OneSet couldn’t check their upload status. Please try again."
      signOutErrorPresented = true
      return
    }
    let hasPendingSessions: Bool
    do {
      hasPendingSessions = try workoutRepository?.hasPendingSessionUploads(accountID: accountID) ?? false
    } catch {
      signOutErrorMessage = "Your workouts are still saved on this device, but OneSet couldn’t check their upload status. Please try again."
      signOutErrorPresented = true
      return
    }
    let hasPendingSetupForAccount = progress?.completed?.needsUpload == true
    if hasPendingSessions && !retainingPendingSessions {
      presentPendingSessionSignOut(for: accountID, progress: progress)
      return
    }
    if hasPendingSetupForAccount && !discardPending && !retainingPendingSessions {
      discardSetupPresented = true
      return
    }

    isSigningOut = true
    var resumeUploadsAfterFailure = false
    defer {
      isSigningOut = false
      if resumeUploadsAfterFailure {
        Task { @MainActor [weak self] in
          guard let self,
                authentication.signedInUser?.id == accountID,
                self.resolvedAccountID == accountID else { return }
          await self.uploadCompletedSetup(using: authentication)
          await self.retryPendingSessionUploads(using: authentication)
        }
      }
    }
    lookupGeneration += 1
    let previousResolution = setupResolution
    let progressForFailure: OnboardingProgress? = progress
    do {
      let shouldRemoveProgress = progress != nil && (!hasPendingSetupForAccount || discardPending)
      if shouldRemoveProgress { try progressStore?.remove(accountID: accountID) }
      await authentication.signOut()
      if authentication.signedInUser == nil {
        resetAccount()
      } else if authentication.signedInUser?.id == accountID {
        if shouldRemoveProgress, let progress { try progressStore?.save(progress, accountID: accountID) }
        setupResolution = previousResolution
        if case .loading = previousResolution {
          await resolveAfterFailedSignOut(using: authentication)
        }
        signOutErrorMessage = signOutFailureMessage(
          authentication.errorMessage ?? "Please try again.", retainingPendingSessions: hasPendingSessions
        )
        signOutErrorPresented = true
        resumeUploadsAfterFailure = true
      }
    } catch {
      if let progressForFailure { try? progressStore?.save(progressForFailure, accountID: accountID) }
      if case .loading = previousResolution {
        await resolveAfterFailedSignOut(using: authentication)
      }
      signOutErrorMessage = signOutFailureMessage(
        error.localizedDescription, retainingPendingSessions: hasPendingSessions
      )
      signOutErrorPresented = true
      resumeUploadsAfterFailure = true
    }
  }

  func confirmPendingSessionSignOut(using authentication: AuthenticationModel) async {
    guard let accountID = pendingSessionSignOutAccountID,
          authentication.signedInUser?.id == accountID else {
      pendingSessionSignOutPresented = false
      pendingSessionSignOutMessage = ""
      pendingSessionSignOutDiscardsSetup = false
      pendingSessionSignOutAccountID = nil
      return
    }
    let discardSetup = pendingSessionSignOutDiscardsSetup
    pendingSessionSignOutPresented = false
    pendingSessionSignOutMessage = ""
    pendingSessionSignOutAccountID = nil
    await signOut(using: authentication, discardPending: discardSetup, retainingPendingSessions: true)
  }

  private func presentPendingSessionSignOut(for accountID: String, progress: OnboardingProgress?) {
    let pendingSetup = progress?.completed
    let requiredCycleID = pendingSetup?.setup.cycleID
    var setupIsRequired = false
    if pendingSetup?.needsUpload == true, let requiredCycleID {
      do {
        setupIsRequired = try workoutRepository?.hasPendingSessionUploads(
          accountID: accountID, cycleID: requiredCycleID
        ) ?? true
      } catch {
        setupIsRequired = true
      }
    }
    pendingSessionSignOutDiscardsSetup = pendingSetup?.needsUpload == true && !setupIsRequired
    pendingSessionSignOutAccountID = accountID
    if setupIsRequired {
      pendingSessionSignOutMessage = "Your completed workouts and the account setup they depend on will stay on this device. Sign in again with this account to continue uploading them."
    } else if pendingSessionSignOutDiscardsSetup {
      pendingSessionSignOutMessage = "Your completed workouts will stay on this device. Sign in again with this account to continue uploading them. The unsaved setup is not needed for these workouts and will be discarded."
    } else {
      pendingSessionSignOutMessage = "Your completed workouts will stay on this device. Sign in again with this account to continue uploading them."
    }
    pendingSessionSignOutPresented = true
  }

  private func signOutFailureMessage(_ message: String, retainingPendingSessions: Bool) -> String {
    guard retainingPendingSessions else { return message }
    return "Your workouts are still saved on this device. Sign out didn’t finish. Please try again."
  }

  private func resolveAfterFailedSignOut(using authentication: AuthenticationModel) async {
    isSigningOut = false
    await resolveAccountSetup(using: authentication)
    isSigningOut = true
  }

  func resetAccount() {
    resetAccount(preservingNavigation: false)
  }

  private func resetAccount(preservingNavigation: Bool) {
    lookupGeneration += 1
    resolvedAccountID = nil
    previousPerformanceUnavailable = false
    setupResolution = .idle
    restoredCycleID = nil
    savedProgress = nil
    uploadingGeneration = nil
    completedSessionUploadCoordinator?.cancelPendingWork()
    uploadMessage = nil
    programSelectionMessage = nil
    discardSetupPresented = false
    pendingSessionSignOutPresented = false
    pendingSessionSignOutMessage = ""
    pendingSessionSignOutDiscardsSetup = false
    pendingSessionSignOutAccountID = nil
    progressErrorPresented = false
    sessionUploadErrorPresented = false
    sessionUploadErrorMessage = ""
    signOutErrorPresented = false
    weightUnit = .kilograms
    trainingDays = 3
    selectedProgramID = nil
    if !preservingNavigation {
      path = []
      programPath = []
      settingsPath = []
      selectedMainTab = .program
    }
  }

  var programs: [TrainingProgram] {
    TrainingProgram.matchingPreferenceFirst(catalog.offeredPrograms, days: trainingDays)
  }

  func refreshCatalog() async {
    await catalog.refresh()
  }

  func program(id: TrainingProgram.ID) -> TrainingProgram? {
    catalog.program(id: id)
  }

  func continueWithGoogle(using authentication: AuthenticationModel) async {
    if authentication.signedInUser == nil {
      await authentication.signInWithGoogle()
    } else if let selectedProgramID, hasCompletedSetup {
      path = [.programOverview(selectedProgramID)]
    } else {
      // Returning from preferences keeps choices still being edited in this workflow.
      path.append(.preferences)
    }
  }

  func showEmailAuthentication() {
    guard resolvedAccountID != nil else {
      path.append(.emailAuthentication)
      return
    }
    if let selectedProgramID, hasCompletedSetup {
      path = [.programOverview(selectedProgramID)]
    } else if let savedProgress {
      restore(savedProgress)
    } else {
      path = [.preferences]
    }
  }

  func showPrograms() {
    guard saveProgress(nextStep: .programs, programID: selectedProgramID) else { return }
    path.append(.programs)
  }

  func selectProgram(_ id: TrainingProgram.ID) {
    guard catalog.offeredPrograms.contains(where: { $0.id == id }) else { return }
    guard path.last == .programDetail(id),
          saveProgress(nextStep: .trial, programID: id) else { return }
    selectedProgramID = id
    programSelectionMessage = nil
    if path.last == .programDetail(id) {
      path.append(.trialPreview(id))
    }
  }

  private func saveProgress(nextStep: OnboardingProgress.Step, programID: TrainingProgram.ID?) -> Bool {
    guard !isSigningOut else { return false }
    // Development preview routes have no authenticated account and do not persist.
    guard let accountID = resolvedAccountID, let progressStore else { return true }
    let progress = OnboardingProgress(
      weightUnit: weightUnit, trainingDays: trainingDays,
      selectedProgramID: programID, nextStep: nextStep
    )
    do {
      try validate(progress)
      try progressStore.save(progress, accountID: accountID)
      savedProgress = progress
      return true
    } catch {
      progressErrorMessage = "Your choices couldn’t be saved on this device. Please try Continue again. "
        + error.localizedDescription
      progressErrorPresented = true
      return false
    }
  }

  private func validate(_ progress: OnboardingProgress) throws {
    if let completed = progress.completed {
      guard progress.nextStep == .overview,
            completed.setup.preferredUnit == progress.weightUnit,
            completed.setup.trainingDays == progress.trainingDays,
            completed.setup.programID == progress.selectedProgramID else {
        throw AccountSetupError.invalidSetup
      }
    }
    guard (2...5).contains(progress.trainingDays),
          progress.selectedProgramID.map({ catalog.program(id: $0) != nil }) ?? true,
          progress.nextStep != .trial || progress.selectedProgramID != nil,
          progress.nextStep != .overview || progress.completed != nil else {
      throw AccountSetupError.invalidSetup
    }
  }

  private func restore(_ progress: OnboardingProgress) {
    if let completed = progress.completed {
      apply(completed.setup)
      uploadMessage = completed.needsUpload ? "Setup saved on this device. Waiting to upload." : nil
      return
    }
    weightUnit = progress.weightUnit
    trainingDays = progress.trainingDays
    selectedProgramID = progress.selectedProgramID
    restoredCycleID = nil
    switch progress.nextStep {
    case .overview:
      break
    case .preferences:
      path = [.preferences]
    case .programs:
      path = [.preferences, .programs]
    case .trial:
      if let programID = progress.selectedProgramID {
        path = [.preferences, .programs, .programDetail(programID), .trialPreview(programID)]
      }
    }
  }

  func continueWithoutTrial() {
    guard !isSigningOut, let selectedProgramID,
          catalog.offeredPrograms.contains(where: { $0.id == selectedProgramID }),
          path.last == .trialPreview(selectedProgramID)
    else { return }

    if let accountID = resolvedAccountID {
      let setup = AccountSetup(preferredUnit: weightUnit, trainingDays: trainingDays,
                               programID: selectedProgramID, cycleID: UUID())
      do {
        try storeCompleted(setup, needsUpload: true, accountID: accountID)
        apply(setup)
        uploadMessage = "Setup saved on this device. Waiting to upload."
      } catch {
        progressErrorMessage = "Your setup couldn’t be saved on this device. Please try again. " + error.localizedDescription
        progressErrorPresented = true
      }
    } else {
      path.append(.programOverview(selectedProgramID))
    }
  }

  private func apply(_ setup: AccountSetup, replacePath: Bool = true) {
    weightUnit = setup.preferredUnit
    trainingDays = setup.trainingDays
    selectedProgramID = setup.programID
    restoredCycleID = setup.cycleID
    if replacePath { path = [.programOverview(setup.programID)] }
  }

  private func storeCompleted(_ setup: AccountSetup, needsUpload: Bool, accountID: String) throws {
    guard (2...5).contains(setup.trainingDays), catalog.program(id: setup.programID) != nil else {
      throw AccountSetupError.invalidSetup
    }
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
                                       selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: needsUpload)
    try progressStore?.save(progress, accountID: accountID)
    savedProgress = progress
  }

  func retryCompletedUploads(using authentication: AuthenticationModel) async {
    while !Task.isCancelled, authentication.signedInUser != nil {
      await uploadCompletedSetup(using: authentication)
      do { try await Task.sleep(for: .seconds(15)) } catch { break }
    }
  }

  func uploadCompletedSetup(using authentication: AuthenticationModel) async {
    guard !isSigningOut, let user = authentication.signedInUser,
          resolvedAccountID == user.id, let completed = savedProgress?.completed,
          completed.needsUpload, let setupService,
          uploadingGeneration != lookupGeneration else { return }
    let generation = lookupGeneration
    uploadingGeneration = generation
    defer { if uploadingGeneration == generation { uploadingGeneration = nil } }
    uploadMessage = "Uploading setup…"
    do {
      let setup = try await setupService.save(completed.setup, for: user)
      guard generation == lookupGeneration, authentication.signedInUser?.id == user.id,
            !isSigningOut else { return }
      if setup.cycleID != completed.setup.cycleID {
        _ = try workoutRepository?.blockSessionUploadsForSetupCycle(
          accountID: user.id, cycleID: completed.setup.cycleID, establishedCycleID: setup.cycleID
        )
      }
      try storeCompleted(setup, needsUpload: false, accountID: user.id)
      // A different device may have established setup first. Respect its cycle.
      apply(setup, replacePath: setup.cycleID != completed.setup.cycleID)
      uploadMessage = nil
      presentSessionUploadErrorIfNeeded(accountID: user.id)
      await retryPendingSessionUploads(using: authentication)
    } catch {
      guard generation == lookupGeneration, authentication.signedInUser?.id == user.id else { return }
      if (error as? AccountSetupError) == .programUnavailable {
        recoverPendingSetupAfterProgramRemoval(completed, accountID: user.id)
        return
      }
      uploadMessage = "Setup saved on this device. Upload pending. You can retry now or stay here for automatic retry."
    }
  }

  private func recoverPendingSetupAfterProgramRemoval(_ completed: CompletedOnboarding, accountID: String) {
    let progress = OnboardingProgress(
      weightUnit: completed.setup.preferredUnit,
      trainingDays: completed.setup.trainingDays,
      selectedProgramID: nil,
      nextStep: .programs
    )
    do {
      try progressStore?.save(progress, accountID: accountID)
    } catch {
      progressErrorMessage = "Your available program choices couldn’t be saved on this device. "
        + error.localizedDescription
      progressErrorPresented = true
    }
    savedProgress = progress
    selectedProgramID = nil
    restoredCycleID = nil
    path = [.preferences, .programs]
    uploadMessage = nil
    programSelectionMessage = "That program is no longer available. Choose an available program to finish setup."
  }

  private func presentSessionUploadErrorIfNeeded(accountID: String) {
    guard let workoutRepository,
          (try? workoutRepository.hasUnresolvedSetupCycleConflict(accountID: accountID)) == true else { return }
    sessionUploadErrorMessage = "Your completed workout is still saved on this device. It belongs to a different cycle than the one already on your account, so it wasn’t uploaded or moved. Keep this device while the cycle conflict is resolved."
    sessionUploadErrorPresented = true
  }

  func previewWorkout(programID: TrainingProgram.ID, workoutID: WorkoutTemplate.ID) {
    guard selectedProgramID == programID,
          let program = catalog.program(id: programID),
          program.workouts.contains(where: { $0.id == workoutID })
    else { return }

    let route = OnboardingRoute.workoutPreview(programID: programID, workoutID: workoutID)
    if hasCompletedSetup {
      programPath.append(route)
    } else if path.last == .programOverview(programID) {
      path.append(route)
    }
  }

  func startWorkout(programID: String, workoutID: String, accountID: String) {
    guard let workoutRepository = ensureWorkoutRepository(), let cycleID = restoredCycleID,
          let program = catalog.program(id: programID),
          let index = program.workouts.firstIndex(where: { $0.id == workoutID }) else {
      workoutErrorMessage = "Your workout could not be started. Please try again."
      workoutErrorPresented = true
      return
    }
    do {
      let next = try workoutRepository.nextOccurrence(accountID: accountID, cycleID: cycleID,
        programID: programID, workoutIDs: program.workouts.map(\.id))
      guard next.workoutID == workoutID else {
        workoutErrorMessage = "Complete the earlier workout day before starting this one."
        workoutErrorPresented = true
        return
      }
      let session = WorkoutSession(accountID: accountID, cycleID: cycleID, program: program,
        workout: program.workouts[index], week: next.week, day: next.day, weightUnit: weightUnit)
      activeWorkoutSession = try workoutRepository.start(session)
      let route = OnboardingRoute.workoutRecording(activeWorkoutSession!.id)
      if hasCompletedSetup { programPath.append(route) } else { path.append(route) }
    } catch {
      workoutErrorMessage = error.localizedDescription
      workoutErrorPresented = true
    }
  }

  func retryWorkoutStorage() {
    guard let workoutRepositoryFactory else { return }
    do {
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
      workoutStorageOpenFailed = false
      workoutErrorPresented = false
      if let resolvedAccountID {
        activeWorkoutSession = try workoutRepository?.activeSession(accountID: resolvedAccountID)
      }
    } catch {
      workoutStorageOpenFailed = true
      workoutErrorMessage = "Workout storage couldn’t be opened. Your saved workouts are still on this device. Try opening storage again.\n\(error.localizedDescription)"
      workoutErrorPresented = true
    }
  }

  private func ensureWorkoutRepository() -> WorkoutRepository? {
    if let workoutRepository { return workoutRepository }
    retryWorkoutStorage()
    return workoutRepository
  }

  func discardActiveWorkout(accountID: String) {
    guard let activeWorkoutSession else { return }
    do {
      try workoutRepository?.discard(sessionID: activeWorkoutSession.id, accountID: accountID)
      self.activeWorkoutSession = nil
      if path.last == .workoutRecording(activeWorkoutSession.id) { path.removeLast() }
      if programPath.last == .workoutRecording(activeWorkoutSession.id) { programPath.removeLast() }
    } catch {
      workoutErrorMessage = error.localizedDescription
      workoutErrorPresented = true
    }
  }

  func saveWorkoutDraft(slotID: String, weightInput: String, repsInput: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.saveDraft(
        sessionID: session.id, accountID: session.accountID, slotID: slotID,
        weightInput: weightInput, repsInput: repsInput
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func completeWorkoutSet(slotID: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      let restSeconds = session.exercises.first(where: { $0.slotID == slotID })?.restSeconds
      activeWorkoutSession = try workoutRepository.completeSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID, restSeconds: restSeconds
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func updateWorkoutSet(slotID: String, weightInput: String, repsInput: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.updateSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID,
        weightInput: weightInput, repsInput: repsInput
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func unmarkWorkoutSet(slotID: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.unmarkSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func completedWorkoutIDs(programID: String, week: Int) -> Set<String> {
    guard let workoutRepository, let cycleID = restoredCycleID,
          let accountID = resolvedAccountID else { return [] }
    return (try? workoutRepository.completedOccurrenceIDs(accountID: accountID, cycleID: cycleID, week: week)) ?? []
  }

  func currentWorkoutWeek(programID: String) -> Int {
    guard let workoutRepository, let cycleID = restoredCycleID,
          let accountID = resolvedAccountID, let program = catalog.program(id: programID) else { return 1 }
    return (try? workoutRepository.nextOccurrence(accountID: accountID, cycleID: cycleID,
      programID: programID, workoutIDs: program.workouts.map(\.id)).week) ?? 1
  }

  func finishActiveWorkout(note: String?, using authentication: AuthenticationModel? = nil) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      _ = try workoutRepository.finish(sessionID: session.id, accountID: session.accountID, note: note)
      activeWorkoutSession = nil
      if path.last == .workoutRecording(session.id) { path.removeLast() }
      if programPath.last == .workoutRecording(session.id) { programPath.removeLast() }
      if let last = path.last, case .workoutPreview = last { path.removeLast() }
      if let last = programPath.last, case .workoutPreview = last { programPath.removeLast() }
      if let authentication {
        let queue = try? workoutRepository.sessionUploadQueue(accountID: session.accountID)
        if queue?.contains(where: { $0.upload.sessionID == session.id
          && $0.permanentFailure == .setupCycleConflict }) == true {
          presentSessionUploadErrorIfNeeded(accountID: session.accountID)
        }
        if queue?.contains(where: { $0.permanentFailure == nil && !$0.isAuthenticationDeferred }) == true {
          Task { await retryPendingSessionUploads(using: authentication) }
        }
      }
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func resumeDeferredSessionUploads(
    using authentication: AuthenticationModel,
    at date: Date = .now,
    scheduleRetries: Bool = true
  ) async {
    guard !isSigningOut, let user = authentication.signedInUser,
          resolvedAccountID == user.id,
          let workoutRepository else { return }
    try? workoutRepository.resumeAuthenticationDeferredUploads(accountID: user.id)
    await retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: scheduleRetries)
  }

  func retryPendingSessionUploads(
    using authentication: AuthenticationModel,
    at date: Date = .now,
    scheduleRetries: Bool = true
  ) async {
    guard !isSigningOut, !hasPendingSetup,
          let user = authentication.signedInUser,
          resolvedAccountID == user.id,
          let completedSessionUploadCoordinator else { return }
    let generation = lookupGeneration
    let isCurrent: @MainActor () -> Bool = { [weak self] in
      guard let self else { return false }
      return !self.isSigningOut && generation == self.lookupGeneration
        && authentication.signedInUser?.id == user.id
        && self.resolvedAccountID == user.id
    }
    presentSessionUploadErrorIfNeeded(accountID: user.id)
    await completedSessionUploadCoordinator.drain(
      for: user,
      whileCurrent: isCurrent,
      at: date,
      scheduleRetries: scheduleRetries
    )
    guard isCurrent() else { return }
    presentSessionUploadErrorIfNeeded(accountID: user.id)
  }

  func adjustWorkoutRest(by seconds: Int) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.adjustRest(
        sessionID: session.id, accountID: session.accountID, by: seconds
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func skipWorkoutRest() -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.skipRest(
        sessionID: session.id, accountID: session.accountID
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func previousPerformances(for session: WorkoutSession) -> [String: WorkoutRepository.PreviousPerformance] {
    guard let workoutRepository else { return [:] }
    return (try? workoutRepository.previousPerformances(accountID: session.accountID,
      exercises: session.exercises.map { .init(slotID: $0.slotID, exerciseKey: $0.exerciseKey) },
      programID: session.programID, workoutID: session.workoutID)) ?? [:]
  }

  func completedHistorySessions(accountID: String) throws -> [WorkoutSession] {
    guard resolvedAccountID == accountID else { throw HistoryDataError.accountUnavailable }
    if workoutRepository == nil {
      guard let workoutRepositoryFactory else { throw HistoryDataError.storageUnavailable }
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
    }
    guard let workoutRepository else { throw HistoryDataError.storageUnavailable }
    workoutStorageOpenFailed = false
    return try workoutRepository.completedSessions(accountID: accountID)
  }

  func completedHistoryCoverage(accountID: String) throws -> SessionHistoryCoverage {
    try historyRepository(accountID: accountID).historyCoverage(accountID: accountID)
  }

  func saveCompletedHistoryPage(_ page: SessionHistoryPage, accountID: String) throws {
    try historyRepository(accountID: accountID).saveHistoryPage(page, accountID: accountID)
  }

  func fetchHistoryPage(
    accountID: String, cursor: String?, using authentication: AuthenticationModel
  ) async throws -> SessionHistoryPage {
    guard let user = authentication.signedInUser, user.id == accountID,
          resolvedAccountID == accountID, let sessionHistoryService else {
      throw HistoryDataError.accountUnavailable
    }
    let page = try await sessionHistoryService.fetchPage(for: user, cursor: cursor)
    guard authentication.signedInUser?.id == accountID, resolvedAccountID == accountID else {
      throw HistoryDataError.accountUnavailable
    }
    return page
  }

  private func historyRepository(accountID: String) throws -> WorkoutRepository {
    guard resolvedAccountID == accountID else { throw HistoryDataError.accountUnavailable }
    if workoutRepository == nil {
      guard let workoutRepositoryFactory else { throw HistoryDataError.storageUnavailable }
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
    }
    guard let workoutRepository else { throw HistoryDataError.storageUnavailable }
    workoutStorageOpenFailed = false
    return workoutRepository
  }

  func programName(id: String) -> String? {
    catalog.program(id: id)?.name
  }

  private func refreshPreviousPerformances(
    for user: AuthenticatedUser, generation: Int, authentication: AuthenticationModel
  ) async {
    guard let previousPerformanceService, let workoutRepository else { return }
    do {
      let results = try await previousPerformanceService.lookup(for: user)
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            resolvedAccountID == user.id else { return }
      try workoutRepository.saveRestoredPreviousPerformances(results, accountID: user.id)
      previousPerformanceUnavailable = false
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            resolvedAccountID == user.id else { return }
      previousPerformanceUnavailable = true
    }
  }

  func retryPreviousPerformances(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser, resolvedAccountID == user.id else { return }
    await refreshPreviousPerformances(for: user, generation: lookupGeneration, authentication: authentication)
  }

  private func showWorkoutSaveError(_ error: Error) {
    workoutErrorMessage = error.localizedDescription
    workoutErrorPresented = true
  }
}
