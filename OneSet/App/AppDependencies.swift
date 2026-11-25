import Foundation

@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService
  let onboardingProgress: any OnboardingProgressStore
  let accountSetup: any AccountSetupService
  let accountCycles: (any AccountCycleService)?
  let previousPerformance: any PreviousPerformanceService
  let accountProgress: (any AccountProgressService)?
  let completedSessionUpload: (any CompletedSessionUploadService)?
  let sessionHistory: (any SessionHistoryService)?
  let subscriptionAccess: any SubscriptionAccessService
  let workoutRepositoryFactory: @MainActor () throws -> WorkoutRepository
  let accountDeletion: AccountDeletionServices

  /// RevenueCat's paywall for the live service. Previews and UI tests use the fake host.
  var paywallHost: any PaywallHost {
    #if DEBUG
    if !(subscriptionAccess is RevenueCatSubscriptionAccessService) { return FakePaywallHost() }
    #endif
    return RevenueCatPaywallHost()
  }

  /// The account owner's approval for the live service. Previews and UI tests that inject a
  /// fake service approve everything; release builds without the owner refuse.
  var paywallApproval: any PaywallApproving {
    if let owner = subscriptionAccess as? any SubscriptionOperationOwner {
      return OwnerPaywallApproval(owner: owner)
    }
    #if DEBUG
    return PreviewPaywallApproval()
    #else
    return UnconfiguredPaywallApproval()
    #endif
  }

  #if DEBUG
  static func development(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppDependencies {
    let storage = AppStorage(environment: environment)
    let workoutURL = storage.directory.appending(path: "Development/workouts.sqlite")
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-workouts-reset") {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(atPath: workoutURL.path + suffix)
      }
    }
    let progressURL = storage.directory.appending(path: "Development/onboarding.json")
    return AppDependencies(
      catalog: .bundled,
      authentication: PreviewAuthenticationService(startsSignedIn: true),
      onboardingProgress: FileOnboardingProgressStore(
        fileURL: progressURL
      ),
      accountSetup: PreviewAccountSetupService(),
      accountCycles: nil,
      previousPerformance: PreviewPreviousPerformanceService(),
      accountProgress: nil,
      completedSessionUpload: nil,
      sessionHistory: nil,
      subscriptionAccess: PreviewSubscriptionAccessService(
        preset: SubscriptionAccessPreset(arguments: arguments) ?? .inactive,
        restore: SubscriptionRestorePreset(arguments: arguments)
      ),
      workoutRepositoryFactory: { try WorkoutRepository(databaseURL: workoutURL) },
      accountDeletion: AccountDeletionServices(
        service: PreviewAccountDeletionService(arguments: arguments),
        onboardingProgress: FileOnboardingProgressStore(fileURL: progressURL),
        savedSubscriptionAccess: FileSavedSubscriptionAccessStore(
          fileURL: storage.directory.appending(path: "Development/saved-access.json")),
        pendingSubscriptionOperations: FilePendingSubscriptionOperationStore(
          fileURL: storage.directory.appending(path: "Development/pending-operations.json"))
      )
    )
  }
  #endif

  static func live(
    arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> AppDependencies {
    let storage = AppStorage(environment: environment)
    let directory = storage.directory.appending(path: "Onboarding")
    #if DEBUG
    if let preview = Self.launchPreview(arguments: arguments, storage: storage, onboardingDirectory: directory) {
      return preview
    }
    #endif
    let progress: any OnboardingProgressStore = FileOnboardingProgressStore(
      fileURL: directory.appending(path: "progress.json")
    )

    let authentication = ClerkAuthenticationService()
    let savedSubscriptionAccess = FileSavedSubscriptionAccessStore(
      fileURL: storage.directory.appending(path: "Subscription/saved-access.json")
    )
    let pendingSubscriptionOperations = FilePendingSubscriptionOperationStore(
      fileURL: storage.directory.appending(path: "Subscription/pending-operations.json")
    )
    let subscriptionAccess = Self.subscriptionAccess(
      arguments: arguments, environment: environment,
      savedAccess: savedSubscriptionAccess, pending: pendingSubscriptionOperations
    )
    let catalogDirectory = storage.directory.appending(path: "Catalog")
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      bundledExercises: ProgramCatalog.unassignedBundledExercises,
      service: HTTPProgramCatalogService(authentication: authentication),
      persistence: FileProgramCatalogPersistence(
        fileURL: catalogDirectory.appending(path: "published-catalog.json")
      )
    )
    return AppDependencies(
      catalog: catalog,
      authentication: authentication,
      onboardingProgress: progress,
      accountSetup: HTTPAccountSetupService(authentication: authentication),
      accountCycles: HTTPAccountCycleService(authentication: authentication),
      previousPerformance: HTTPPreviousPerformanceService(authentication: authentication),
      accountProgress: HTTPAccountProgressService(authentication: authentication),
      completedSessionUpload: HTTPCompletedSessionUploadService(authentication: authentication),
      sessionHistory: HTTPSessionHistoryService(authentication: authentication),
      subscriptionAccess: subscriptionAccess,
      workoutRepositoryFactory: {
        try WorkoutRepository(databaseURL: storage.directory.appending(path: "Workouts/workouts.sqlite"))
      },
      accountDeletion: AccountDeletionServices(
        service: HTTPAccountDeletionService(authentication: authentication),
        onboardingProgress: progress,
        savedSubscriptionAccess: savedSubscriptionAccess,
        pendingSubscriptionOperations: pendingSubscriptionOperations
      )
    )
  }

  #if DEBUG
  static func previewWorkoutFile(
    _ arguments: [String], restoreError: Bool, signOut: Bool, history: Bool
  ) -> String {
    if arguments.contains("--ui-finish-review") { return "finish-review-workouts.sqlite" }
    if restoreError { return "progress-restore-error-workouts.sqlite" }
    if signOut { return "session-signout-workouts.sqlite" }
    return history ? "history-preview-workouts.sqlite" : "workouts.sqlite"
  }

  /// Setup journeys stay on the trial screen unless a test presets Pro. Tab previews and
  /// accounts with completed setup start with Pro.
  static func previewSubscriptionAccess(
    launch: AppLaunchConfiguration, arguments: [String]
  ) -> PreviewSubscriptionAccessService {
    let startsWithPro = launch.includesMainTabsPreview || arguments.contains("--ui-setup-completed")
    return PreviewSubscriptionAccessService(
      preset: launch.subscriptionPreset ?? (startsWithPro ? .active : .inactive),
      restore: launch.subscriptionRestore
    )
  }
  #endif

  /// RevenueCat for the live app. Previews and UI tests keep the fakes and never touch it.
  private static func subscriptionAccess(
    arguments: [String], environment: [String: String],
    savedAccess: any SavedSubscriptionAccessStore, pending: any PendingSubscriptionOperationStore
  ) -> any SubscriptionAccessService {
    #if DEBUG
    let launch = AppLaunchConfiguration(arguments: arguments)
    if let preset = launch.subscriptionPreset {
      return PreviewSubscriptionAccessService(preset: preset, restore: launch.subscriptionRestore)
    }
    if environment["ONESET_UI_TEST_ID"] != nil { return UnconfiguredSubscriptionAccessService() }
    #endif
    return liveSubscriptionAccess(savedAccess: savedAccess, pending: pending)
  }

  private static func liveSubscriptionAccess(
    savedAccess: any SavedSubscriptionAccessStore, pending: any PendingSubscriptionOperationStore
  ) -> RevenueCatSubscriptionAccessService {
    #if DEBUG
    let isDebug = true
    #else
    let isDebug = false
    #endif
    return RevenueCatSubscriptionAccessService(
      client: LivePurchasesClient(fallbackEnvironment: isDebug ? .sandbox : .production),
      apiKey: AppLaunchConfiguration.revenueCatAPIKey(),
      store: savedAccess,
      pendingStore: pending,
      acceptsSandboxSavedAccess: isDebug
    )
  }

  #if DEBUG
  static func seedCompletedPreviewSession(
    in repository: WorkoutRepository,
    cycleID: UUID,
    startedAt: Date
  ) throws {
    guard let program = ProgramCatalog.bundled.program(id: "machine-full-body"),
          let workout = program.workouts.first,
          let exercise = workout.exercises.first else { return }
    let session = WorkoutSession(
      accountID: "preview-user", cycleID: cycleID,
      program: program, workout: workout, week: 1, day: 1,
      weightUnit: .pounds, startedAt: startedAt
    )
    _ = try repository.start(session)
    _ = try repository.saveDraft(
      sessionID: session.id, accountID: session.accountID,
      slotID: exercise.id, weightInput: "50", repsInput: "8"
    )
    _ = try repository.completeSet(
      sessionID: session.id, accountID: session.accountID, slotID: exercise.id,
      at: startedAt.addingTimeInterval(10)
    )
    _ = try repository.finish(
      sessionID: session.id, accountID: session.accountID, note: nil,
      at: startedAt.addingTimeInterval(20)
    )
  }

  static func seedHistoryPreviewSessions(in repository: WorkoutRepository) throws {
    guard try repository.completedSessions(accountID: "preview-user").isEmpty,
          let program = ProgramCatalog.bundled.program(id: "machine-full-body"),
          let workout = program.workouts.first, workout.exercises.count >= 2 else { return }
    let samples: [(String, UUID, Date, Bool)] = [
      ("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
       ISO8601DateFormatter().date(from: "2026-10-18T10:00:00Z")!, false),
      ("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
       ISO8601DateFormatter().date(from: "2026-10-29T18:30:00Z")!, true),
    ]
    for (_, sessionID, startedAt, partial) in samples {
      let capturedWorkout = partial ? WorkoutTemplate(id: workout.id, name: workout.name, exercises: workout.exercises,
        supersets: [SupersetPair(firstSlotID: workout.exercises[0].id, secondSlotID: workout.exercises[1].id)]) : workout
      let session = WorkoutSession(
        accountID: "preview-user", cycleID: UUID(), program: program, workout: capturedWorkout,
        week: 1, day: 1, weightUnit: .pounds, startedAt: startedAt, id: sessionID
      )
      _ = try repository.start(session)
      for (index, exercise) in session.exercises.enumerated() {
        if partial && index > 0 {
          _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
            slotID: exercise.slotID, weightInput: "999", repsInput: "draft")
          continue
        }
        let weight = partial ? "0" : "125.5"
        _ = try repository.saveDraft(sessionID: session.id, accountID: session.accountID,
          slotID: exercise.slotID, weightInput: weight, repsInput: "10")
        _ = try repository.completeSet(sessionID: session.id, accountID: session.accountID,
          slotID: exercise.slotID, at: startedAt.addingTimeInterval(Double(index + 1) * 600))
      }
      _ = try repository.finish(
        sessionID: session.id,
        accountID: session.accountID,
        note: partial ? "Recorded as a partial workout." : nil,
        at: startedAt.addingTimeInterval(3_600)
      )
    }
  }

  static func previewDownloadedHistorySession(
    id sessionID: String,
    workout workoutID: String,
    startedAt: Date,
    day: Int
  ) -> WorkoutSession {
    let id = UUID(uuidString: sessionID) ?? UUID()
    let program = ProgramCatalog.bundled.program(id: "machine-full-body")!
    let workout = program.workouts.first(where: { $0.id == workoutID }) ?? program.workouts[0]
    var session = WorkoutSession(
      accountID: "preview-user", cycleID: PreviewCycleID.current,
      program: program, workout: workout, week: 2, day: day,
      weightUnit: .kilograms, startedAt: startedAt, id: id
    )
    if let exercise = session.exercises.first {
      session.setEntries[exercise.slotID] = WorkoutSession.SetEntry(
        weightInput: "42.5", repsInput: "10", completedAt: startedAt.addingTimeInterval(600),
        recordedWeightUnit: .kilograms
      )
    }
    session.finishedAt = startedAt.addingTimeInterval(1800)
    session.note = "Downloaded for offline review"
    return session
  }
  #endif
}

