import Foundation

@MainActor
protocol ProgramCatalogService {
  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult
}
