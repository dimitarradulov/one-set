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
  private let setupService: (any AccountSetupService)?
  private var lookupGeneration = 0
  private var resolvedAccountID: String?
  private let catalog: ProgramCatalog

  init(
    catalog: ProgramCatalog,
    setupService: (any AccountSetupService)? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil
  ) {
    self.catalog = catalog
    self.setupService = setupService
    path = initialPath
    selectedProgramID = initialSelectedProgramID
  }

  func resolveAccountSetup(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser else {
      if resolvedAccountID != nil || !isSetupIdle { resetAccount() }
      return
    }
    guard resolvedAccountID != user.id, let setupService else { return }
    lookupGeneration += 1
    let generation = lookupGeneration
    setupResolution = .loading
    do {
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
      } else {
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
      setupResolution = .failed(error.localizedDescription)
    }
  }

  private var isSetupIdle: Bool {
    if case .idle = setupResolution { return true }
    return false
  }

  func signOut(using authentication: AuthenticationModel) async {
    await authentication.signOut()
    if authentication.signedInUser == nil {
      resetAccount()
    } else if let message = authentication.errorMessage {
      signOutErrorMessage = message
      signOutErrorPresented = true
    }
  }

  func resetAccount() {
    lookupGeneration += 1
    resolvedAccountID = nil
    setupResolution = .idle
    restoredCycleID = nil
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
    } else {
      path = [.preferences]
    }
  }

  func showPrograms() {
    path.append(.programs)
  }

  func selectProgram(_ id: TrainingProgram.ID) {
    guard catalog.program(id: id) != nil else { return }
    selectedProgramID = id
    if path.last == .programDetail(id) {
      path.append(.trialPreview(id))
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
