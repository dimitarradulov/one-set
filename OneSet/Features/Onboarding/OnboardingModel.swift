import Observation

@MainActor
@Observable
final class OnboardingModel {
  var path: [OnboardingRoute]
  var weightUnit: WeightUnit = .kilograms
  var trainingDays = 3
  private(set) var selectedProgramID: TrainingProgram.ID?

  private let catalog: ProgramCatalog

  init(
    catalog: ProgramCatalog,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil
  ) {
    self.catalog = catalog
    path = initialPath
    selectedProgramID = initialSelectedProgramID
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
    path.append(.login)
  }

  func showEmailAuthentication() {
    path.append(.emailAuthentication)
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
