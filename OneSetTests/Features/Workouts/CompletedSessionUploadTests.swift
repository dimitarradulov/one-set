import Foundation
import Testing
@testable import OneSet

@MainActor
struct CompletedSessionUploadTests {
  @Test
  func finishingSendsTheDurablePayloadAndAcknowledgesItLocally() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let service = CompletedSessionUploadSpy()
    let cycleID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "72.5", repsInput: "10"))
    #expect(model.completeWorkoutSet(slotID: slot.id))
    let sessionID = try #require(model.activeWorkoutSession?.id)

    #expect(model.finishActiveWorkout(note: "Felt strong", using: authentication))
    for _ in 0..<100 where service.uploads.isEmpty { await Task.yield() }
    for _ in 0..<100 where !(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty) {
      await Task.yield()
    }

    let uploaded = try #require(service.uploads.first)
    #expect(uploaded.sessionID == sessionID)
    #expect(uploaded.accountID == "preview-user")
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
    #expect(model.workoutErrorPresented == false)
  }

  @Test
  func failedImmediateUploadKeepsFinishedWorkPendingWithoutRoutineUi() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy(fails: true)
    let cycleID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    let setup = AccountSetup(
      preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "0", repsInput: "8"))
    #expect(model.completeWorkoutSet(slotID: slot.id))
    let sessionID = try #require(model.activeWorkoutSession?.id)

    #expect(model.finishActiveWorkout(note: nil, using: authentication))
    for _ in 0..<100 where service.uploads.isEmpty { await Task.yield() }

    #expect(service.uploads.first?.sessionID == sessionID)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").map(\.sessionID) == [sessionID])
    #expect(model.activeWorkoutSession == nil)
    #expect(model.workoutErrorPresented == false)
  }

  @Test
  func draftsAndDiscardedAttemptsNeverReachTheUploadService() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let service = CompletedSessionUploadSpy()
    let cycleID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: cycleID
    )
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: StaticAccountSetupService(setup: setup),
      completedSessionUploadService: service,
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    let workout = try #require(model.program(id: setup.programID)?.workouts.first)
    let slot = try #require(workout.exercises.first)
    model.startWorkout(programID: setup.programID, workoutID: workout.id, accountID: "preview-user")
    #expect(model.saveWorkoutDraft(slotID: slot.id, weightInput: "70", repsInput: "8"))
    #expect(!model.finishActiveWorkout(note: nil, using: authentication))
    #expect(service.uploads.isEmpty)
    #expect(model.activeWorkoutSession != nil)

    model.discardActiveWorkout(accountID: "preview-user")
    #expect(model.activeWorkoutSession == nil)
    #expect(service.uploads.isEmpty)
    #expect(try repository.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }
}

@MainActor
private final class CompletedSessionUploadSpy: CompletedSessionUploadService {
  let fails: Bool
  private(set) var uploads: [PendingSessionUpload] = []

  init(fails: Bool = false) {
    self.fails = fails
  }

  func upload(_ pending: PendingSessionUpload, for user: AuthenticatedUser) async throws {
    #expect(pending.accountID == user.id)
    uploads.append(pending)
    if fails { throw URLError(.notConnectedToInternet) }
  }
}

@MainActor
private struct StaticAccountSetupService: AccountSetupService {
  let setup: AccountSetup

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    self.setup
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    setup
  }
}
