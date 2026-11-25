import Foundation

@MainActor
struct HTTPAccountSetupService: AccountSetupService {
  let authentication: ClerkAuthenticationService

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    try await send(for: user, setup: nil)
  }

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    guard let saved = try await send(for: user, setup: setup) else { throw AccountSetupError.invalidSetup }
    return saved
  }

  func updatePreferences(_ preferences: AccountPreferences, for user: AuthenticatedUser) async throws -> AccountPreferences {
    var request = try await makeRequest(path: "v1/me", for: user)
    request.httpMethod = "PATCH"
    request.httpBody = try JSONEncoder().encode(preferences)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw AccountSetupError.unavailable }
    guard response.statusCode == 200 else {
      switch response.statusCode {
      case 400: throw AccountSetupError.invalidPreferences
      case 401: throw AccountSetupError.authenticationRequired
      // 409 SETUP_REQUIRED and 503 are temporary from the app's point of view.
      default: throw AccountSetupError.unavailable
      }
    }
    do {
      return try JSONDecoder().decode(AccountPreferences.self, from: data)
    } catch {
      throw AccountSetupError.unavailable
    }
  }

  private func makeRequest(path: String, for user: AuthenticatedUser) async throws -> URLRequest {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https",
          baseURL.host != nil else { throw AccountSetupError.unavailable }
    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: path))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    return request
  }

  private func send(for user: AuthenticatedUser, setup: AccountSetup?) async throws -> AccountSetup? {
    var request = try await makeRequest(path: "v1/me/setup", for: user)
    if let setup {
      request.httpMethod = "PUT"
      request.httpBody = try JSONEncoder().encode(setup)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw AccountSetupError.unavailable }
    guard response.statusCode == 200 else {
      if response.statusCode == 401 { throw AccountSetupError.authenticationRequired }
      if response.statusCode == 409,
         let result = try? JSONDecoder().decode(ErrorResponse.self, from: data),
         result.error.code == "PROGRAM_UNAVAILABLE" {
        throw AccountSetupError.programUnavailable
      }
      throw AccountSetupError.unavailable
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

private struct ErrorResponse: Decodable {
  struct APIError: Decodable { let code: String }
  let error: APIError
}
