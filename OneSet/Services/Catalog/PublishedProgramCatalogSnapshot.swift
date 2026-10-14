import Foundation

struct PublishedProgramCatalogSnapshot: Codable, Equatable, Sendable {
  let publicationID: String?
  let entityTag: String
  let programs: [TrainingProgram]
}
