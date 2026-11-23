import Foundation
import Testing
@testable import OneSet

@MainActor
struct ProgramCycleSyncCoordinatorTests {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let alice = AuthenticatedUser(id: "alice", emailAddress: nil)
  private let bob = AuthenticatedUser(id: "bob", emailAddress: nil)

  private func cycle() -> AccountCycle {
    AccountCycle(cycleID: UUID(), programID: "machine-full-body", startedAt: "2027-01-15T08:00:00Z")
  }

  private func progress(creating cycles: [AccountCycle]) -> OnboardingProgress {
    OnboardingProgress(
      weightUnit: .pounds, trainingDays: 3, selectedProgramID: "machine-full-body", nextStep: .overview,
      cycles: ProgramCycleState(
        selectedProgramID: "machine-full-body", selectedCycleID: cycles[0].cycleID, knownCycles: [],
        discoveryComplete: true, pendingCreations: cycles
      )
    )
  }

  private func upload(
    _ coordinator: ProgramCycleSyncCoordinator, user: AuthenticatedUser, generation: Int,
    holder: ProgressHolder, service: CycleServiceSpy
  ) async {
    await coordinator.upload(
      user: user, generation: generation, at: now, publicationID: nil, service: service,
      store: MemoryProgressStore(),
      current: { holder.progress }, didSave: { holder.progress = $0 },
      authenticationRequired: {}, creationAcknowledged: {}
    )
  }

  @Test
  func suspendWaitsForTheInFlightRequestAndStopsFurtherRequests() async throws {
    let cycles = [cycle(), cycle()]
    let holder = ProgressHolder(progress(creating: cycles))
    let service = CycleServiceSpy(suspendFirstCreate: true)
    let coordinator = ProgramCycleSyncCoordinator()

    let uploading = Task { await upload(coordinator, user: alice, generation: 1, holder: holder, service: service) }
    await settle { service.isCreateSuspended }
    #expect(service.created == [cycles[0].cycleID])

    var suspendReturned = false
    let suspending = Task {
      await coordinator.suspend(accountID: alice.id)
      suspendReturned = true
    }
    await settle { false }
    #expect(suspendReturned == false)

    service.releaseSuspendedCreate()
    await suspending.value
    await uploading.value

    #expect(service.created == [cycles[0].cycleID])
    #expect(holder.progress?.cycles?.pendingCreations.map(\.cycleID) == [cycles[1].cycleID])

    await upload(coordinator, user: alice, generation: 2, holder: holder, service: service)
    #expect(service.created.count == 1)
  }

  @Test
  func suspendStillWaitsWhenANewerGenerationForAnotherAccountFinishesFirst() async throws {
    let holder = ProgressHolder(progress(creating: [cycle()]))
    let service = CycleServiceSpy(suspendFirstCreate: true)
    let coordinator = ProgramCycleSyncCoordinator()

    let uploading = Task { await upload(coordinator, user: alice, generation: 1, holder: holder, service: service) }
    await settle { service.isCreateSuspended }

    let bobHolder = ProgressHolder(progress(creating: [cycle()]))
    await upload(coordinator, user: bob, generation: 2, holder: bobHolder, service: service)

    var suspendReturned = false
    let suspending = Task {
      await coordinator.suspend(accountID: alice.id)
      suspendReturned = true
    }
    await settle { false }
    #expect(suspendReturned == false)

    service.releaseSuspendedCreate()
    await suspending.value
    await uploading.value
    #expect(suspendReturned)
  }

  @Test
  func resumeContinuesAndOtherAccountsAreUnaffected() async throws {
    let cycles = [cycle(), cycle()]
    let holder = ProgressHolder(progress(creating: cycles))
    let service = CycleServiceSpy()
    let coordinator = ProgramCycleSyncCoordinator()

    await coordinator.suspend(accountID: alice.id)
    await upload(coordinator, user: alice, generation: 1, holder: holder, service: service)
    #expect(service.created.isEmpty)
    #expect(holder.progress?.cycles?.pendingCreations.count == 2)

    let otherHolder = ProgressHolder(progress(creating: [cycle()]))
    await upload(coordinator, user: bob, generation: 2, holder: otherHolder, service: service)
    #expect(service.created.count == 1)

    coordinator.resume(accountID: alice.id)
    await upload(coordinator, user: alice, generation: 3, holder: holder, service: service)
    #expect(service.created.count == 3)
    #expect(holder.progress?.cycles?.pendingCreations.isEmpty == true)
  }
}

private final class MemoryProgressStore: OnboardingProgressStore {
  func load(accountID: String) throws -> OnboardingProgress? { nil }
  func save(_ progress: OnboardingProgress, accountID: String) throws {}
  func remove(accountID: String) throws {}
}

@MainActor
private final class ProgressHolder {
  var progress: OnboardingProgress?
  init(_ progress: OnboardingProgress) { self.progress = progress }
}

@MainActor
private final class CycleServiceSpy: AccountCycleService {
  private var suspendFirstCreate: Bool
  private var continuation: CheckedContinuation<Void, Never>?
  private(set) var created: [UUID] = []
  private(set) var isCreateSuspended = false

  init(suspendFirstCreate: Bool = false) { self.suspendFirstCreate = suspendFirstCreate }

  func releaseSuspendedCreate() {
    continuation?.resume()
    continuation = nil
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    throw AccountCycleError.unavailable
  }

  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    created.append(cycle.cycleID)
    if suspendFirstCreate {
      suspendFirstCreate = false
      isCreateSuspended = true
      await withCheckedContinuation { continuation = $0 }
      isCreateSuspended = false
    }
  }

  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}
