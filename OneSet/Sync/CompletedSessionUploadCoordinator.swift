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
    if isDraining {
      queuedDrain = request
      return
    }

    isDraining = true
    defer {
      isDraining = false
      if scheduleRetries {
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

    guard let entries = try? repository.sessionUploadQueue(accountID: user.id) else { return }
    for entry in entries {
      guard !Task.isCancelled, isCurrent() else { return }
      struct CycleReference: Decodable { let cycle_id: UUID }
      let cycleID = try? JSONDecoder().decode(CycleReference.self, from: entry.upload.body).cycle_id
      guard blockedCycleIDs.isEmpty || (cycleID != nil && !blockedCycleIDs.contains(cycleID!)),
            entry.permanentFailure == nil, !entry.isAuthenticationDeferred,
            entry.retryAfter.map({ $0 <= date }) ?? true else { continue }

      do {
        try await service.upload(entry.upload, for: user)
      } catch let error as CompletedSessionUploadError {
        guard isCurrent() else { return }
        switch error {
        case .authenticationRequired:
          try? repository.deferUploadUntilAuthenticationRestored(
            sessionID: entry.upload.sessionID, accountID: user.id
          )
          return
        case .forbidden:
          guard (try? repository.rejectSessionUpload(
            sessionID: entry.upload.sessionID, accountID: user.id, reason: .forbidden
          )) != nil else { return }
          continue
        case .conflict:
          guard (try? repository.rejectSessionUpload(
            sessionID: entry.upload.sessionID, accountID: user.id, reason: .conflict
          )) != nil else { return }
          continue
        case .invalidSession:
          guard (try? repository.rejectSessionUpload(
            sessionID: entry.upload.sessionID, accountID: user.id, reason: .invalidSession
          )) != nil else { return }
          continue
        case .temporary(let serverRetryAt):
          recordTransientFailure(for: entry, accountID: user.id, at: date, serverRetryAt: serverRetryAt)
          continue
        }
      } catch {
        guard isCurrent() else { return }
        recordTransientFailure(for: entry, accountID: user.id, at: date)
        continue
      }

      guard isCurrent() else { return }
      do {
        try repository.acknowledgeSessionUpload(sessionID: entry.upload.sessionID, accountID: user.id)
      } catch {
        recordTransientFailure(for: entry, accountID: user.id, at: date)
      }
    }
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
    guard request.isCurrent(),
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
            request.isCurrent() else { return }
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
