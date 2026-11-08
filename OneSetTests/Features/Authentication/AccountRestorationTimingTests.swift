import Foundation
import GRDB
import Testing
@testable import OneSet

@MainActor
struct AccountRestorationTimingTests {
  @Test
  func savedProgressOpensAndAllowsStartingWhileRefreshIsSuspended() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "setup.json"))
    var saved = OnboardingProgress(weightUnit: .kilograms, trainingDays: 3,
      selectedProgramID: setup.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.save(saved, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    try repository.restoreProgress(AccountProgress(cycleID: setup.cycleID, programID: setup.programID,
      currentTrainingWeek: 3, completedOccurrences: [], workoutPeriods: [],
      requiredWorkoutIDs: ["machine-full-body-workout-a"]), accountID: "preview-user")
    let service = SuspendedSetupService()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: repository)
    let attempt = Task { await model.resolveAccountSetup(using: auth) }
    while !service.isWaiting { await Task.yield() }
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.currentWorkoutWeek(programID: setup.programID) == 3)
    if case .idle = model.setupResolution {} else { Issue.record("Saved content should be available") }
    model.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    #expect(model.activeWorkoutSession != nil)
    let remote = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    service.complete(remote)
    await attempt.value
    while !model.requiresProgramUpdate { await Task.yield() }
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.activeWorkoutSession != nil)
    #expect(try store.load(accountID: "preview-user")?.pendingRemoteSelection?.cycleID == remote.cycleID)
  }

  @Test
  func completedSetupAloneCannotOpenWhenProgressIsMissing() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "setup.json"))
    var saved = OnboardingProgress(weightUnit: .kilograms, trainingDays: 3,
      selectedProgramID: setup.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.save(saved, accountID: "preview-user")
    let service = SuspendedSetupService()
    let model = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let attempt = Task { await model.resolveAccountSetup(using: auth) }
    while !service.isWaiting { await Task.yield() }
    if case .loading = model.setupResolution {} else { Issue.record("Unsafe progress must keep loading") }
    service.complete()
    await attempt.value
    if case .failed = model.setupResolution {} else { Issue.record("Missing progress must offer recovery") }
    #expect(model.restoredCycleID == nil)
  }

  @Test
  func changedRemoteSelectionDoesNotOpenUnsafeSavedProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let old = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let remote = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "bro-split", cycleID: UUID())
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "setup.json"))
    var saved = OnboardingProgress(weightUnit: .kilograms, trainingDays: 3,
      selectedProgramID: old.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: old, needsUpload: false)
    try store.save(saved, accountID: "preview-user")
    let service = SuspendedSetupService()
    let model = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite")))
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let attempt = Task { await model.resolveAccountSetup(using: auth) }
    while !service.isWaiting { await Task.yield() }
    service.complete(remote)
    await attempt.value
    if case .failed = model.setupResolution {} else { Issue.record("Unsafe progress must offer recovery") }
    #expect(model.restoredCycleID == nil)
  }

  @Test
  func interruptedUnconfirmedRefreshDoesNotBlockOfflineRelaunch() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "setup.json"))
    var saved = OnboardingProgress(weightUnit: .kilograms, trainingDays: 3,
      selectedProgramID: setup.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.save(saved, accountID: "preview-user")
    let repository = try WorkoutRepository(databaseURL: directory.appending(path: "workouts.sqlite"))
    try repository.restoreProgress(AccountProgress(cycleID: setup.cycleID, programID: setup.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [],
      requiredWorkoutIDs: ["machine-full-body-workout-a"]), accountID: "preview-user")
    let service = SuspendedSetupService()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let first = OnboardingModel(catalog: .bundled, setupService: service, progressStore: store,
      workoutRepository: repository)
    let attempt = Task { await first.resolveAccountSetup(using: auth) }
    while !service.isWaiting { await Task.yield() }
    let offline = SuspendedSetupService()
    let reopened = OnboardingModel(catalog: .bundled, setupService: offline, progressStore: store,
      workoutRepository: repository)
    let retry = Task { await reopened.resolveAccountSetup(using: auth) }
    while !offline.isWaiting { await Task.yield() }
    #expect(!reopened.requiresProgramUpdate)
    reopened.startWorkout(programID: setup.programID, workoutID: "machine-full-body-workout-a", accountID: "preview-user")
    #expect(reopened.activeWorkoutSession != nil)
    service.complete(setup)
    offline.complete(setup)
    await attempt.value
    await retry.value
  }

  @Test
  func backgroundProgressSaveFailureIsVisibleAndRetainsSavedProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let store = FileOnboardingProgressStore(fileURL: directory.appending(path: "setup.json"))
    var saved = OnboardingProgress(weightUnit: .kilograms, trainingDays: 3,
      selectedProgramID: setup.programID, nextStep: .overview)
    saved.completed = CompletedOnboarding(setup: setup, needsUpload: false)
    try store.save(saved, accountID: "preview-user")
    let databaseURL = directory.appending(path: "workouts.sqlite")
    let repository = try WorkoutRepository(databaseURL: databaseURL)
    let current = AccountProgress(cycleID: setup.cycleID, programID: setup.programID,
      currentTrainingWeek: 1, completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    try repository.restoreProgress(current, accountID: "preview-user")
    let sabotage = try DatabaseQueue(path: databaseURL.path)
    try await sabotage.write { database in
      try database.execute(sql: """
        CREATE TRIGGER fail_progress BEFORE INSERT ON restored_cycle_progress
        BEGIN SELECT RAISE(ABORT, 'storage unavailable'); END
        """)
    }
    let service = SuspendedSetupService()
    let auth = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service,
      progressService: FixedProgressService(summary: current), progressStore: store, workoutRepository: repository)
    let attempt = Task { await model.resolveAccountSetup(using: auth) }
    while !service.isWaiting { await Task.yield() }
    service.complete(setup)
    await attempt.value
    #expect(model.workoutErrorPresented)
    #expect(model.currentWorkoutWeek(programID: setup.programID) == 1)
    #expect(model.selectedProgramID == setup.programID)
  }

  @Test
  func timeoutOffersRecoveryAndIgnoresLateLookup() async {
    let clock = RestorationClock()
    let service = SuspendedSetupService()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, waitForSetupDelay: { delay in
      try await clock.wait(delay)
    })
    let attempt = Task { await model.resolveAccountSetup(using: authentication) }
    while !service.isWaiting || !clock.hasWaiter(1) || !clock.hasWaiter(15) { await Task.yield() }
    #expect(!model.showsSetupSpinner)
    clock.advance(1)
    await Task.yield()
    #expect(model.showsSetupSpinner)
    clock.advance(15)
    await Task.yield()
    if case .failed = model.setupResolution {} else { Issue.record("Recovery should be offered at the deadline") }
    service.complete()
    await attempt.value
    if case .failed = model.setupResolution {} else { Issue.record("A late response must not navigate") }
    #expect(model.path.isEmpty)
  }

  @Test
  func retryStartsFreshTimingAndRejectsTheEarlierResponse() async {
    let clock = RestorationClock()
    let service = SuspendedSetupService()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, waitForSetupDelay: { delay in
      try await clock.wait(delay)
    })
    let first = Task { await model.resolveAccountSetup(using: authentication) }
    while service.waitingCount < 1 || !clock.hasWaiter(1) || !clock.hasWaiter(15) { await Task.yield() }
    clock.advance(1)
    await Task.yield()
    clock.advance(15)
    await Task.yield()
    let retry = Task { await model.resolveAccountSetup(using: authentication) }
    while service.waitingCount < 2 || !clock.hasWaiter(1) || !clock.hasWaiter(15) { await Task.yield() }
    #expect(!model.showsSetupSpinner)
    service.complete()
    await first.value
    if case .loading = model.setupResolution {} else { Issue.record("The earlier attempt must not resolve the retry") }
    clock.advance(1)
    await Task.yield()
    #expect(model.showsSetupSpinner)
    service.complete()
    await retry.value
    #expect(model.path == [.preferences])
    clock.advance(15)
    await Task.yield()
    if case .idle = model.setupResolution {} else { Issue.record("Completion must cancel the deadline") }
  }

  @Test
  func deadlineCoversProgressLookupAndRejectsItsLateResult() async {
    let clock = RestorationClock()
    let progress = SuspendedProgressService()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(
      catalog: .bundled,
      setupService: PreviewAccountSetupService(arguments: ["--ui-setup-completed"]),
      progressService: progress,
      waitForSetupDelay: { delay in try await clock.wait(delay) }
    )
    let attempt = Task { await model.resolveAccountSetup(using: authentication) }
    while !progress.isWaiting || !clock.hasWaiter(1) || !clock.hasWaiter(15) { await Task.yield() }
    clock.advance(15)
    await Task.yield()
    if case .failed = model.setupResolution {} else { Issue.record("The full restoration must time out") }
    progress.complete()
    await attempt.value
    #expect(model.restoredCycleID == nil)
    #expect(model.path.isEmpty)
    if case .failed = model.setupResolution {} else { Issue.record("Late progress must not resolve restoration") }
    clock.advance(1)
  }

  @Test
  func immediateCompletionDoesNotWaitForSpinner() async {
    let clock = RestorationClock()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: PreviewAccountSetupService(), waitForSetupDelay: { delay in
      try await clock.wait(delay)
    })
    await model.resolveAccountSetup(using: authentication)
    #expect(model.path == [.preferences])
    #expect(!model.showsSetupSpinner)
    await Task.yield()
    clock.advance(1)
    clock.advance(15)
  }
}

