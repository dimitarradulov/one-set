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
  var signOutErrorPresented = false
  private(set) var signOutErrorMessage = ""
  var progressErrorPresented = false
  private(set) var progressErrorMessage = ""
  private let progressStore: (any OnboardingProgressStore)?
  private var savedProgress: UnfinishedOnboarding?
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
        guard (2...5).contains(setup.trainingDays), catalog.program(id: setup.programID) != nil else {
          throw AccountSetupError.invalidSetup
        }
        weightUnit = setup.preferredUnit
        trainingDays = setup.trainingDays
        selectedProgramID = setup.programID
        restoredCycleID = setup.cycleID
        path = [.programOverview(setup.programID)]
      } else if let savedProgress {
        restore(savedProgress)
      } else {
        let progress = UnfinishedOnboarding(
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

  func signOut(using authentication: AuthenticationModel) async {
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

  func showPreferences() {
    path.append(.preferences)
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
    if let selectedProgramID, restoredCycleID != nil {
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

  private func saveProgress(nextStep: UnfinishedOnboarding.Step, programID: TrainingProgram.ID?) -> Bool {
    guard !isSigningOut else { return false }
    // Development preview routes have no authenticated account and do not persist.
    guard let accountID = resolvedAccountID, let progressStore else { return true }
    let progress = UnfinishedOnboarding(
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

  private func validate(_ progress: UnfinishedOnboarding) throws {
    guard (2...5).contains(progress.trainingDays),
          progress.selectedProgramID.map({ catalog.program(id: $0) != nil }) ?? true,
          progress.nextStep != .trial || progress.selectedProgramID != nil else {
      throw AccountSetupError.invalidSetup
    }
  }

  private func restore(_ progress: UnfinishedOnboarding) {
    weightUnit = progress.weightUnit
    trainingDays = progress.trainingDays
    selectedProgramID = progress.selectedProgramID
    restoredCycleID = nil
    switch progress.nextStep {
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
    guard let selectedProgramID,
          catalog.program(id: selectedProgramID) != nil,
          path.last == .trialPreview(selectedProgramID)
    else { return }

    path.append(.programOverview(selectedProgramID))
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
