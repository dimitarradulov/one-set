import Foundation

@MainActor
struct HTTPAccountProgressService: AccountProgressService {
  let authentication: ClerkAuthenticationService

  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https",
          baseURL.host != nil else { throw AccountSetupError.unavailable }
    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: "v1/me/progress"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw AccountSetupError.unavailable }
    guard response.statusCode == 200 else {
      if response.statusCode == 401 { throw AccountSetupError.authenticationRequired }
      throw AccountSetupError.unavailable
    }
    struct LookupResponse: Decodable {
      let progress: AccountProgress?
    }
    return try JSONDecoder().decode(LookupResponse.self, from: data).progress
  }
}
