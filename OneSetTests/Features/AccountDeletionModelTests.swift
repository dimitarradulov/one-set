import Foundation
import Testing
@testable import OneSet

@MainActor
struct AccountDeletionModelTests {
  private struct StepFailure: Error {}

  private final class Log {
    var events: [String] = []
  }

  private final class Fakes: AccountDeletionUploads, AccountDeletionConnectivity, AccountDeletionWorkoutState,
    AccountDeletionLocalErasure, AccountDeletionSignOut, AccountDeletionService
  {
    let log: Log
    var isOnline = true
    var hasActiveWorkout = false
    var unsyncedCount = 0
    var unsyncedCountFails = false
    var results: [AccountDeletionResult] = [.deleted]
    var eraseFailures = 0
    var signOutFailures = 0
    var drainBlocks = false
    private var drainContinuation: CheckedContinuation<Void, Never>?

    func releaseDrain() { drainContinuation?.resume(); drainContinuation = nil }

    init(log: Log) { self.log = log }

    func suspend(accountID: String) async { log.events.append("suspend \(accountID)") }
    func resume(accountID: String) { log.events.append("resume \(accountID)") }
    func drain(for user: AuthenticatedUser) async {
      log.events.append("drain \(user.id)")
      if drainBlocks { await withCheckedContinuation { drainContinuation = $0 } }
    }
    func unsyncedCompletedSessionCount(accountID: String) throws -> Int {
      if unsyncedCountFails { throw StepFailure() }
      return unsyncedCount
    }
    func erase(accountID: String) throws {
      log.events.append("erase \(accountID)")
      if eraseFailures > 0 {
        eraseFailures -= 1
        throw StepFailure()
      }
    }
    func signOut() async throws {
      log.events.append("signOut")
      if signOutFailures > 0 {
        signOutFailures -= 1
        throw StepFailure()
      }
    }
    func deleteAccount(for user: AuthenticatedUser) async -> AccountDeletionResult {
      log.events.append("request")
      return results.isEmpty ? .failed : results.removeFirst()
    }
  }

  private let user = AuthenticatedUser(id: "alice", emailAddress: nil)

  /// The post-failure drain runs in the background; wait until it has started.
  private func waitForDrain(_ log: Log) async {
    for _ in 0..<100 where !log.events.contains("drain alice") { await Task.yield() }
  }

  private func makeModel(_ fakes: Fakes) -> AccountDeletionModel {
    AccountDeletionModel(
      user: user, uploads: fakes, service: fakes, erasure: fakes, signOut: fakes,
      connectivity: fakes, workouts: fakes)
  }

  @Test func startsReadyWithNoBlockOrWarning() {
    let model = makeModel(Fakes(log: Log()))
    model.refresh()
    #expect(model.phase == .ready)
    #expect(model.blocker == nil)
    #expect(model.canDelete)
    #expect(!model.showsUnsyncedWarning)
  }

  @Test func offlineBlocksDeletion() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.isOnline = false
    let model = makeModel(fakes)
    model.refresh()
    #expect(model.blocker == .offline)
    #expect(!model.canDelete)

    await model.confirmDeletion()

    #expect(log.events.isEmpty)
    #expect(model.phase == .ready)
  }

  @Test func activeWorkoutBlocksDeletionAndTakesPriorityOverOffline() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.hasActiveWorkout = true
    fakes.isOnline = false
    let model = makeModel(fakes)
    model.refresh()
    #expect(model.blocker == .activeWorkout)

    await model.confirmDeletion()

    #expect(log.events.isEmpty)
  }

  @Test func blockerClearsOnRefreshWhenConditionsChange() {
    let fakes = Fakes(log: Log())
    fakes.isOnline = false
    let model = makeModel(fakes)
    model.refresh()
    fakes.isOnline = true
    model.refresh()
    #expect(model.blocker == nil)
  }

  @Test func confirmationRechecksBlockersBeforeStarting() async {
    let log = Log()
    let fakes = Fakes(log: log)
    let model = makeModel(fakes)
    model.refresh()
    fakes.hasActiveWorkout = true

    await model.confirmDeletion()

    #expect(log.events.isEmpty)
    #expect(model.blocker == .activeWorkout)
  }

  @Test func unsyncedSessionsShowWarningButDoNotBlock() {
    let fakes = Fakes(log: Log())
    fakes.unsyncedCount = 2
    let model = makeModel(fakes)
    model.refresh()
    #expect(model.showsUnsyncedWarning)
    #expect(model.canDelete)
  }

  @Test func unknownUnsyncedCountWarnsConservatively() {
    let fakes = Fakes(log: Log())
    fakes.unsyncedCountFails = true
    let model = makeModel(fakes)
    model.refresh()
    #expect(model.showsUnsyncedWarning)
  }

  @Test func successPausesUploadsThenRequestsThenErasesThenSignsOut() async {
    let log = Log()
    let model = makeModel(Fakes(log: log))
    model.refresh()

    await model.confirmDeletion()

    #expect(log.events == ["suspend alice", "request", "erase alice", "signOut"])
    #expect(model.phase == .deleted)
  }

  @Test func failedRequestErasesNothingResumesAndRestartsUploads() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.results = [.failed]
    let model = makeModel(fakes)
    model.refresh()

    await model.confirmDeletion()
    await waitForDrain(log)

    #expect(log.events == ["suspend alice", "request", "resume alice", "drain alice"])
    #expect(model.phase == .failed(.request))
    #expect(model.canDelete)
  }

  @Test func failureIsShownWithoutWaitingForTheUploadDrain() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.results = [.failed]
    fakes.drainBlocks = true
    let model = makeModel(fakes)
    model.refresh()

    await model.confirmDeletion()

    #expect(model.phase == .failed(.request))
    await waitForDrain(log)
    fakes.releaseDrain()
  }

  @Test func retryAfterFailedRequestRunsTheWholeFlowAgain() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.results = [.failed, .deleted]
    let model = makeModel(fakes)
    model.refresh()
    await model.confirmDeletion()
    await waitForDrain(log)
    log.events.removeAll()

    await model.retry()

    #expect(log.events == ["suspend alice", "request", "erase alice", "signOut"])
    #expect(model.phase == .deleted)
  }

  @Test func failedLocalErasureKeepsUploadsPausedAndRetryDoesNotRepeatTheRequest() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.eraseFailures = 1
    let model = makeModel(fakes)
    model.refresh()

    await model.confirmDeletion()

    #expect(log.events == ["suspend alice", "request", "erase alice"])
    #expect(model.phase == .failed(.cleanup))
    log.events.removeAll()

    await model.retry()

    #expect(log.events == ["erase alice", "signOut"])
    #expect(model.phase == .deleted)
  }

  @Test func failedSignOutOffersRetryOfCleanupOnly() async {
    let log = Log()
    let fakes = Fakes(log: log)
    fakes.signOutFailures = 1
    let model = makeModel(fakes)
    model.refresh()

    await model.confirmDeletion()

    #expect(model.phase == .failed(.cleanup))
    log.events.removeAll()

    await model.retry()

    #expect(!log.events.contains("request"))
    #expect(log.events.last == "signOut")
    #expect(model.phase == .deleted)
  }

  @Test func repeatedConfirmationAfterDeletionIsIgnored() async {
    let log = Log()
    let model = makeModel(Fakes(log: log))
    model.refresh()
    await model.confirmDeletion()
    log.events.removeAll()

    await model.confirmDeletion()

    #expect(log.events.isEmpty)
    #expect(model.phase == .deleted)
  }
}
