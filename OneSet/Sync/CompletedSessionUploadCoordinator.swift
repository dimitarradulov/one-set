import Foundation

@MainActor
final class CompletedSessionUploadCoordinator {
  private struct DrainRequest {
    let user: AuthenticatedUser
    let isCurrent: @MainActor () -> Bool
    let date: Date
    let blockedCycleIDs: Set<UUID>
  }

  private let repository: WorkoutRepository
  private let service: any CompletedSessionUploadService
  private let waitForRetry: @MainActor (TimeInterval) async throws -> Void
  private var isDraining = false
  private var drainingAccountID: String?
  private var suspendedAccountIDs: Set<String> = []
  private var drainWaiters: [CheckedContinuation<Void, Never>] = []
  private var queuedDrain: DrainRequest?
  private var retryTask: Task<Void, Never>?
  private var scheduledRetryAccountID: String?
  private var scheduledRetryAt: Date?

  init(
    repository: WorkoutRepository,
    service: any CompletedSessionUploadService,
    waitForRetry: @escaping @MainActor (TimeInterval) async throws -> Void
  ) {
    self.repository = repository
    self.service = service
    self.waitForRetry = waitForRetry
  }

  func drain(
    for user: AuthenticatedUser,
    whileCurrent isCurrent: @escaping @MainActor () -> Bool,
    at date: Date,
    scheduleRetries: Bool,
    blockedCycleIDs: Set<UUID> = []
  ) async {
    // Recheck the captured account generation after each suspended upload before mutating its queue.
    let request = DrainRequest(user: user, isCurrent: isCurrent, date: date, blockedCycleIDs: blockedCycleIDs)
    guard isCurrent() else {
      cancelRetry()
      return
    }
    guard !suspendedAccountIDs.contains(user.id) else { return }
    if isDraining {
      queuedDrain = request
      return
    }

    isDraining = true
    drainingAccountID = user.id
    defer { finishDrain(request, scheduleRetries: scheduleRetries) }

    guard let entries = try? repository.sessionUploadQueue(accountID: user.id) else { return }
    for entry in entries {
      guard !Task.isCancelled, isCurrent(), !suspendedAccountIDs.contains(user.id) else { return }
      guard Self.isEligible(entry, at: date, blockedCycleIDs: blockedCycleIDs) else { continue }
      guard await upload(entry, request: request) == .next else { return }
    }
  }

  private enum EntryOutcome {
    /// Move on to the next queued entry.
    case next
    /// Stop draining: the account changed or uploads must wait for authentication.
    case stop
  }

  /// Ends a drain: wakes suspended callers, schedules a retry, and starts any drain queued meanwhile.
  private func finishDrain(_ request: DrainRequest, scheduleRetries: Bool) {
    isDraining = false
    drainingAccountID = nil
    let waiters = drainWaiters
    drainWaiters = []
    waiters.forEach { $0.resume() }
    if scheduleRetries, !suspendedAccountIDs.contains(request.user.id) {
      scheduleRetry(for: request)
    }
    if let queuedDrain {
      self.queuedDrain = nil
      Task { [weak self] in
        await self?.drain(
          for: queuedDrain.user,
          whileCurrent: queuedDrain.isCurrent,
          at: queuedDrain.date,
          scheduleRetries: true,
          blockedCycleIDs: queuedDrain.blockedCycleIDs
        )
      }
    }
  }

  /// An entry uploads now unless its cycle is blocked, it failed permanently, it waits for
  /// authentication, or its retry time has not come.
  private static func isEligible(_ entry: CompletedSessionUploadQueueEntry, at date: Date, blockedCycleIDs: Set<UUID>) -> Bool {
    if !blockedCycleIDs.isEmpty {
      guard let cycleID = try? JSONDecoder().decode(UploadCycleReference.self, from: entry.upload.body).cycleID,
            !blockedCycleIDs.contains(cycleID) else { return false }
    }
    return entry.permanentFailure == nil && !entry.isAuthenticationDeferred
      && (entry.retryAfter.map { $0 <= date } ?? true)
  }

  private func upload(_ entry: CompletedSessionUploadQueueEntry, request: DrainRequest) async -> EntryOutcome {
    let user = request.user
    do {
      try await service.upload(entry.upload, for: user)
    } catch let error as CompletedSessionUploadError {
      guard request.isCurrent() else { return .stop }
      return handle(error, for: entry, request: request)
    } catch {
      guard request.isCurrent() else { return .stop }
      recordTransientFailure(for: entry, accountID: user.id, at: request.date)
      return .next
    }

    guard request.isCurrent() else { return .stop }
    do {
      try repository.acknowledgeSessionUpload(sessionID: entry.upload.sessionID, accountID: user.id)
    } catch {
      recordTransientFailure(for: entry, accountID: user.id, at: request.date)
    }
    return .next
  }

