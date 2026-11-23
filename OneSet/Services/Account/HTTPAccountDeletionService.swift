import Foundation

@MainActor
struct HTTPAccountDeletionService: AccountDeletionService {
  typealias TokenProvider = @MainActor (AuthenticatedUser) async throws -> String
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  let baseURL: URL?
  let token: TokenProvider
  let send: Transport

  init(baseURL: URL?, token: @escaping TokenProvider, send: @escaping Transport) {
    self.baseURL = baseURL
    self.token = token
    self.send = send
  }

  init(authentication: ClerkAuthenticationService) {
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String)
      .flatMap(URL.init(string:))
    self.init(
      baseURL: configured,
      token: { try await authentication.sessionToken(for: $0) },
      send: { try await URLSession.shared.data(for: $0) })
  }

  func deleteAccount(for user: AuthenticatedUser) async -> AccountDeletionResult {
    guard let baseURL, baseURL.scheme == "https", baseURL.host != nil,
          let bearer = try? await token(user) else { return .failed }
    var request = URLRequest(url: baseURL.appending(path: "v1/me"))
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    guard let (_, response) = try? await send(request),
          let http = response as? HTTPURLResponse,
          http.statusCode == 200 else { return .failed }
    return .deleted
  }
}
