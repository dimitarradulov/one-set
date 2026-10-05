import Foundation
import Observation

@MainActor
@Observable
final class OnboardingModel {
  var path: [OnboardingRoute]
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
  private let setupService: (any AccountSetupService)?
  private var lookupGeneration = 0
  private var resolvedAccountID: String?
  private let catalog: ProgramCatalog

  init(
    catalog: ProgramCatalog,
    setupService: (any AccountSetupService)? = nil,
    progressStore: (any OnboardingProgressStore)? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil
  ) {
    self.catalog = catalog
    self.setupService = setupService
    self.progressStore = progressStore
    path = initialPath
    selectedProgramID = initialSelectedProgramID
  }

  func resolveAccountSetup(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser else {
      if resolvedAccountID != nil || !isSetupIdle { resetAccount() }
      return
    }
    guard !isSigningOut, resolvedAccountID != user.id, let setupService else { return }
    resetAccount()
    lookupGeneration += 1
    let generation = lookupGeneration
    setupResolution = .loading
    do {
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
    lookupGeneration += 1
    resolvedAccountID = nil
    setupResolution = .idle
    restoredCycleID = nil
    savedProgress = nil
    uploadingGeneration = nil
    uploadMessage = nil
    discardSetupPresented = false
    progressErrorPresented = false
    signOutErrorPresented = false
    weightUnit = .kilograms
    trainingDays = 3
    selectedProgramID = nil
    path = []
  }

  var programs: [TrainingProgram] {
    TrainingProgram.matchingPreferenceFirst(catalog.programs, days: trainingDays)
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

  func showLogin() {
    showAccountEntry(.login)
  }

  func showEmailAuthentication() {
    showAccountEntry(.emailAuthentication)
  }

  private func showAccountEntry(_ route: OnboardingRoute) {
    guard resolvedAccountID != nil else {
      path.append(route)
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
    guard catalog.program(id: id) != nil else { return }
    guard path.last == .programDetail(id),
          saveProgress(nextStep: .trial, programID: id) else { return }
    selectedProgramID = id
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
          catalog.program(id: selectedProgramID) != nil,
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
      uploadMessage = "Setup saved on this device. Upload pending. You can retry now or stay here for automatic retry."
    }
  }

  func previewWorkout(programID: TrainingProgram.ID, workoutID: WorkoutTemplate.ID) {
    guard selectedProgramID == programID,
          path.last == .programOverview(programID),
          let program = catalog.program(id: programID),
          program.workouts.contains(where: { $0.id == workoutID })
    else { return }

    path.append(.workoutPreview(programID: programID, workoutID: workoutID))
  }
}
