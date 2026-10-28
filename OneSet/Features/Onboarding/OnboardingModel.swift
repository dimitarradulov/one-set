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
  private var lookupGeneration = 0
  private var resolvedAccountID: String?
  private let catalog: ProgramCatalog
  private let workoutRepository: WorkoutRepository?
  private(set) var activeWorkoutSession: WorkoutSession?
  var workoutErrorPresented = false
  private(set) var workoutErrorMessage = ""

  init(
    catalog: ProgramCatalog,
    setupService: (any AccountSetupService)? = nil,
    progressStore: (any OnboardingProgressStore)? = nil,
    workoutRepository: WorkoutRepository? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil,
    initialProgramPath: [OnboardingRoute] = [],
    initialSettingsPath: [SettingsDestination] = [],
    initialMainTab: MainTab = .program
  ) {
    self.catalog = catalog
    self.setupService = setupService
    self.progressStore = progressStore
    self.workoutRepository = workoutRepository
    path = initialPath
    selectedProgramID = initialSelectedProgramID
    programPath = initialProgramPath
    settingsPath = initialSettingsPath
    selectedMainTab = initialMainTab
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
        try storeCompleted(setup, needsUpload: false, accountID: user.id)
        apply(setup)
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
      setupResolution = .idle
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if let savedProgress, (try? validate(savedProgress)) != nil,
         !(error is CocoaError), !(error is DecodingError),
         (error as? AccountSetupError) != .invalidSetup {
        restore(savedProgress)
        resolvedAccountID = user.id
        setupResolution = .idle
      } else {
        setupResolution = .failed(error.localizedDescription)
      }
    }
  }

  private var isSetupIdle: Bool {
    if case .idle = setupResolution { return true }
    return false
  }

  func signOut(using authentication: AuthenticationModel, discardPending: Bool = false) async {
    if activeWorkoutSession != nil {
      signOutErrorMessage = "Finish or discard your current workout first."
      signOutErrorPresented = true
      return
    }
    if hasPendingSetup && !discardPending {
      discardSetupPresented = true
      return
    }
    guard !isSigningOut, let accountID = authentication.signedInUser?.id else { return }
    isSigningOut = true
    defer { isSigningOut = false }
    lookupGeneration += 1
    let previousResolution = setupResolution
    do {
      // Clear before ending the session: a removal failure must not leave resumable
      // progress behind for an account that was successfully signed out.
      let progress = try progressStore?.load(accountID: accountID)
      try progressStore?.remove(accountID: accountID)
      await authentication.signOut()
      if authentication.signedInUser == nil {
        resetAccount()
      } else if authentication.signedInUser?.id == accountID {
        if let progress { try progressStore?.save(progress, accountID: accountID) }
        setupResolution = previousResolution
        if case .loading = previousResolution {
          await resolveAfterFailedSignOut(using: authentication)
        }
        signOutErrorMessage = authentication.errorMessage ?? "Please try again."
        signOutErrorPresented = true
      }
    } catch {
      if case .loading = previousResolution {
        await resolveAfterFailedSignOut(using: authentication)
      }
      signOutErrorMessage = error.localizedDescription
      signOutErrorPresented = true
    }
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
    setupResolution = .idle
    restoredCycleID = nil
    savedProgress = nil
    uploadingGeneration = nil
    uploadMessage = nil
    programSelectionMessage = nil
    discardSetupPresented = false
    progressErrorPresented = false
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
      try storeCompleted(setup, needsUpload: false, accountID: user.id)
      // A different device may have established setup first. Respect its cycle.
      apply(setup, replacePath: setup.cycleID != completed.setup.cycleID)
      uploadMessage = nil
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
    guard let workoutRepository, let cycleID = restoredCycleID,
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

  func finishActiveWorkout(note: String?) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      _ = try workoutRepository.finish(sessionID: session.id, accountID: session.accountID, note: note)
      activeWorkoutSession = nil
      if path.last == .workoutRecording(session.id) { path.removeLast() }
      if programPath.last == .workoutRecording(session.id) { programPath.removeLast() }
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  private func showWorkoutSaveError(_ error: Error) {
    workoutErrorMessage = error.localizedDescription
    workoutErrorPresented = true
  }
}
