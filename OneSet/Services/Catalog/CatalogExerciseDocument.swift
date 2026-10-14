import Foundation

struct CatalogExerciseDocument: Decodable, Sendable {
  let key: String
  let name: String
  let instructions: String
  let stoppingGuidance: String
  let warmupGuidance: String
  let restSeconds: Int
  let defaultReps: CatalogRepRange
  let videoKey: String?
}
