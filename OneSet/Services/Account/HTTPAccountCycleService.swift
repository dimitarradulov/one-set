import Foundation

@MainActor
struct HTTPAccountCycleService: AccountCycleService {
  let authentication: ClerkAuthenticationService

  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    let data = try await send(path: "v1/me/cycles", method: "GET", body: nil, for: user)
    do {
      return try JSONDecoder().decode(AccountCycles.self, from: data)
    } catch {
      throw AccountCycleError.unavailable
    }
  }

  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    let body = try JSONEncoder().encode(cycle)
    let data = try await send(path: "v1/cycles", method: "POST", body: body, for: user)
    struct Response: Decodable {
      let cycleID: UUID
      let result: String
      enum CodingKeys: String, CodingKey { case cycleID = "cycle_id", result }
    }
    guard let response = try? JSONDecoder().decode(Response.self, from: data),
          response.cycleID == cycle.cycleID,
          response.result == "created" || response.result == "acknowledged" else {
      throw AccountCycleError.unavailable
    }
  }

  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {
    let data = try await send(path: "v1/cycles/\(cycleID.uuidString)/activate", method: "POST", body: nil, for: user)
    struct Response: Decodable {
      let cycleID: UUID
      let result: String
      enum CodingKeys: String, CodingKey { case cycleID = "cycle_id", result }
    }
    guard let response = try? JSONDecoder().decode(Response.self, from: data),
          response.cycleID == cycleID, response.result == "activated" else {
      throw AccountCycleError.unavailable
    }
  }

  private func send(path: String, method: String, body: Data?, for user: AuthenticatedUser) async throws -> Data {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https",
          baseURL.host != nil else { throw AccountCycleError.unavailable }
    let token: String
    do {
      token = try await authentication.sessionToken(for: user)
    } catch {
      throw AccountCycleError.authenticationRequired
    }
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = method
    request.httpBody = body
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw AccountCycleError.unavailable
    }
    guard let http = response as? HTTPURLResponse else { throw AccountCycleError.unavailable }
    guard (200...201).contains(http.statusCode) else {
      if http.statusCode == 401 { throw AccountCycleError.authenticationRequired }
      if http.statusCode == 403 { throw AccountCycleError.forbidden }
      struct ErrorResponse: Decodable {
        struct APIError: Decodable { let code: String }
        let error: APIError
      }
      switch (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.code {
      case "PROGRAM_UNAVAILABLE": throw AccountCycleError.programUnavailable
      case "CYCLE_CONFLICT": throw AccountCycleError.conflict
      case "INVALID_CYCLE": throw AccountCycleError.invalidCycle
      default: throw AccountCycleError.unavailable
      }
    }
    return data
  }
}
