import Foundation

enum ProgramCatalogFetchResult: Sendable {
  case notModified
  case snapshot(PublishedProgramCatalogSnapshot)
}
