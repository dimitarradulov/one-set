import Foundation

@MainActor
protocol PreviousPerformanceService {
  func lookup(for user: AuthenticatedUser) async throws -> [WorkoutRepository.PreviousPerformanceSnapshot]
}

@MainActor
struct HTTPPreviousPerformanceService: PreviousPerformanceService {
  let authentication: ClerkAuthenticationService

  func lookup(for user: AuthenticatedUser) async throws -> [WorkoutRepository.PreviousPerformanceSnapshot] {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https", baseURL.host != nil else {
      throw AccountSetupError.unavailable
    }
    let token = try await authentication.sessionToken(for: user)
    var request = URLRequest(url: baseURL.appending(path: "v1/me/previous-performance"))
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
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = formatter.date(from: value) { return date }
      formatter.formatOptions = [.withInternetDateTime]
      guard let date = formatter.date(from: value) else { throw AccountSetupError.unavailable }
      return date
    }
    let responseBody = try decoder.decode(PreviousPerformanceResponse.self, from: data)
    return try responseBody.results.map { result in
      guard let unit = WeightUnit(rawValue: result.unit),
            Double(result.weight)?.isFinite == true,
            let sessionID = UUID(uuidString: result.sessionID) else {
        throw AccountSetupError.unavailable
      }
      return WorkoutRepository.PreviousPerformanceSnapshot(
        sessionID: sessionID,
        exerciseKey: result.exerciseKey,
        programID: result.programKey,
        workoutID: result.workoutKey,
        slotID: result.slotKey,
        weightInput: result.weight,
        repsInput: String(result.reps),
        weightUnit: unit,
        completedAt: result.completedAt,
        workoutName: result.workoutName,
        week: result.weekNumber,
        day: nil
      )
    }
  }
}

private struct PreviousPerformanceResponse: Decodable {
  let results: [Result]

  struct Result: Decodable {
    let exerciseKey: String
    let programKey: String
    let workoutKey: String
    let slotKey: String
    let weekNumber: Int
    let workoutName: String
    let weight: String
    let unit: String
    let reps: Int
    let completedAt: Date
    let sessionID: String
  }
}

@MainActor
struct PreviewPreviousPerformanceService: PreviousPerformanceService {
  let results: [WorkoutRepository.PreviousPerformanceSnapshot]
  let fails: Bool

  init(results: [WorkoutRepository.PreviousPerformanceSnapshot] = [], fails: Bool = false) {
    self.results = results
    self.fails = fails
  }

  func lookup(for user: AuthenticatedUser) async throws -> [WorkoutRepository.PreviousPerformanceSnapshot] {
    if fails { throw AccountSetupError.unavailable }
    return results
  }
}
