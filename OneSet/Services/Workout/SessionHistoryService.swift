import Foundation

struct SessionHistoryPage: Sendable {
  let sessions: [WorkoutSession]
  let nextCursor: String?
  let hasMore: Bool
}

struct SessionHistoryCoverage: Sendable, Equatable {
  let nextCursor: String?
  let hasMore: Bool
  let hasLoadedPage: Bool
}

@MainActor
protocol SessionHistoryService {
  func fetchPage(for user: AuthenticatedUser, cursor: String?) async throws -> SessionHistoryPage
}

enum SessionHistoryServiceError: Error, LocalizedError {
  case unavailable
  case authenticationRequired
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .unavailable: "History is temporarily unavailable. Try again."
    case .authenticationRequired: "Sign in again to load account history."
    case .invalidResponse: "History couldn’t be read. Try again."
    }
  }
}

@MainActor
struct HTTPSessionHistoryService: SessionHistoryService {
  let authentication: ClerkAuthenticationService
  let pageSize: Int

  init(authentication: ClerkAuthenticationService, pageSize: Int = 25) {
    self.authentication = authentication
    self.pageSize = min(max(pageSize, 1), 50)
  }

  func fetchPage(for user: AuthenticatedUser, cursor: String?) async throws -> SessionHistoryPage {
    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "OneSetAPIBaseURL") as? String,
          let baseURL = URL(string: baseURLString), baseURL.scheme == "https", baseURL.host != nil else {
      throw SessionHistoryServiceError.unavailable
    }
    let token = try await authentication.sessionToken(for: user)
    var components = URLComponents(url: baseURL.appending(path: "v1/sessions"), resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "limit", value: String(pageSize))]
    if let cursor { components?.queryItems?.append(URLQueryItem(name: "cursor", value: cursor)) }
    guard let url = components?.url else { throw SessionHistoryServiceError.unavailable }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw SessionHistoryServiceError.unavailable }
    guard response.statusCode == 200 else {
      if response.statusCode == 401 { throw SessionHistoryServiceError.authenticationRequired }
      throw SessionHistoryServiceError.unavailable
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = formatter.date(from: value) { return date }
      formatter.formatOptions = [.withInternetDateTime]
      guard let date = formatter.date(from: value) else { throw SessionHistoryServiceError.invalidResponse }
      return date
    }

    let responseBody: SessionHistoryResponse
    do {
      responseBody = try decoder.decode(SessionHistoryResponse.self, from: data)
    } catch {
      throw SessionHistoryServiceError.invalidResponse
    }
    guard responseBody.hasMore == (responseBody.nextCursor != nil) else {
      throw SessionHistoryServiceError.invalidResponse
    }
    let sessions = try responseBody.sessions.map { try $0.workoutSession(accountID: user.id) }
    return SessionHistoryPage(
      sessions: sessions, nextCursor: responseBody.nextCursor, hasMore: responseBody.hasMore
    )
  }
}

private struct SessionHistoryResponse: Decodable {
  let sessions: [RemoteSession]
  let nextCursor: String?
  let hasMore: Bool

  enum CodingKeys: String, CodingKey {
    case sessions
    case nextCursor = "next_cursor"
    case hasMore = "has_more"
  }
}

private struct RemoteSession: Decodable {
  let sessionID: UUID
  let cycleID: UUID
  let programKey: String
  let programName: String
  let workoutKey: String
  let weekNumber: Int
  let dayNumber: Int?
  let workoutName: String
  let startedAt: Date
  let completedAt: Date
  let note: String?
  let sets: [RemoteSet]

  enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
    case cycleID = "cycle_id"
    case programKey = "program_key"
    case programName = "program_name"
    case workoutKey = "workout_key"
    case weekNumber = "week_number"
    case dayNumber = "day_number"
    case workoutName = "workout_name"
    case startedAt = "started_at"
    case completedAt = "completed_at"
    case note, sets
  }

  func workoutSession(accountID: String) throws -> WorkoutSession {
    guard !sets.isEmpty, weekNumber > 0,
          let weightUnit = sets.first.flatMap({ WeightUnit(rawValue: $0.unit) }) else {
      throw SessionHistoryServiceError.invalidResponse
    }
    let orderedSets = sets.sorted { $0.position < $1.position }
    guard orderedSets.enumerated().allSatisfy({ index, set in
      set.position == index + 1 && WeightUnit(rawValue: set.unit) != nil
        && (set.completedAt == nil ? set.weight == nil && set.reps == nil
          : set.weight != nil && set.reps.map { $0 > 0 } == true)
    }) else { throw SessionHistoryServiceError.invalidResponse }

    var exercises: [WorkoutSession.Exercise] = []
    for set in orderedSets {
      guard let scope = set.prescription.repScopeValue else {
        throw SessionHistoryServiceError.invalidResponse
      }
      exercises.append(WorkoutSession.Exercise(
        slotID: set.workoutExerciseKey,
        exerciseKey: set.exerciseKey,
        name: set.prescription.name,
        order: set.position - 1,
        repTarget: RepTarget(
          minimum: set.prescription.repsMin,
          maximum: set.prescription.repsMax,
          scope: scope
        ),
        instructions: set.prescription.instructions,
        stoppingGuidance: set.prescription.stoppingGuidance,
        warmupGuidance: set.prescription.warmupGuidance.note,
        warmupSteps: set.prescription.warmupGuidance.steps,
        restSeconds: set.prescription.restSeconds,
        videoKey: set.prescription.videoKey
      ))
    }
    var entries: [String: WorkoutSession.SetEntry] = [:]
    for set in orderedSets {
      let unit = WeightUnit(rawValue: set.unit) ?? weightUnit
      entries[set.workoutExerciseKey] = WorkoutSession.SetEntry(
        weightInput: set.weight ?? "",
        repsInput: set.reps.map(String.init) ?? "",
        completedAt: set.completedAt,
        recordedWeightUnit: unit
      )
    }
    return WorkoutSession(
      id: sessionID,
      accountID: accountID,
      cycleID: cycleID,
      programID: programKey,
      resolvedProgramName: programName,
      week: weekNumber,
      workoutID: workoutKey,
      dayNumber: dayNumber,
      workoutName: workoutName,
      startedAt: startedAt,
      finishedAt: completedAt,
      note: note,
      exercises: exercises,
      setEntries: entries,
      weightUnit: weightUnit
    )
  }
}

private struct RemoteSet: Decodable {
  let workoutExerciseKey: String
  let exerciseKey: String
  let position: Int
  let prescription: Prescription
  let weight: String?
  let unit: String
  let reps: Int?
  let completedAt: Date?

  enum CodingKeys: String, CodingKey {
    case workoutExerciseKey = "workout_exercise_key"
    case exerciseKey = "exercise_key"
    case position, prescription, weight, unit, reps
    case completedAt = "completed_at"
  }

  struct Prescription: Decodable {
    let name: String
    let instructions: String
    let stoppingGuidance: String
    let warmupGuidance: WarmupGuidance
    let videoKey: String?
    let repsMin: Int
    let repsMax: Int
    let repScope: String
    let restSeconds: Int?

    enum CodingKeys: String, CodingKey {
      case name, instructions
      case stoppingGuidance = "stopping_guidance"
      case warmupGuidance = "warmup_guidance"
      case videoKey = "video_key"
      case repsMin = "reps_min"
      case repsMax = "reps_max"
      case repScope = "rep_scope"
      case restSeconds = "rest_seconds"
    }

    var repScopeValue: RepTarget.Scope? {
      switch repScope {
      case "reps": .reps
      case "each_leg": .eachLeg
      case "each_side": .eachSide
      default: nil
      }
    }
  }

  struct WarmupGuidance: Decodable {
    let steps: [String]
    let note: String
  }
}

@MainActor
struct PreviewSessionHistoryService: SessionHistoryService {
  let pages: [[WorkoutSession]]
  let failsInitial: Bool
  let failsOlder: Bool

  init(pages: [[WorkoutSession]] = [], failsInitial: Bool = false, failsOlder: Bool = false) {
    self.pages = pages
    self.failsInitial = failsInitial
    self.failsOlder = failsOlder
  }

  func fetchPage(for user: AuthenticatedUser, cursor: String?) async throws -> SessionHistoryPage {
    if cursor == nil, failsInitial { throw URLError(.notConnectedToInternet) }
    if cursor != nil, failsOlder { throw URLError(.notConnectedToInternet) }
    let index = cursor == nil ? 0 : 1
    guard pages.indices.contains(index) else {
      return SessionHistoryPage(sessions: [], nextCursor: nil, hasMore: false)
    }
    let hasMore = index + 1 < pages.count || (index == 0 && failsOlder)
    return SessionHistoryPage(
      sessions: pages[index], nextCursor: hasMore ? "preview-history-\(index + 1)" : nil,
      hasMore: hasMore
    )
  }
}
