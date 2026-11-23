import Foundation
import Testing
@testable import OneSet

@MainActor
struct LocalAccountErasureTests {
  private struct StepFailure: Error, Equatable {
    let name: String
  }

  private final class RecordingStep: AccountDeletionCleanup {
    let name: String
    let fails: Bool
    private(set) var erasedAccountIDs: [String] = []
    var onErase: (() -> Void)?

    init(_ name: String, fails: Bool = false) {
      self.name = name
      self.fails = fails
    }

    func erase(accountID: String) throws {
      erasedAccountIDs.append(accountID)
      onErase?()
      if fails { throw StepFailure(name: name) }
    }
  }

  @Test
  func runsEveryStepInOrderForTheAccount() throws {
    var order: [String] = []
    let steps = ["a", "b", "c"].map { name -> RecordingStep in
      let step = RecordingStep(name)
      step.onErase = { order.append(name) }
      return step
    }

    try LocalAccountErasure(steps: steps).erase(accountID: "user")

    #expect(order == ["a", "b", "c"])
    #expect(steps.allSatisfy { $0.erasedAccountIDs == ["user"] })
  }

  @Test
  func failingStepIsReportedAndLaterStepsStillRun() {
    let first = RecordingStep("first", fails: true)
    let second = RecordingStep("second")
    let third = RecordingStep("third", fails: true)
    let fourth = RecordingStep("fourth")

    do {
      try LocalAccountErasure(steps: [first, second, third, fourth]).erase(accountID: "user")
      Issue.record("Erasure must report failed steps")
    } catch let error as LocalAccountErasureError {
      #expect(error.failures.compactMap { $0 as? StepFailure } == [.init(name: "first"), .init(name: "third")])
    } catch {
      Issue.record("Unexpected error \(error)")
    }
    #expect([second, fourth].allSatisfy { $0.erasedAccountIDs == ["user"] })
  }

  @Test
  func anotherStepCanBeAddedWithoutChangingTheRunner() throws {
    let extra = RecordingStep("billing")
    let steps: [any AccountDeletionCleanup] = [RecordingStep("repository"), extra]

    try LocalAccountErasure(steps: steps).erase(accountID: "user")

    #expect(extra.erasedAccountIDs == ["user"])
  }

  @Test
  func standardStepsEraseTheAccountFromEveryLocalStore() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    let onboarding = FileOnboardingProgressStore(fileURL: directory.appending(path: "onboarding.json"))
    let access = FileSavedSubscriptionAccessStore(fileURL: directory.appending(path: "access.json"))
    let pending = FilePendingSubscriptionOperationStore(fileURL: directory.appending(path: "pending.json"))
    let progress = OnboardingProgress(
      weightUnit: .kilograms, trainingDays: 3, selectedProgramID: nil, nextStep: .programs
    )
    let record = SavedSubscriptionRecord(checkedAt: .now, status: .inactive)
    let operation = PendingSubscriptionOperation(kind: .approval, startedAt: .now)
    for account in ["erased", "kept"] {
      try onboarding.save(progress, accountID: account)
      try access.save(record, accountID: account, environment: .production)
      try pending.save(operation, accountID: account)
    }

    try LocalAccountErasure.standard(
      repository: repository, onboardingProgress: onboarding,
      savedSubscriptionAccess: access, pendingSubscriptionOperations: pending
    ).erase(accountID: "erased")

    #expect(try onboarding.load(accountID: "erased") == nil)
    #expect(try access.load(accountID: "erased", environment: .production) == nil)
    #expect(try pending.load(accountID: "erased") == nil)
    #expect(try onboarding.load(accountID: "kept") != nil)
    #expect(try access.load(accountID: "kept", environment: .production) == record)
    #expect(try pending.load(accountID: "kept") == operation)
  }
}
