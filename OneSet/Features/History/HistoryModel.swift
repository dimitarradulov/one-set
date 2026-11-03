import Foundation
import Observation

enum HistoryDataError: Error, LocalizedError {
  case accountUnavailable
  case storageUnavailable

  var errorDescription: String? {
    switch self {
    case .accountUnavailable: "History is unavailable for the current account."
    case .storageUnavailable: "Workout storage is unavailable on this device."
    }
  }
}

@MainActor
@Observable
final class HistoryModel {
  struct Month: Identifiable {
    let start: Date
    let title: String
    let sessions: [WorkoutSession]

    var id: Date { start }
  }

  private(set) var sessions: [WorkoutSession] = []
  private(set) var isLoading = false
  private(set) var loadError: String?
  private(set) var calendarRevision = 0
  private var loadGeneration = 0

  let accountID: String
  let displayUnit: WeightUnit
  private let loadSessions: @MainActor (String) throws -> [WorkoutSession]
  private let resolveProgramName: @MainActor (String) -> String?

  init(
    accountID: String,
    displayUnit: WeightUnit,
    loadSessions: @escaping @MainActor (String) throws -> [WorkoutSession],
    resolveProgramName: @escaping @MainActor (String) -> String?
  ) {
    self.accountID = accountID
    self.displayUnit = displayUnit
    self.loadSessions = loadSessions
    self.resolveProgramName = resolveProgramName
  }

  func reload() async {
    loadGeneration += 1
    let generation = loadGeneration
    isLoading = true
    loadError = nil
    defer {
      if generation == loadGeneration { isLoading = false }
    }
    await Task.yield()
    guard generation == loadGeneration else { return }
    do {
      let loaded = try loadSessions(accountID)
        .filter { $0.accountID == accountID && $0.finishedAt != nil
          && completedExerciseCount(for: $0) > 0 }
        .sorted {
          if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
          return $0.id.uuidString > $1.id.uuidString
        }
      guard generation == loadGeneration else { return }
      sessions = loaded
    } catch {
      guard generation == loadGeneration else { return }
      loadError = error.localizedDescription
    }
  }

  func refreshCalendarContext() {
    calendarRevision += 1
  }

  func session(id: UUID) -> WorkoutSession? {
    sessions.first { $0.id == id }
  }

  func programName(for session: WorkoutSession) -> String {
    resolveProgramName(session.programID) ?? "Unavailable program"
  }

  func completedExerciseCount(for session: WorkoutSession) -> Int {
    session.exercises.filter { exercise in
      guard let entry = session.setEntries[exercise.slotID], entry.completedAt != nil,
            let weight = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
            weight.isFinite, weight >= 0,
            let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
      return reps > 0
    }.count
  }

  func months(calendar: Calendar = .current) -> [Month] {
    _ = calendarRevision
    let grouped = Dictionary(grouping: sessions) { session in
      calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? session.startedAt
    }
    return grouped.keys.sorted(by: >).compactMap { start in
      guard let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
      let title = interval.start.formatted(.dateTime.month(.wide).year())
      return Month(start: start, title: title, sessions: grouped[start] ?? [])
    }
  }

  func formattedWeight(_ entry: WorkoutSession.SetEntry, in session: WorkoutSession) -> String? {
    guard let value = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
          value.isFinite, value >= 0 else { return nil }
    guard session.weightUnit != displayUnit else {
      return "\(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)) \(displayUnit.rawValue)"
    }
    let source = session.weightUnit == .kilograms ? UnitMass.kilograms : UnitMass.pounds
    let target = displayUnit == .kilograms ? UnitMass.kilograms : UnitMass.pounds
    let converted = Measurement(value: value, unit: source).converted(to: target).value
    return "\(converted.formatted(.number.precision(.fractionLength(0...2)))) \(displayUnit.rawValue)"
  }

  func duration(for session: WorkoutSession) -> String {
    guard let finishedAt = session.finishedAt else { return "Duration unavailable" }
    let seconds = max(0, finishedAt.timeIntervalSince(session.startedAt))
    let components = DateComponentsFormatter()
    components.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute]
    components.unitsStyle = .abbreviated
    return components.string(from: seconds) ?? "0 min"
  }
}
