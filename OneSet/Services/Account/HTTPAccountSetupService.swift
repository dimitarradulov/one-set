import Foundation

@MainActor
struct HTTPAccountSetupService: AccountSetupService {
  let authentication: ClerkAuthenticationService

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https",
          baseURL.host != nil else { throw AccountSetupError.unavailable }
    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: "v1/me/setup"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw AccountSetupError.unavailable }
    guard response.statusCode == 200 else {
      throw response.statusCode == 401 ? AccountSetupError.authenticationRequired : AccountSetupError.unavailable
    }
    struct LookupResponse: Decodable {
      let setup: AccountSetup?
      enum CodingKeys: CodingKey { case setup }
      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setup = try container.decode(AccountSetup?.self, forKey: .setup)
      }
    }
    return try JSONDecoder().decode(LookupResponse.self, from: data).setup
  }
}