#if DEBUG
@MainActor
struct PreviewProgramCatalogService: ProgramCatalogService {
  let editedProgram: Bool

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    var programs = ProgramCatalog.bundled.programs
    if editedProgram,
       let index = programs.firstIndex(where: { $0.id == "push-pull-legs" }) {
      let current = programs[index]
      programs[index] = TrainingProgram(
        id: current.id, name: "Push Pull Legs Updated",
        format: current.format, emphasis: "Updated publication for refresh continuity.",
        workouts: current.workouts, recommendedWeeks: current.recommendedWeeks, isOffered: current.isOffered
      )
    }
    programs.append(TrainingProgram(
      id: "founder-authored-plan", name: "Founder Authored Plan",
      format: "A / B / C", emphasis: "A newly published plan.",
      workouts: [WorkoutTemplate(id: "founder-authored-plan-day-a", name: "Day A", banner: "lower-body", exercises: [
        WorkoutExercise(
          id: "founder-authored-plan-slot-a", exerciseKey: "barbell-row", name: "Barbell Row",
          repTarget: RepTarget(minimum: 8, maximum: 12), instructions: "Row with control.",
          stoppingGuidance: "Stop when form breaks.", warmupGuidance: "Warm up gradually.",
          restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12)
        )
      ])], recommendedWeeks: 8
    ))
    return .snapshot(PublishedProgramCatalogSnapshot(
      publicationID: "preview-publication", entityTag: "\"preview-catalog\"", programs: programs
    ))
  }
}
#endif

