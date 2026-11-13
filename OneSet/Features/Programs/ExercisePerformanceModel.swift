import Foundation
import Observation

@MainActor
@Observable
final class ExercisePerformanceModel {
  struct Result: Identifiable {
    let session: WorkoutSession
    let slotID: String
    let weight: Double
    let reps: Int
    let date: Date
    var id: String { "\(session.id.uuidString):\(slotID)" }
  }

  private(set) var results: [Result] = []
  private(set) var isLoading = false
  private(set) var error: String?
  let unit: WeightUnit
  private let exerciseKey: String
  private let loadLocal: @MainActor () throws -> [WorkoutSession]
  private let fetchPage: (@MainActor (String?) async throws -> SessionHistoryPage)?
  private let resolveProgramName: @MainActor (String) -> String?
  private let pendingIDs: @MainActor () throws -> Set<UUID>
  private let cacheSessions: @MainActor ([WorkoutSession]) throws -> Void
  private let isCurrent: @MainActor () -> Bool

  init(exerciseKey: String, unit: WeightUnit, loadLocal: @escaping @MainActor () throws -> [WorkoutSession],
       fetchPage: (@MainActor (String?) async throws -> SessionHistoryPage)?,
       resolveProgramName: @escaping @MainActor (String) -> String? = { _ in nil },
       pendingIDs: @escaping @MainActor () throws -> Set<UUID> = { [] },
       cacheSessions: @escaping @MainActor ([WorkoutSession]) throws -> Void = { _ in },
       isCurrent: @escaping @MainActor () -> Bool) {
    self.exerciseKey = exerciseKey
    self.unit = unit
    self.loadLocal = loadLocal
    self.fetchPage = fetchPage
    self.resolveProgramName = resolveProgramName
    self.pendingIDs = pendingIDs
    self.cacheSessions = cacheSessions
    self.isCurrent = isCurrent
  }

  func reload() async {
    guard !isLoading else { return }
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      let local = try loadLocal()
      let initiallyPending = try pendingIDs()
      results = makeResults(local)
      guard let fetchPage else { return }
      var remote: [WorkoutSession] = []
      var cursor: String?
      var seen = Set<String>()
      repeat {
        let page = try await fetchPage(cursor)
        guard isCurrent(), !Task.isCancelled else { return }
        try cacheSessions(page.sessions)
        remote.append(contentsOf: page.sessions)
        results = makeResults(try loadLocal())
        cursor = page.nextCursor
        if let cursor, !seen.insert(cursor).inserted { throw SessionHistoryServiceError.invalidResponse }
      } while cursor != nil
      guard isCurrent() else { return }
      // Local sessions take precedence over uploaded copies, including pending changes.
      let latestLocal = try loadLocal()
      let remoteIDs = Set(remote.map(\.id))
      let protectedIDs = initiallyPending.union(try pendingIDs())
      let localResults = latestLocal.filter { remoteIDs.contains($0.id) || protectedIDs.contains($0.id) }
      let localIDs = Set(localResults.map(\.id))
      results = makeResults(localResults + remote.filter { !localIDs.contains($0.id) })
    } catch {
      guard isCurrent(), !Task.isCancelled else { return }
      if let local = try? loadLocal() { results = makeResults(local) }
      self.error = "Some past results may be unavailable. Try again."
    }
  }

  private func makeResults(_ sessions: [WorkoutSession]) -> [Result] {
    sessions.flatMap { session -> [Result] in
      guard session.finishedAt != nil else { return [] }
      return session.exercises.compactMap { exercise in
        guard exercise.exerciseKey == exerciseKey, let entry = session.setEntries[exercise.slotID],
              let date = entry.completedAt, let weight = Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
              weight.isFinite, weight >= 0, let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else { return nil }
        let source = (entry.recordedWeightUnit ?? session.weightUnit) == .kilograms ? UnitMass.kilograms : UnitMass.pounds
        let target = unit == .kilograms ? UnitMass.kilograms : UnitMass.pounds
        return Result(session: session, slotID: exercise.slotID,
                      weight: Measurement(value: weight, unit: source).converted(to: target).value, reps: reps, date: date)
      }
    }.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
  }

  func programName(for session: WorkoutSession) -> String {
    session.resolvedProgramName ?? resolveProgramName(session.programID) ?? "Unavailable program"
  }

  var heaviest: Result? { results.max { $0.weight < $1.weight } }
  var estimatedMaximum: Double? { results.filter { $0.reps <= 10 }.map { $0.weight * (1 + Double($0.reps) / 30) }.max() }
  func weight(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit.rawValue)" }
}