@MainActor
private final class RestorationClock {
  private var waiters: [TimeInterval: CheckedContinuation<Void, any Error>] = [:]
  func wait(_ delay: TimeInterval) async throws {
    try await withCheckedThrowingContinuation { waiters[delay] = $0 }
  }
  func hasWaiter(_ delay: TimeInterval) -> Bool { waiters[delay] != nil }
  func advance(_ delay: TimeInterval) { waiters.removeValue(forKey: delay)?.resume() }
}

@MainActor
private final class SuspendedSetupService: AccountSetupService {
  private var continuations: [CheckedContinuation<AccountSetup?, Never>] = []
  var isWaiting: Bool { !continuations.isEmpty }
  var waitingCount: Int { continuations.count }
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    await withCheckedContinuation { continuations.append($0) }
  }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { setup }
  func complete(_ setup: AccountSetup? = nil) { continuations.removeFirst().resume(returning: setup) }
}

@MainActor
private final class SuspendedProgressService: AccountProgressService {
  private var continuation: CheckedContinuation<AccountProgress?, Never>?
  var isWaiting: Bool { continuation != nil }
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? {
    await withCheckedContinuation { continuation = $0 }
  }
  func complete() { continuation?.resume(returning: nil); continuation = nil }
}

@MainActor
private final class FixedProgressService: AccountProgressService {
  let summary: AccountProgress
  init(summary: AccountProgress) { self.summary = summary }
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? { summary }
}
