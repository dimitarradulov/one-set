struct ProgramCatalog: Sendable {
  let programs: [TrainingProgram]

  func program(id: TrainingProgram.ID) -> TrainingProgram? {
    programs.first { $0.id == id }
  }
}
