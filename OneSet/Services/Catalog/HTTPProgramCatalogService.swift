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
    guard let document = envelope.catalog else { return .notModified }
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
    guard !programs.isEmpty,
          let entityTag = response.value(forHTTPHeaderField: "ETag") else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    return .snapshot(PublishedProgramCatalogSnapshot(
      publicationID: envelope.publicationId, entityTag: entityTag, programs: programs
    ))
  }
}

private enum ProgramCatalogServiceError: Error {
  case unavailable
  case invalidResponse
}

private struct CatalogEnvelope: Decodable, Sendable {
  let publicationId: String?
  let catalog: CatalogDocument?
}

private struct CatalogDocument: Decodable, Sendable {
  let exercises: [CatalogExerciseDocument]
  let programs: [CatalogProgramDocument]
}

private struct CatalogExerciseDocument: Decodable, Sendable {
  let key: String
  let name: String
  let instructions: String
  let stoppingGuidance: String
  let warmupGuidance: String
  let restSeconds: Int
  let defaultReps: CatalogRepRange
  let videoKey: String?
}

private struct CatalogProgramDocument: Decodable, Sendable {
  let key: String
  let name: String
  let recommendedWeeks: Int
  let format: String
  let emphasis: String
  let removed: Bool?
  let workouts: [CatalogWorkoutDocument]

  func model(exercises: [String: CatalogExerciseDocument]) throws -> TrainingProgram {
    guard !key.isEmpty, !name.isEmpty,
          recommendedWeeks > 0,
          !format.isEmpty, !emphasis.isEmpty else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    let visibleWorkouts = try workouts.filter { $0.removed != true }.map { workout in
      guard !workout.key.isEmpty, !workout.name.isEmpty else {
        throw ProgramCatalogServiceError.invalidResponse
      }
      let slots = try workout.exercises.filter { $0.removed != true }.map { slot in
        guard !slot.key.isEmpty, let exercise = exercises[slot.exercise],
              !exercise.name.isEmpty, !exercise.instructions.isEmpty,
              !exercise.stoppingGuidance.isEmpty, !exercise.warmupGuidance.isEmpty,
              exercise.restSeconds > 0,
              Self.valid(exercise.defaultReps), Self.valid(slot.reps) else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        let scope: RepTarget.Scope
        switch slot.scope {
        case nil, "reps": scope = .reps
        case "each_leg": scope = .eachLeg
        case "each_side": scope = .eachSide
        default: throw ProgramCatalogServiceError.invalidResponse
        }
        guard let target = RepTarget(validating: slot.reps, scope: scope),
              let defaultTarget = RepTarget(validating: exercise.defaultReps) else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        return WorkoutExercise(
          id: slot.key,
          exerciseKey: exercise.key,
          name: exercise.name,
          repTarget: target,
          instructions: exercise.instructions,
          stoppingGuidance: exercise.stoppingGuidance,
          warmupGuidance: exercise.warmupGuidance,
          restSeconds: exercise.restSeconds,
          defaultRepTarget: defaultTarget,
          videoKey: exercise.videoKey
        )
      }
      return WorkoutTemplate(id: workout.key, name: workout.name, exercises: slots)
    }
    return TrainingProgram(
      id: key,
      name: name,
      format: format,
      emphasis: emphasis,
      workouts: visibleWorkouts,
      recommendedWeeks: recommendedWeeks,
      isOffered: removed != true
    )
  }

  private static func valid(_ range: CatalogRepRange) -> Bool {
    range.minimum > 0 && range.maximum >= range.minimum && range.maximum <= 100
  }
}

private struct CatalogWorkoutDocument: Decodable, Sendable {
  let key: String
  let name: String
  let removed: Bool?
  let exercises: [CatalogSlotDocument]
}

private struct CatalogSlotDocument: Decodable, Sendable {
  let key: String
  let exercise: String
  let scope: String?
  let removed: Bool?
  let reps: CatalogRepRange
}

private struct CatalogRepRange: Decodable, Sendable {
  let minimum: Int
  let maximum: Int
}

private extension RepTarget {
  init?(validating range: CatalogRepRange, scope: Scope = .reps) {
    guard range.minimum > 0, range.maximum >= range.minimum, range.maximum <= 100 else { return nil }
    self.init(minimum: range.minimum, maximum: range.maximum, scope: scope)
  }
}

private extension JSONDecoder {
  static var catalogDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }
}
