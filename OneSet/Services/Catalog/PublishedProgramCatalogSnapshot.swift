import Foundation

struct PublishedProgramCatalogSnapshot: Codable, Equatable, Sendable {
  let publicationID: String?
  let entityTag: String
  let programs: [TrainingProgram]
  let exerciseLibrary: [WorkoutExercise]?

  init(publicationID: String?, entityTag: String, programs: [TrainingProgram],
       exerciseLibrary: [WorkoutExercise]? = nil) {
    self.publicationID = publicationID
    self.entityTag = entityTag
    self.programs = programs
    self.exerciseLibrary = exerciseLibrary
  }
}
