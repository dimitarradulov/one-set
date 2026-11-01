import Foundation

@MainActor
struct HTTPCompletedSessionUploadService: CompletedSessionUploadService {
  let authentication: ClerkAuthenticationService

  func upload(_ pending: PendingSessionUpload, for user: AuthenticatedUser) async throws {
    guard pending.accountID == user.id,
          let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https", baseURL.host != nil else {
      throw AccountSetupError.unavailable
    }

    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: "v1/sessions/completed"))
    request.httpMethod = "POST"
    request.httpBody = pending.body
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw AccountSetupError.unavailable }
    switch response.statusCode {
    case 200, 201:
      let acknowledgment = try JSONDecoder().decode(CompletedSessionUploadAcknowledgment.self, from: data)
      guard acknowledgment.sessionID == pending.sessionID.uuidString.lowercased(),
            ["created", "acknowledged"].contains(acknowledgment.result) else {
        throw AccountSetupError.unavailable
      }
    case 401:
      throw CompletedSessionUploadError.authenticationRequired
    case 403:
      throw CompletedSessionUploadError.forbidden
    case 409:
      throw CompletedSessionUploadError.conflict
    case 400, 422:
      throw CompletedSessionUploadError.invalidSession
    default:
      throw AccountSetupError.unavailable
    }
  }
}

private struct CompletedSessionUploadAcknowledgment: Decodable {
  let sessionID: String
  let result: String

  enum CodingKeys: String, CodingKey {
    case result
    case sessionID = "session_id"
  }
}