#if DEBUG
@MainActor
final class PreviewSwitchSyncService: AccountCycleService, CompletedSessionUploadService {
  let online: Bool
  private var created: Set<UUID> = []

  init(online: Bool) { self.online = online }

  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {
    if !online { throw AccountCycleError.unavailable }
  }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    let current = PreviewCycleID.current
    return AccountCycles(cycles: [AccountCycle(cycleID: current, programID: "machine-full-body",
      startedAt: "2026-01-01T00:00:00Z")], selectedCycleID: current)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    if !online { throw AccountCycleError.unavailable }
    created.insert(cycle.cycleID)
  }
  func upload(_ pending: PendingSessionUpload, for user: AuthenticatedUser) async throws {
    guard online, let json = try? JSONSerialization.jsonObject(with: pending.body) as? [String: Any],
          let id = json["cycle_id"] as? String, let cycleID = UUID(uuidString: id),
          created.contains(cycleID) else { throw CompletedSessionUploadError.temporary(retryAfter: nil) }
  }
}
#endif

#if DEBUG
@MainActor
struct PreviewRestoredCycles: AccountCycleService {
  private let current = PreviewCycleID.current
  private let previous = PreviewCycleID.previous
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [
      AccountCycle(cycleID: current, programID: "machine-full-body", startedAt: "2026-02-01T00:00:00Z"),
      AccountCycle(cycleID: previous, programID: "bro-split", startedAt: "2026-01-01T00:00:00Z")
    ], selectedCycleID: current)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
}

@MainActor
struct PreviewRestoredProgress: AccountProgressService {
  private let current = PreviewCycleID.current
  private let previous = PreviewCycleID.previous
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? {
    try await lookup(cycleID: current, for: user)
  }
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress? {
    if cycleID == current {
      return AccountProgress(cycleID: current, programID: "machine-full-body", currentTrainingWeek: 1,
        completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
    }
    guard cycleID == previous else { return nil }
    return AccountProgress(cycleID: previous, programID: "bro-split", currentTrainingWeek: 3,
      completedOccurrences: [], workoutPeriods: [], requiredWorkoutIDs: [])
  }
}
#endif
