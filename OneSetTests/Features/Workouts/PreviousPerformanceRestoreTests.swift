import Foundation
import Testing
@testable import OneSet

@MainActor
struct PreviousPerformanceRestoreTests {
  @Test
  func accountRestorationPersistsCompactResultsForTheRecordingFlow() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let program = try #require(ProgramCatalog.bundled.program(id: "machine-full-body"))
    let workout = try #require(program.workouts.first)
    let exercise = try #require(workout.exercises.first)
    let setup = AccountSetup(
      preferredUnit: .kilograms, trainingDays: 3, programID: program.id,
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
    let snapshot = WorkoutRepository.PreviousPerformanceSnapshot(
      sessionID: UUID(), exerciseKey: exercise.exerciseKey, programID: program.id,
      workoutID: workout.id, slotID: exercise.id, weightInput: "0", repsInput: "10",
      weightUnit: .pounds, completedAt: Date(timeIntervalSince1970: 1_800_000_000),
      workoutName: "Captured Machine Day", week: 12, day: nil
    )
    let service = StubPreviousPerformanceService(results: [snapshot])
    let model = OnboardingModel(
      catalog: .bundled, setupService: StubAccountSetupService(setup: setup),
      previousPerformanceService: service, workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)
    model.startWorkout(programID: program.id, workoutID: workout.id, accountID: "preview-user")

    let session = try #require(model.activeWorkoutSession)
    let result = try #require(model.previousPerformances(for: session)[exercise.id])
    #expect(result.weightInput == "0")
    #expect(result.repsInput == "10")
    #expect(result.weightUnit == .pounds)
    #expect(result.isSameProgramWorkout)
    #expect(!model.previousPerformanceUnavailable)

    let reopened = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let afterRelaunch = try #require(try reopened.previousPerformance(accountID: "preview-user",
      exerciseKey: exercise.exerciseKey, slotID: exercise.id, programID: program.id, workoutID: workout.id))
    #expect(afterRelaunch.weightInput == "0")
    #expect(try reopened.pendingSessionUploads(accountID: "preview-user").isEmpty)
  }

  @Test
  func failedSummaryRestorePreservesLocalResultsAndMarksMissingResultsUnavailable() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let setup = AccountSetup(
      preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body",
      cycleID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    )
    let program = try #require(ProgramCatalog.bundled.program(id: setup.programID))
    let workout = try #require(program.workouts.first)
    let exercise = try #require(workout.exercises.first)
    let completedLocal = WorkoutSession(accountID: "preview-user", cycleID: setup.cycleID,
      program: program, workout: workout, week: 1, day: 1, weightUnit: .kilograms)
    _ = try repository.start(completedLocal)
    _ = try repository.saveDraft(sessionID: completedLocal.id, accountID: "preview-user",
      slotID: exercise.id, weightInput: "42.5", repsInput: "11")
    _ = try repository.completeSet(sessionID: completedLocal.id, accountID: "preview-user", slotID: exercise.id)
    _ = try repository.finish(sessionID: completedLocal.id, accountID: "preview-user", note: nil)
    let model = OnboardingModel(
      catalog: .bundled, setupService: StubAccountSetupService(setup: setup),
      previousPerformanceService: StubPreviousPerformanceService(fails: true),
      workoutRepository: repository
    )
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    #expect(model.previousPerformanceUnavailable)
    let nextSession = WorkoutSession(accountID: "preview-user", cycleID: setup.cycleID,
      program: program, workout: workout, week: 1, day: 1)
    let result = try #require(model.previousPerformances(for: nextSession)[exercise.id])
    #expect(result.weightInput == "42.5")
    #expect(result.repsInput == "11")
  }
}

@MainActor
private struct StubPreviousPerformanceService: PreviousPerformanceService {
  let results: [WorkoutRepository.PreviousPerformanceSnapshot]
  let fails: Bool

  init(results: [WorkoutRepository.PreviousPerformanceSnapshot] = [], fails: Bool = false) {
    self.results = results
    self.fails = fails
  }

  func lookup(for user: AuthenticatedUser) async throws -> [WorkoutRepository.PreviousPerformanceSnapshot] {
    if fails { throw AccountSetupError.unavailable }
    return results
  }
}

@MainActor
private struct StubAccountSetupService: AccountSetupService {
  let setup: AccountSetup

  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { self.setup }
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { setup }
}
