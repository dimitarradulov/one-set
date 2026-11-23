import Foundation
import Testing
@testable import OneSet

@MainActor
struct CompletedSessionUploadCoordinatorTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let alice = AuthenticatedUser(id: "alice", emailAddress: nil)
  private let bob = AuthenticatedUser(id: "bob", emailAddress: nil)

  private func makeRepository() throws -> (WorkoutRepository, URL) {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    return (try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")), directory)
  }

  private func makeCoordinator(
    _ repository: WorkoutRepository, _ service: CompletedSessionUploadSpy
  ) -> CompletedSessionUploadCoordinator {
    CompletedSessionUploadCoordinator(
      repository: repository, service: service, waitForRetry: { _ in try await Task.sleep(for: .seconds(3_600)) }
    )
  }

  private func drain(
    _ coordinator: CompletedSessionUploadCoordinator, _ user: AuthenticatedUser
  ) async {
    await coordinator.drain(for: user, whileCurrent: { true }, at: now, scheduleRetries: false)
  }

  @Test
  func suspendWaitsForTheInFlightRequestAndStopsFurtherRequestsForThatAccount() async throws {
    let (repository, directory) = try makeRepository()
    defer { try? FileManager.default.removeItem(at: directory) }
    let sessions = try finishSessions(repository: repository, accountID: alice.id, count: 3)
    let service = CompletedSessionUploadSpy(suspendNextUpload: true)
    let coordinator = makeCoordinator(repository, service)

    let draining = Task { await drain(coordinator, alice) }
    await settle { service.isUploadSuspended }
    #expect(service.uploads.count == 1)

    var suspendReturned = false
    let suspending = Task {
      await coordinator.suspend(accountID: alice.id)
      suspendReturned = true
    }
    await settle { false }
    #expect(suspendReturned == false)

    service.resumeSuspendedUpload()
    await suspending.value
    await draining.value

    #expect(suspendReturned)
    #expect(service.uploads.map(\.sessionID) == [sessions[0]])
    #expect(try repository.pendingSessionUploads(accountID: alice.id).map(\.sessionID) == Array(sessions[1...]))

    await drain(coordinator, alice)
    #expect(service.uploads.count == 1)
  }

  @Test
  func suspendedAccountSendsNothingWhileOtherAccountsKeepDraining() async throws {
    let (repository, directory) = try makeRepository()
    defer { try? FileManager.default.removeItem(at: directory) }
    _ = try finishSessions(repository: repository, accountID: alice.id, count: 2)
    let bobSessions = try finishSessions(repository: repository, accountID: bob.id, count: 1)
    let service = CompletedSessionUploadSpy()
    let coordinator = makeCoordinator(repository, service)

    await coordinator.suspend(accountID: alice.id)
    await drain(coordinator, alice)
    await drain(coordinator, bob)

    #expect(service.uploads.map(\.sessionID) == bobSessions)
    #expect(try repository.pendingSessionUploads(accountID: alice.id).count == 2)
  }

  @Test
  func suspendingOneAccountDoesNotWaitForAnotherAccountsDrain() async throws {
    let (repository, directory) = try makeRepository()
    defer { try? FileManager.default.removeItem(at: directory) }
    _ = try finishSessions(repository: repository, accountID: bob.id, count: 1)
    let service = CompletedSessionUploadSpy(suspendNextUpload: true)
    let coordinator = makeCoordinator(repository, service)

    let draining = Task { await drain(coordinator, bob) }
    await settle { service.isUploadSuspended }
    await coordinator.suspend(accountID: alice.id)
    #expect(service.isUploadSuspended)

    service.resumeSuspendedUpload()
    await draining.value
  }

  @Test
  func resumeContinuesUploadingAndKeepsQueuedRecords() async throws {
    let (repository, directory) = try makeRepository()
    defer { try? FileManager.default.removeItem(at: directory) }
    let sessions = try finishSessions(repository: repository, accountID: alice.id, count: 2)
    let service = CompletedSessionUploadSpy(outcomes: [.offline])
    let coordinator = makeCoordinator(repository, service)

    await coordinator.suspend(accountID: alice.id)
    await drain(coordinator, alice)
    #expect(service.uploads.isEmpty)
    #expect(try repository.pendingSessionUploads(accountID: alice.id).map(\.sessionID) == sessions)

    coordinator.resume(accountID: alice.id)
    await drain(coordinator, alice)

    // The first request fails transiently and backs off; the second still goes out and is acknowledged.
    #expect(service.uploads.map(\.sessionID) == sessions)
    let queue = try repository.sessionUploadQueue(accountID: alice.id)
    #expect(queue.map(\.upload.sessionID) == [sessions[0]])
    #expect(queue.first?.retryAfter != nil)
  }

  @Test
  func suspendDiscardsQueuedDrainForThatAccount() async throws {
    let (repository, directory) = try makeRepository()
    defer { try? FileManager.default.removeItem(at: directory) }
    _ = try finishSessions(repository: repository, accountID: alice.id, count: 2)
    let service = CompletedSessionUploadSpy(suspendNextUpload: true)
    let coordinator = makeCoordinator(repository, service)

    let first = Task { await drain(coordinator, alice) }
    await settle { service.isUploadSuspended }
    await drain(coordinator, alice) // queued behind the running drain
    let suspending = Task { await coordinator.suspend(accountID: alice.id) }
    await settle { false }
    service.resumeSuspendedUpload()
    await suspending.value
    await first.value
    await settle { false }

    #expect(service.uploads.count == 1)
  }
}

@MainActor
func settle(_ condition: () -> Bool) async {
  for _ in 0..<50 {
    if condition() { return }
    await Task.yield()
  }
}

@MainActor
private func finishSessions(repository: WorkoutRepository, accountID: String, count: Int) throws -> [UUID] {
  let program = try #require(ProgramCatalog.bundled.program(id: "machine-full-body"))
  let cycleID = UUID()
  let start = Date(timeIntervalSince1970: 1_800_000_000)
  return try (0..<count).map { index in
    let workout = program.workouts[index % program.workouts.count]
    let slot = try #require(workout.exercises.first)
    let date = start.addingTimeInterval(Double(index) * 60)
    let session = WorkoutSession(
      accountID: accountID, cycleID: cycleID, program: program, workout: workout,
      week: index / program.workouts.count + 1, day: index % program.workouts.count + 1,
      weightUnit: .pounds, startedAt: date
    )
    _ = try repository.start(session)
    _ = try repository.saveDraft(
      sessionID: session.id, accountID: accountID, slotID: slot.id, weightInput: "50", repsInput: "8"
    )
    _ = try repository.completeSet(
      sessionID: session.id, accountID: accountID, slotID: slot.id, at: date.addingTimeInterval(10)
    )
    _ = try repository.finish(
      sessionID: session.id, accountID: accountID, note: nil, at: date.addingTimeInterval(20)
    )
    return session.id
  }
}
