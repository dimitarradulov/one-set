import Foundation
import Observation

/// Pauses and restarts the account's background uploads around a deletion attempt.
@MainActor
protocol AccountDeletionUploads {
  /// Stops all upload requests for the account and waits for any request already on the wire.
  func suspend(accountID: String) async
  /// Lifts the pause only. It does not restart uploads; call `drain(for:)` afterward.
  func resume(accountID: String)
  /// Restarts uploads for the account after a resume.
  func drain(for user: AuthenticatedUser) async
}

@MainActor
protocol AccountDeletionConnectivity {
  var isOnline: Bool { get }
}

@MainActor
protocol AccountDeletionWorkoutState {
  var hasActiveWorkout: Bool { get }
  /// Completed sessions that have not uploaded yet.
  func unsyncedCompletedSessionCount(accountID: String) throws -> Int
}

@MainActor
protocol AccountDeletionLocalErasure {
  func erase(accountID: String) throws
}

@MainActor
protocol AccountDeletionSignOut {
  func signOut() async throws
}

extension LocalAccountErasure: AccountDeletionLocalErasure {}

/// Coordinates account deletion: blocking states, the unsynced warning, the upload pause, the
/// server request, and (only after the server confirms) local erasure and sign-out.
@MainActor
@Observable
final class AccountDeletionModel {
  enum Phase: Equatable {
    case ready
    case deleting
    case failed(Failure)
    case deleted
  }

  enum Failure: Equatable {
    /// The server did not confirm deletion. Nothing was erased and the account stays signed in.
    case request
    /// The server deleted the account, but erasing local data or signing out failed.
    case cleanup
  }

  enum Blocker: Equatable {
    case offline
    case activeWorkout
  }

  private(set) var phase: Phase = .ready
  private(set) var blocker: Blocker?
  private(set) var showsUnsyncedWarning = false

  var canDelete: Bool {
    blocker == nil && (phase == .ready || phase == .failed(.request))
  }

  private let user: AuthenticatedUser
  private let uploads: any AccountDeletionUploads
  private let service: any AccountDeletionService
  private let erasure: any AccountDeletionLocalErasure
  private let signOut: any AccountDeletionSignOut
  private let connectivity: any AccountDeletionConnectivity
  private let workouts: any AccountDeletionWorkoutState

  init(
    user: AuthenticatedUser,
    uploads: any AccountDeletionUploads,
    service: any AccountDeletionService,
    erasure: any AccountDeletionLocalErasure,
    signOut: any AccountDeletionSignOut,
    connectivity: any AccountDeletionConnectivity,
    workouts: any AccountDeletionWorkoutState
  ) {
    self.user = user
    self.uploads = uploads
    self.service = service
    self.erasure = erasure
    self.signOut = signOut
    self.connectivity = connectivity
    self.workouts = workouts
  }

  /// Re-reads connectivity, the active workout and the unsynced count. Call when the screen appears
  /// and whenever those inputs may have changed.
  func refresh() {
    if workouts.hasActiveWorkout {
      blocker = .activeWorkout
    } else if !connectivity.isOnline {
      blocker = .offline
    } else {
      blocker = nil
    }
    // An unknown count warns, since the warning only costs the user a read.
    showsUnsyncedWarning = ((try? workouts.unsyncedCompletedSessionCount(accountID: user.id)) ?? 1) > 0
  }

  /// Starts deletion after the user confirms. Does nothing while blocked or already running.
  func confirmDeletion() async {
    refresh()
    guard canDelete else { return }
    phase = .deleting
    await uploads.suspend(accountID: user.id)

    guard await service.deleteAccount(for: user) == .deleted else {
      uploads.resume(accountID: user.id)
      // Show the failure now; restarting uploads is background work and must not hold the spinner.
      phase = .failed(.request)
      Task { [uploads, user] in await uploads.drain(for: user) }
      return
    }
    await finishLocalCleanup()
  }

  /// Retries the step that failed: the whole request, or only local cleanup once the server has deleted.
  func retry() async {
    switch phase {
    case .failed(.request): await confirmDeletion()
    case .failed(.cleanup): await finishLocalCleanup()
    default: break
    }
  }

  private func finishLocalCleanup() async {
    phase = .deleting
    do {
      try erasure.erase(accountID: user.id)
      try await signOut.signOut()
      phase = .deleted
    } catch {
      phase = .failed(.cleanup)
    }
  }
}
