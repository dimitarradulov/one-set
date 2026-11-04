import Foundation

/// Serializes durable cycle creation and activation independently of screen lifetime.
@MainActor
final class ProgramCycleSyncCoordinator {
  private var uploadingGeneration: Int?

  func upload(
    user: AuthenticatedUser, generation: Int, at date: Date, publicationID: String?,
    service: any AccountCycleService, store: any OnboardingProgressStore,
    current: @MainActor () -> OnboardingProgress?,
    didSave: @MainActor (OnboardingProgress) -> Void,
    authenticationRequired: @MainActor () -> Void,
    creationAcknowledged: @MainActor () async -> Void
  ) async {
    guard uploadingGeneration != generation else { return }
    uploadingGeneration = generation
    defer { if uploadingGeneration == generation { uploadingGeneration = nil } }

    func save(_ progress: OnboardingProgress) throws {
      try store.save(progress, accountID: user.id)
      didSave(progress)
    }

    while let state = current()?.cycles {
      let rejectedCreations = Set(state.rejectedCycleIDs ?? [])
      let rejectedActivations = Set(state.rejectedActivationIDs ?? []).union(rejectedCreations)
      let pendingCycleIDs = Set(state.pendingCreations.map(\.cycleID))
      let creation = state.pendingCreations.first {
        !rejectedCreations.contains($0.cycleID)
          && ($0.preferenceSourceCycleID.map { !pendingCycleIDs.contains($0) } ?? true)
      }
      let activation = state.pendingActivations?.first { !rejectedActivations.contains($0) && !pendingCycleIDs.contains($0) }
      guard let cycleID = creation?.cycleID ?? activation else { break }
      let operation = "\(creation == nil ? "activate" : "create"):\(cycleID.uuidString)"
      if let retry = state.retry, retry.operation == operation, retry.retryAfter > date { return }
      do {
        if let creation {
          try await service.create(creation, for: user)
        } else {
          try await service.activate(cycleID, for: user)
        }
        guard var progress = current(), var latest = progress.cycles else { return }
        if creation != nil {
          guard let index = latest.pendingCreations.firstIndex(where: { $0.cycleID == cycleID }) else { return }
          latest.pendingCreations.remove(at: index)
        } else {
          guard let index = latest.pendingActivations?.firstIndex(of: cycleID) else { return }
          latest.pendingActivations?.remove(at: index)
        }
        latest.retry = nil
        progress.cycles = latest
        try save(progress)
        if creation != nil { await creationAcknowledged() }
      } catch {
        guard var progress = current(), var latest = progress.cycles else { return }
        if let failure = error as? AccountCycleError, failure != .unavailable {
          if failure == .programUnavailable {
            var rejected = latest.unavailableAtPublication ?? [:]
            rejected[cycleID.uuidString] = publicationID ?? ""
            latest.unavailableAtPublication = rejected
          }
          if failure == .authenticationRequired {
            latest.authenticationDeferred = true
            authenticationRequired()
          } else if creation != nil {
            latest.rejectedCycleIDs = (latest.rejectedCycleIDs ?? []) + [cycleID]
          } else {
            latest.rejectedActivationIDs = (latest.rejectedActivationIDs ?? []) + [cycleID]
          }
          progress.cycles = latest
          do { try save(progress) } catch { return }
          if failure != .authenticationRequired { continue }
        } else {
          let attempts = (latest.retry?.operation == operation ? latest.retry?.attempts ?? 0 : 0) + 1
          latest.retry = CycleRetryState(operation: operation, attempts: attempts,
            retryAfter: CompletedSessionUploadRetryPolicy.retryDate(afterAttempt: attempts, at: date))
          progress.cycles = latest
          try? save(progress)
        }
        return
      }
    }
  }
}
