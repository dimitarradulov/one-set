import Foundation

struct CatalogWorkoutDocument: Decodable, Sendable {
  let key: String
  let name: String
  let banner: String?
  let weekParity: WorkoutTemplate.WeekParity?
  let removed: Bool?
  let supersets: [SupersetPair]?
  let exercises: [CatalogSlotDocument]
}
