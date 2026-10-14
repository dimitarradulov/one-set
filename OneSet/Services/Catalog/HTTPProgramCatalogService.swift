import Foundation

@MainActor
struct HTTPProgramCatalogService: ProgramCatalogService {
  let authentication: ClerkAuthenticationService

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    guard let user = authentication.signedInUser,
          let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https", baseURL.host != nil else {
      throw ProgramCatalogServiceError.unavailable
    }

    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: "v1/catalog"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let ifNoneMatch { request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match") }
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw ProgramCatalogServiceError.unavailable }
    if response.statusCode == 304 { return .notModified }
    guard response.statusCode == 200 else { throw ProgramCatalogServiceError.unavailable }

    let envelope = try JSONDecoder.catalogDecoder.decode(CatalogEnvelope.self, from: data)
    guard let document = envelope.catalog,
          let publicationID = envelope.publicationId, !publicationID.isEmpty,
          let entityTag = response.value(forHTTPHeaderField: "ETag"),
          !entityTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !document.exercises.isEmpty, !document.programs.isEmpty else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    let exerciseKeys = document.exercises.map(\.key)
    let programKeys = document.programs.map(\.key)
    let workoutKeys = document.programs.flatMap { $0.workouts.map(\.key) }
    let slotKeys = document.programs.flatMap { $0.workouts.flatMap { $0.exercises.map(\.key) } }
    guard Set(exerciseKeys).count == exerciseKeys.count,
          Set(programKeys).count == programKeys.count,
          Set(workoutKeys).count == workoutKeys.count,
          Set(slotKeys).count == slotKeys.count else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    let exercises = Dictionary(uniqueKeysWithValues: document.exercises.map { ($0.key, $0) })
    let programs = try document.programs.map { try $0.model(exercises: exercises) }
    guard !programs.isEmpty else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    return .snapshot(PublishedProgramCatalogSnapshot(
      publicationID: publicationID, entityTag: entityTag, programs: programs
    ))
  }
}
