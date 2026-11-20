import Foundation

struct CatalogSlotDocument: Decodable, Sendable {
  let key: String
  let exercise: String
  let scope: String?
  let stoppingGuidance: String?
  let removed: Bool?
  let reps: CatalogRepRange
}