  private func handle(
    _ error: CompletedSessionUploadError, for entry: CompletedSessionUploadQueueEntry, request: DrainRequest
  ) -> EntryOutcome {
    let accountID = request.user.id
    let sessionID = entry.upload.sessionID
    switch error {
    case .authenticationRequired:
      try? repository.deferUploadUntilAuthenticationRestored(sessionID: sessionID, accountID: accountID)
      return .stop
    case .forbidden:
      return reject(sessionID, accountID: accountID, reason: .forbidden)
    case .conflict:
      return reject(sessionID, accountID: accountID, reason: .conflict)
    case .invalidSession:
      return reject(sessionID, accountID: accountID, reason: .invalidSession)
    case .temporary(let serverRetryAt):
      recordTransientFailure(for: entry, accountID: accountID, at: request.date, serverRetryAt: serverRetryAt)
      return .next
    }
  }

  /// Marks the upload as permanently rejected. A storage failure stops the drain.
  private func reject(_ sessionID: UUID, accountID: String, reason: CompletedSessionUploadRejection) -> EntryOutcome {
    (try? repository.rejectSessionUpload(sessionID: sessionID, accountID: accountID, reason: reason)) != nil
      ? .next : .stop
  }

  /// Stops all upload requests for the account. A request already on the wire finishes first, and
  /// no further request goes out for the account until `resume(accountID:)`. Queued records are kept.
  func suspend(accountID: String) async {
    suspendedAccountIDs.insert(accountID)
    if queuedDrain?.user.id == accountID { queuedDrain = nil }
    if scheduledRetryAccountID == accountID { cancelRetry() }
    while isDraining, drainingAccountID == accountID {
      await withCheckedContinuation { drainWaiters.append($0) }
    }
  }

  /// Lets the account upload again. Callers trigger the next drain; queued records are untouched.
  func resume(accountID: String) {
    suspendedAccountIDs.remove(accountID)
  }

  // Clears queued drains and future retries. The caller invalidates any in-flight request through `isCurrent`.
  func cancelPendingWork() {
    queuedDrain = nil
    cancelRetry()
  }

  private func recordTransientFailure(
    for entry: CompletedSessionUploadQueueEntry,
    accountID: String,
    at date: Date,
    serverRetryAt: Date? = nil
  ) {
    let retryAt = CompletedSessionUploadRetryPolicy.retryDate(
      afterAttempt: entry.attemptCount + 1, at: date, serverRetryAt: serverRetryAt
    )
    try? repository.recordTransientUploadFailure(
      sessionID: entry.upload.sessionID, accountID: accountID, retryAt: retryAt
    )
  }

  private func scheduleRetry(for request: DrainRequest) {
    guard request.isCurrent(), !suspendedAccountIDs.contains(request.user.id),
          let entries = try? repository.sessionUploadQueue(accountID: request.user.id) else {
      cancelRetry()
      return
    }
    let nextRetry = entries
      .filter { $0.permanentFailure == nil && !$0.isAuthenticationDeferred }
      .compactMap(\.retryAfter)
      .min()
    guard let nextRetry, nextRetry > request.date else {
      cancelRetry()
      return
    }
    if scheduledRetryAccountID == request.user.id, scheduledRetryAt == nextRetry,
       retryTask != nil { return }

    cancelRetry()
    let delay = nextRetry.timeIntervalSince(request.date)
    let wait = waitForRetry
    scheduledRetryAccountID = request.user.id
    scheduledRetryAt = nextRetry
    retryTask = Task { @MainActor [weak self] in
      do { try await wait(delay) } catch { return }
      guard !Task.isCancelled, let self,
            self.scheduledRetryAccountID == request.user.id,
            self.scheduledRetryAt == nextRetry,
            request.isCurrent(), !self.suspendedAccountIDs.contains(request.user.id) else { return }
      self.retryTask = nil
      self.scheduledRetryAccountID = nil
      self.scheduledRetryAt = nil
      await self.drain(
        for: request.user,
        whileCurrent: request.isCurrent,
        at: nextRetry,
        scheduleRetries: true,
        blockedCycleIDs: request.blockedCycleIDs
      )
    }
  }

  private func cancelRetry() {
    retryTask?.cancel()
    retryTask = nil
    scheduledRetryAccountID = nil
    scheduledRetryAt = nil
  }
}

/// The cycle a queued upload belongs to, read from its request body.
private struct UploadCycleReference: Decodable {
  let cycleID: UUID
  enum CodingKeys: String, CodingKey { case cycleID = "cycle_id" }
}
