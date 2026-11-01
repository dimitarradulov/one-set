import Foundation
import Testing
@testable import OneSet

@MainActor
struct AppStorageTests {
  @Test(arguments: [false, true])
  func journeysKeepTheirOwnStateAcrossDependencyRecreation(development: Bool) async throws {
    let firstID = UUID().uuidString
    let secondID = UUID().uuidString
    let firstEnvironment = ["ONESET_UI_TEST_ID": firstID]
    let secondEnvironment = ["ONESET_UI_TEST_ID": secondID]
    defer {
      for id in [firstID, secondID] {
        let storage = AppStorage(environment: ["ONESET_UI_TEST_ID": id])
        try? FileManager.default.removeItem(at: storage.directory)
        storage.authenticationDefaults.removePersistentDomain(forName: "oneset.ui-tests.\(id)")
      }
    }
    let arguments = ["--ui-auth-test", "--ui-auth-persist-session-test", "--ui-progress-keep", "--ui-shared-backend"]
    func dependencies(_ environment: [String: String]) -> AppDependencies {
      development ? .development(environment: environment) : .live(arguments: arguments, environment: environment)
    }

    let first = dependencies(firstEnvironment)
    if !development { try await first.authentication.signInWithApple() }
    let user = try #require(first.authentication.signedInUser)
    let program = try #require(first.catalog.programs.first)
    let workout = try #require(program.workouts.first)
    let session = WorkoutSession(accountID: user.id, cycleID: UUID(), program: program,
      workout: workout, week: 1, day: 1, weightUnit: .pounds)
    let repository = try first.workoutRepositoryFactory()
    _ = try repository.start(session)
    try first.onboardingProgress.save(
      OnboardingProgress(weightUnit: .pounds, trainingDays: 5, selectedProgramID: program.id, nextStep: .programs),
      accountID: user.id
    )
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 5,
      programID: program.id, cycleID: session.cycleID)
    _ = try await first.accountSetup.save(setup, for: user)

    let second = dependencies(secondEnvironment)
    #expect(try second.workoutRepositoryFactory().activeSession(accountID: user.id) == nil)
    #expect(try second.onboardingProgress.load(accountID: user.id) == nil)
    if !development {
      #expect(second.authentication.signedInUser == nil)
      #expect(try await second.accountSetup.lookup(for: user) == nil)
    }

    let reopened = dependencies(firstEnvironment)
    #expect(reopened.authentication.signedInUser?.id == user.id)
    #expect(try reopened.workoutRepositoryFactory().activeSession(accountID: user.id)?.id == session.id)
    #expect(try reopened.onboardingProgress.load(accountID: user.id)?.trainingDays == 5)
    if !development {
      #expect(try await reopened.accountSetup.lookup(for: user)?.cycleID == session.cycleID)
      try await reopened.authentication.signOut()
      #expect(dependencies(firstEnvironment).authentication.signedInUser == nil)
    }
  }

  @Test(arguments: [[:], ["ONESET_UI_TEST_ID": "../../invalid"]])
  func ordinaryLaunchesUseApplicationStorage(environment: [String: String]) {
    let storage = AppStorage(environment: environment)
    #expect(storage.directory == URL.applicationSupportDirectory)
    #expect(storage.authenticationDefaults === UserDefaults.standard)
  }
}
