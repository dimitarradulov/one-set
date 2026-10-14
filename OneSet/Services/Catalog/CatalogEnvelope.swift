import Foundation

struct CatalogEnvelope: Decodable, Sendable {
  let publicationId: String?
  let catalog: CatalogDocument?
}
