import Foundation

struct CatalogWorkoutDocument: Decodable, Sendable {
  let key: String
  let name: String
  let removed: Bool?
  let exercises: [CatalogSlotDocument]
}
