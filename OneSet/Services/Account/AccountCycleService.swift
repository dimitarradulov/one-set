import Foundation

struct CyclePreference: Codable, Equatable, Sendable {
  let workoutExerciseID: String
  let exerciseID: String?
  let note: String?
  let restSeconds: Int?

  enum CodingKeys: String, CodingKey {
    case workoutExerciseID = "workout_exercise_id"
    case exerciseID = "exercise_id"
    case note
    case restSeconds = "rest_seconds"
  }

  init(workoutExerciseID: String, exerciseID: String?, note: String?, restSeconds: Int?) {
    self.workoutExerciseID = workoutExerciseID
    self.exerciseID = exerciseID
    self.note = note
    self.restSeconds = restSeconds
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    workoutExerciseID = try container.decode(String.self, forKey: .workoutExerciseID)
    exerciseID = try container.decode(String?.self, forKey: .exerciseID)
    note = try container.decode(String?.self, forKey: .note)
    restSeconds = try container.decode(Int?.self, forKey: .restSeconds)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(workoutExerciseID, forKey: .workoutExerciseID)
    try container.encode(exerciseID, forKey: .exerciseID)
    try container.encode(note, forKey: .note)
    try container.encode(restSeconds, forKey: .restSeconds)
  }
}

/// A fixed cycle identity and its original start time, preserved across retries.
struct AccountCycle: Codable, Equatable, Sendable {
  let cycleID: UUID
  let programID: TrainingProgram.ID
  let startedAt: String
  var preferenceSourceCycleID: UUID? = nil
  var preferences: [CyclePreference]? = []

  enum CodingKeys: String, CodingKey {
    case cycleID = "cycle_id"
    case programID = "program_id"
    case startedAt = "started_at"
    case preferenceSourceCycleID = "preference_source_cycle_id"
    case preferences
  }
}

/// A successful lookup is a complete list of the account's latest cycles, not a partial cache.
struct AccountCycles: Decodable, Equatable, Sendable {
  let cycles: [AccountCycle]
  let selectedCycleID: UUID?

  enum CodingKeys: String, CodingKey {
    case cycles
    case selectedCycleID = "selected_cycle_id"
  }

  init(cycles: [AccountCycle], selectedCycleID: UUID?) {
    self.cycles = cycles
    self.selectedCycleID = selectedCycleID
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    cycles = try container.decode([AccountCycle].self, forKey: .cycles)
    selectedCycleID = try container.decode(UUID?.self, forKey: .selectedCycleID)
    guard cycles.allSatisfy({ $0.preferences != nil }),
          Set(cycles.map(\.programID)).count == cycles.count,
          Set(cycles.map(\.cycleID)).count == cycles.count,
          selectedCycleID.map({ id in cycles.contains { $0.cycleID == id } }) ?? true else {
      throw DecodingError.dataCorruptedError(forKey: .cycles, in: container,
        debugDescription: "Cycle lookup is inconsistent.")
    }
  }
}

enum AccountCycleError: Error, Equatable {
  case authenticationRequired
  case forbidden
  case programUnavailable
  case conflict
  case invalidCycle
  case unavailable
}

@MainActor
protocol AccountCycleService {
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws
}
