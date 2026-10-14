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
    guard Self.isStableKey(key), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          recommendedWeeks > 0,
          !format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !emphasis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !workouts.isEmpty else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    let visibleWorkouts = try workouts.filter { $0.removed != true }.map { workout in
      guard Self.isStableKey(workout.key), !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !workout.exercises.isEmpty else {
        throw ProgramCatalogServiceError.invalidResponse
      }
      let slots = try workout.exercises.filter { $0.removed != true }.map { slot in
        guard Self.isStableKey(slot.key), let exercise = exercises[slot.exercise],
              Self.isStableKey(exercise.key),
              !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.stoppingGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.warmupGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              exercise.restSeconds > 0,
              exercise.videoKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true,
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
    guard (1...5).contains(visibleWorkouts.count) else {
      throw ProgramCatalogServiceError.invalidResponse
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

  private static func isStableKey(_ value: String) -> Bool {
    !value.isEmpty && value.range(of: #"^[a-z0-9][a-z0-9_-]*$"#, options: .regularExpression) != nil
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
