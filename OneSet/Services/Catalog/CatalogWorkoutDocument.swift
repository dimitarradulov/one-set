import Foundation

struct CatalogWorkoutDocument: Decodable, Sendable {
  let key: String
  let name: String
  let banner: String?
  let removed: Bool?
  let supersets: [SupersetPair]?
  let exercises: [CatalogSlotDocument]
}
