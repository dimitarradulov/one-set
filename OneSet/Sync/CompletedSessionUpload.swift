import Foundation

struct PendingSessionUpload: Equatable, Sendable {
  let sessionID: UUID
  let accountID: String
  let body: Data
}

enum CompletedSessionUploadRejection: String, Equatable, Sendable {
  case forbidden
  case conflict
  case invalidSession
}

struct CompletedSessionUploadQueueEntry: Equatable, Sendable {
  let upload: PendingSessionUpload
  let attemptCount: Int
  let retryAfter: Date?
  let isAuthenticationDeferred: Bool
  let permanentFailure: CompletedSessionUploadRejection?
}

enum CompletedSessionUploadRetryPolicy {
  static let initialDelay: TimeInterval = 15
  static let maximumDelay: TimeInterval = 6 * 60 * 60

  static func retryDate(afterAttempt attempt: Int, at date: Date, serverRetryAt: Date? = nil) -> Date {
    let exponent = min(max(attempt - 1, 0), 16)
    let exponentialDelay = min(maximumDelay, initialDelay * pow(2, Double(exponent)))
    let serverDelay = max(serverRetryAt?.timeIntervalSince(date) ?? 0, 0)
    return date.addingTimeInterval(max(exponentialDelay, serverDelay))
  }

  static func serverRetryDate(headerValue: String?, at date: Date) -> Date? {
    guard let value = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 {
      return date.addingTimeInterval(seconds)
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
    return formatter.date(from: value)
  }
}

struct CompletedSessionUploadPayload: Encodable, Sendable {
  struct WarmupGuidance: Encodable, Sendable {
    let steps: [String] = []
    let note: String
  }

  struct Prescription: Encodable, Sendable {
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

    func encode(to encoder: Encoder) throws {
      var values = encoder.container(keyedBy: CodingKeys.self)
      try values.encode(name, forKey: .name)
      try values.encode(instructions, forKey: .instructions)
      try values.encode(stoppingGuidance, forKey: .stoppingGuidance)
      try values.encode(warmupGuidance, forKey: .warmupGuidance)
      try values.encode(videoKey, forKey: .videoKey)
      try values.encode(repsMin, forKey: .repsMin)
      try values.encode(repsMax, forKey: .repsMax)
      try values.encode(repScope, forKey: .repScope)
      try values.encode(restSeconds, forKey: .restSeconds)
    }
  }

  struct Set: Encodable, Sendable {
    let workoutExerciseKey: String
    let exerciseKey: String
    let position: Int
    let prescription: Prescription
    let weight: Double?
    let unit: String
    let reps: Int?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
      case position, prescription, weight, unit, reps
      case workoutExerciseKey = "workout_exercise_key"
      case exerciseKey = "exercise_key"
      case completedAt = "completed_at"
    }

    func encode(to encoder: Encoder) throws {
      var values = encoder.container(keyedBy: CodingKeys.self)
      try values.encode(workoutExerciseKey, forKey: .workoutExerciseKey)
      try values.encode(exerciseKey, forKey: .exerciseKey)
      try values.encode(position, forKey: .position)
      try values.encode(prescription, forKey: .prescription)
      try values.encode(weight, forKey: .weight)
      try values.encode(unit, forKey: .unit)
      try values.encode(reps, forKey: .reps)
      try values.encode(completedAt, forKey: .completedAt)
    }
  }

  let sessionID: String
  let cycleID: String
  let programKey: String
  let workoutKey: String
  let weekNumber: Int
  let workoutName: String
  let startedAt: String
  let completedAt: String
  let note: String?
  let sets: [Set]

  enum CodingKeys: String, CodingKey {
    case note, sets
    case sessionID = "session_id"
    case cycleID = "cycle_id"
    case programKey = "program_key"
    case workoutKey = "workout_key"
    case weekNumber = "week_number"
    case workoutName = "workout_name"
    case startedAt = "started_at"
    case completedAt = "completed_at"
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(sessionID, forKey: .sessionID)
    try values.encode(cycleID, forKey: .cycleID)
    try values.encode(programKey, forKey: .programKey)
    try values.encode(workoutKey, forKey: .workoutKey)
    try values.encode(weekNumber, forKey: .weekNumber)
    try values.encode(workoutName, forKey: .workoutName)
    try values.encode(startedAt, forKey: .startedAt)
    try values.encode(completedAt, forKey: .completedAt)
    try values.encode(note, forKey: .note)
    try values.encode(sets, forKey: .sets)
  }

  init(session: WorkoutSession) throws {
    guard let finishDate = session.finishedAt,
          !session.setEntries.values.allSatisfy({ $0.completedAt == nil }) else {
      throw WorkoutRepositoryError.invalidCompletedSession
    }
    sessionID = session.id.uuidString.lowercased()
    cycleID = session.cycleID.uuidString.lowercased()
    programKey = session.programID
    workoutKey = session.workoutID
    weekNumber = session.week
    workoutName = session.workoutName
    startedAt = Self.timestamp(session.startedAt)
    completedAt = Self.timestamp(finishDate)
    note = session.note
    sets = try session.exercises.enumerated().map { index, exercise in
      let result = session.setEntries[exercise.slotID]
      let isCompleted = result?.completedAt != nil
      let weight: Double?
      let reps: Int?
      if isCompleted {
        guard let input = result?.weightInput.trimmingCharacters(in: .whitespacesAndNewlines),
              let parsedWeight = Double(input), parsedWeight.isFinite,
              parsedWeight >= 0, parsedWeight <= 9_999_999.999,
              let inputReps = result?.repsInput.trimmingCharacters(in: .whitespacesAndNewlines),
              let parsedReps = Int(inputReps), parsedReps > 0,
              abs(parsedWeight * 1000 - (parsedWeight * 1000).rounded()) < 0.000_001 else {
          throw WorkoutRepositoryError.invalidCompletedSession
        }
        weight = parsedWeight
        reps = parsedReps
      } else {
        weight = nil
        reps = nil
      }
      let scope: String
      switch exercise.repTarget.scope {
      case .reps: scope = "reps"
      case .eachLeg: scope = "each_leg"
      case .eachSide: scope = "each_side"
      }
      return Set(
        workoutExerciseKey: exercise.slotID,
        exerciseKey: exercise.exerciseKey,
        position: index + 1,
        prescription: Prescription(
          name: exercise.name,
          instructions: exercise.instructions,
          stoppingGuidance: exercise.stoppingGuidance,
          warmupGuidance: WarmupGuidance(note: exercise.warmupGuidance),
          videoKey: exercise.videoKey,
          repsMin: exercise.repTarget.minimum,
          repsMax: exercise.repTarget.maximum,
          repScope: scope,
          restSeconds: exercise.restSeconds
        ),
        weight: weight,
        unit: session.weightUnit.rawValue,
        reps: reps,
        completedAt: isCompleted ? Self.timestamp(result!.completedAt!) : nil
      )
    }
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self)
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
