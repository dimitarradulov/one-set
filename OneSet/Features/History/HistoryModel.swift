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
  private(set) var hasLoadedAccountHistory = false
  private(set) var hasMoreHistory = false
  private(set) var isLoadingOlder = false
  private(set) var olderPageError: String?
  private(set) var isOfflineOlderBoundary = false
  private(set) var isAtEndOfArchive = false
  private(set) var calendarRevision = 0
  private var loadGeneration = 0
  private var olderRequestGeneration = 0
  private var wantsOfflineBoundaryPreview = false
  private var coverage = SessionHistoryCoverage(nextCursor: nil, hasMore: false, hasLoadedPage: false)

  let accountID: String
  let displayUnit: WeightUnit
  private let loadSessions: @MainActor (String) throws -> [WorkoutSession]
  private let resolveProgramName: @MainActor (String) -> String?
  private let loadCoverage: (@MainActor (String) throws -> SessionHistoryCoverage)?
  private let savePage: (@MainActor (SessionHistoryPage, String) throws -> Void)?
  private let fetchPage: (@MainActor (String?) async throws -> SessionHistoryPage)?
  private let isAccountCurrent: @MainActor () -> Bool

  init(
    accountID: String,
    displayUnit: WeightUnit,
    loadSessions: @escaping @MainActor (String) throws -> [WorkoutSession],
    resolveProgramName: @escaping @MainActor (String) -> String?,
    loadCoverage: (@MainActor (String) throws -> SessionHistoryCoverage)? = nil,
    savePage: (@MainActor (SessionHistoryPage, String) throws -> Void)? = nil,
    fetchPage: (@MainActor (String?) async throws -> SessionHistoryPage)? = nil,
    isAccountCurrent: @escaping @MainActor () -> Bool = { true }
  ) {
    self.accountID = accountID
    self.displayUnit = displayUnit
    self.loadSessions = loadSessions
    self.resolveProgramName = resolveProgramName
    self.loadCoverage = loadCoverage
    self.savePage = savePage
    self.fetchPage = fetchPage
    self.isAccountCurrent = isAccountCurrent
  }

  func reload() async {
    guard !isLoading else { return }
    loadGeneration += 1
    let generation = loadGeneration
    olderRequestGeneration += 1
    isLoading = true
    loadError = nil
    olderPageError = nil
    isOfflineOlderBoundary = false
    defer {
      if generation == loadGeneration { isLoading = false }
    }
    await Task.yield()
    guard generation == loadGeneration, isAccountCurrent() else { return }
    do {
      try reloadLocalSessions()
      if let loadCoverage {
        coverage = try loadCoverage(accountID)
        hasLoadedAccountHistory = coverage.hasLoadedPage
        updateArchiveBoundary()
      }
    } catch {
      guard generation == loadGeneration else { return }
      loadError = error.localizedDescription
      return
    }

    guard let fetchPage, let savePage else { return }
    do {
      let page = try await fetchPage(nil)
      guard generation == loadGeneration, isAccountCurrent() else { return }
      try savePage(page, accountID)
      guard generation == loadGeneration, isAccountCurrent() else { return }
      coverage = try loadCoverage?(accountID)
        ?? SessionHistoryCoverage(nextCursor: page.nextCursor, hasMore: page.hasMore, hasLoadedPage: true)
      hasLoadedAccountHistory = true
      updateArchiveBoundary()
      try reloadLocalSessions()
    } catch {
      guard generation == loadGeneration, isAccountCurrent() else { return }
      loadError = error.localizedDescription
    }
  }

  func loadOlderPage() async {
    guard let fetchPage, let savePage, hasLoadedAccountHistory, hasMoreHistory,
          let cursor = coverage.nextCursor, !isLoadingOlder, isAccountCurrent() else { return }
    let currentGeneration = loadGeneration
    olderRequestGeneration += 1
    let requestGeneration = olderRequestGeneration
    isLoadingOlder = true
    olderPageError = nil
    isOfflineOlderBoundary = false
    defer {
      if requestGeneration == olderRequestGeneration { isLoadingOlder = false }
    }
    do {
      let page = try await fetchPage(cursor)
      guard requestGeneration == olderRequestGeneration,
            currentGeneration == loadGeneration,
            coverage.nextCursor == cursor,
            isAccountCurrent() else { return }
      try savePage(page, accountID)
      guard requestGeneration == olderRequestGeneration,
            currentGeneration == loadGeneration,
            isAccountCurrent() else { return }
      coverage = try loadCoverage?(accountID)
        ?? SessionHistoryCoverage(nextCursor: page.nextCursor, hasMore: page.hasMore, hasLoadedPage: true)
      updateArchiveBoundary()
      try reloadLocalSessions()
    } catch {
      guard requestGeneration == olderRequestGeneration,
            currentGeneration == loadGeneration,
            isAccountCurrent() else { return }
      if Self.isOffline(error) {
        isOfflineOlderBoundary = true
      } else {
        olderPageError = error.localizedDescription
      }
    }
  }

  func markOfflineBoundaryForPreview() {
    wantsOfflineBoundaryPreview = true
    if hasMoreHistory { isOfflineOlderBoundary = true }
  }

  private func reloadLocalSessions() throws {
    sessions = try loadSessions(accountID)
      .filter { $0.accountID == accountID && $0.finishedAt != nil
        && completedExerciseCount(for: $0) > 0 }
      .sorted {
        if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
        return $0.id.uuidString > $1.id.uuidString
      }
  }

  private func updateArchiveBoundary() {
    hasMoreHistory = coverage.hasLoadedPage && coverage.hasMore && coverage.nextCursor != nil
    isAtEndOfArchive = coverage.hasLoadedPage && !coverage.hasMore
    if wantsOfflineBoundaryPreview && hasMoreHistory { isOfflineOlderBoundary = true }
  }

  private static func isOffline(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    return [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code)
  }

  func refreshCalendarContext() {
    calendarRevision += 1
  }

  func session(id: UUID) -> WorkoutSession? {
    sessions.first { $0.id == id }
  }

  func programName(for session: WorkoutSession) -> String {
    session.resolvedProgramName ?? resolveProgramName(session.programID) ?? "Unavailable program"
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
    let recordedUnit = entry.recordedWeightUnit ?? session.weightUnit
    guard recordedUnit != displayUnit else {
      return "\(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)) \(displayUnit.rawValue)"
    }
    let source = recordedUnit == .kilograms ? UnitMass.kilograms : UnitMass.pounds
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
