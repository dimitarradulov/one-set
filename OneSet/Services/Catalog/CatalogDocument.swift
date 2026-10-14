import Foundation

struct CatalogDocument: Decodable, Sendable {
  let exercises: [CatalogExerciseDocument]
  let programs: [CatalogProgramDocument]
}
