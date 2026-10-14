import Foundation

@MainActor
protocol ProgramCatalogPersistence {
  func load() throws -> PublishedProgramCatalogSnapshot?
  func save(_ snapshot: PublishedProgramCatalogSnapshot) throws
}
