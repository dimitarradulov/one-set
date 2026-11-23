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
    let launch = AppLaunchConfiguration(arguments: arguments)
    let uploadPreview = arguments.contains("--ui-setup-upload-pending")
      || arguments.contains("--ui-setup-upload-discard") || arguments.contains("--ui-setup-upload-removed")
      || arguments.contains("--ui-setup-cycle-conflict")
    let setupCycleConflictPreview = arguments.contains("--ui-setup-cycle-conflict")
    let programChangePreview = arguments.contains("--ui-program-change")
      || arguments.contains("--ui-program-change-preview") || arguments.contains("--ui-program-change-active")
    let sessionSignOutPreview = arguments.contains("--ui-session-signout-confirmation")
      || arguments.contains("--ui-session-signout-error")
    let historyPreview = arguments.contains("--ui-history-populated")
      || arguments.contains("--ui-history-partial-detail")
      || arguments.contains("--ui-history-empty") || arguments.contains("--ui-history-error")
      || arguments.contains("--ui-history-refresh-error")
      || arguments.contains("--ui-history-pagination")
      || arguments.contains("--ui-history-offline-boundary")
    let removedProgramPreview = arguments.contains("--ui-programs-removed")
      || arguments.contains("--ui-setup-removed-follower") || arguments.contains("--ui-setup-upload-removed")
    let accountDeletionUnsyncedPreview = arguments.contains("--ui-account-deletion-unsynced")
    let completionSaveError = arguments.contains("--ui-completion-save-error")
    let progressRestoreError = arguments.contains("--ui-progress-restore-error")
    let mainTabsPreview = launch.includesMainTabsPreview
    let preview = completionSaveError || uploadPreview || removedProgramPreview || mainTabsPreview || arguments.contains("--ui-workout-storage-error") || arguments.contains("--ui-auth-test") || arguments.contains("--ui-account-setup-error") || arguments.contains("--ui-setup-timeout")
      || arguments.contains("--ui-email-auth") || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-progress-save-error") || arguments.contains("--ui-apple-auth-error")
      || progressRestoreError
      || arguments.contains("--ui-google-auth-error")
      || arguments.contains("--ui-catalog-seed") || arguments.contains("--ui-catalog-seed-edited")
      || arguments.contains("--ui-catalog-offline") || arguments.contains("--ui-workout-banner-fallback")
      || arguments.contains("--ui-workout-banner-legacy") || arguments.contains("--ui-workout-preview-superset")
      || sessionSignOutPreview
    let progressURL = directory.appending(path: preview ? "preview-progress.json" : "progress.json")
    if preview && (!arguments.contains("--ui-progress-keep") || arguments.contains("--ui-progress-reset")) {
      try? FileManager.default.removeItem(at: progressURL)
    }
    if arguments.contains("--ui-development-progress-reset") {
      try? FileManager.default.removeItem(
        at: storage.directory.appending(path: "Development/onboarding.json")
      )
    }
    let previewWorkoutFile = Self.previewWorkoutFile(arguments, restoreError: progressRestoreError, signOut: sessionSignOutPreview, history: historyPreview)
    let previewWorkoutURL = storage.directory.appending(path: "Preview/\(previewWorkoutFile)")
    if arguments.contains("--ui-workouts-reset") || arguments.contains("--ui-finish-review") || arguments.contains("--ui-main-workout-gated")
      || arguments.contains("--ui-switch-programs")
      || arguments.contains("--ui-switch-detail") || setupCycleConflictPreview
      || sessionSignOutPreview || progressRestoreError || programChangePreview || accountDeletionUnsyncedPreview {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(atPath: previewWorkoutURL.path + suffix)
      }
    }
    #else
    let progressURL = directory.appending(path: "progress.json")
    #endif
    let fileStore = FileOnboardingProgressStore(fileURL: progressURL)
    #if DEBUG
    if uploadPreview {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                         selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
        cycleID: setupCycleConflictPreview
          ? PreviewCycleID.previous
          : UUID()
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
    if programChangePreview {
      let old = AccountSetup(preferredUnit: .pounds, trainingDays: 3, programID: "bro-split",
        cycleID: PreviewCycleID.previous)
      var saved = OnboardingProgress(weightUnit: .pounds, trainingDays: 3, selectedProgramID: old.programID, nextStep: .overview)
      saved.completed = CompletedOnboarding(setup: old, needsUpload: false)
      try? fileStore.save(saved, accountID: "preview-user")
    }
    if sessionSignOutPreview {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                        selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
        cycleID: PreviewCycleID.pendingSignOut
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
    let progress: any OnboardingProgressStore = (completionSaveError || arguments.contains("--ui-progress-save-error"))
      ? PreviewOnboardingProgressStore(store: fileStore, completionOnly: completionSaveError) : fileStore
    #else
    let progress: any OnboardingProgressStore = fileStore
    #endif
    #if DEBUG
    if preview {
      let bundledPrograms = ProgramCatalog.bundled.programs.map { program in
        if program.id == "upper-lower",
           arguments.contains("--ui-workout-banner-fallback") || arguments.contains("--ui-workout-banner-legacy") {
          let workouts = program.workouts.map { workout in
            guard workout.id == "upper-lower-lower-a" else { return workout }
            let banner = arguments.contains("--ui-workout-banner-legacy") ? nil : "future-theme-v2"
            return WorkoutTemplate(id: workout.id, name: workout.name, banner: banner, exercises: workout.exercises)
          }
          return TrainingProgram(
            id: program.id, name: program.name, format: program.format, emphasis: program.emphasis,
            workouts: workouts, recommendedWeeks: program.recommendedWeeks, isOffered: program.isOffered
          )
        }
        if program.id == "machine-full-body",
           arguments.contains("--ui-workout-preview-superset") || arguments.contains("--ui-main-workout-superset") {
          let workouts = program.workouts.map { workout in
            guard workout.id == "machine-full-body-workout-a", workout.exercises.count >= 2 else { return workout }
            return WorkoutTemplate(
              id: workout.id, name: workout.name, banner: workout.banner, exercises: workout.exercises,
              supersets: [SupersetPair(firstSlotID: workout.exercises[0].id, secondSlotID: workout.exercises[1].id)]
            )
          }
          return TrainingProgram(
            id: program.id, name: program.name, format: program.format, emphasis: program.emphasis,
            workouts: workouts, recommendedWeeks: program.recommendedWeeks, isOffered: program.isOffered
          )
        }
        guard removedProgramPreview, program.id == "machine-full-body" else { return program }
        return TrainingProgram(
          id: program.id, name: program.name,
          format: program.format, emphasis: program.emphasis, workouts: program.workouts,
          recommendedWeeks: program.recommendedWeeks, isOffered: false
        )
      }
      let catalogURL = storage.directory
        .appending(path: "Catalog", directoryHint: .isDirectory)
        .appending(path: "preview-catalog.json")
      let catalogSeed = arguments.contains("--ui-catalog-seed") || arguments.contains("--ui-catalog-seed-edited")
      if catalogSeed {
        try? FileManager.default.removeItem(at: catalogURL)
      }
      let catalogService: (any ProgramCatalogService)? =
        catalogSeed
        ? PreviewProgramCatalogService(editedProgram: arguments.contains("--ui-catalog-seed-edited")) : nil
      let switchSync = PreviewSwitchSyncService(online: arguments.contains("--ui-switch-online"))
      return AppDependencies(
        catalog: ProgramCatalog(
          programs: bundledPrograms,
          bundledExercises: ProgramCatalog.unassignedBundledExercises,
          service: catalogService,
          persistence: catalogSeed || arguments.contains("--ui-catalog-offline")
            ? FileProgramCatalogPersistence(fileURL: catalogURL) : nil
        ),
        authentication: PreviewAuthenticationService(
          defaults: storage.authenticationDefaults,
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: uploadPreview || mainTabsPreview || arguments.contains("--ui-setup-timeout") || arguments.contains("--ui-auth-restored")
            || arguments.contains("--ui-setup-removed-follower") || arguments.contains("--ui-account-setup-error")
            || arguments.contains("--ui-progress-save-error") || progressRestoreError,
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset"),
          signOutFails: arguments.contains("--ui-auth-signout-error") || arguments.contains("--ui-session-signout-error"),
          googleIncomplete: arguments.contains("--ui-google-incomplete"),
          googleFails: arguments.contains("--ui-google-error") || arguments.contains("--ui-google-auth-error"),
          googleCancels: arguments.contains("--ui-google-cancel"),
          appleCancels: arguments.contains("--ui-apple-cancel"),
          appleFails: arguments.contains("--ui-apple-error") || arguments.contains("--ui-apple-auth-error")
        ),
        onboardingProgress: progress,
        accountSetup: PreviewAccountSetupService(
          arguments: arguments,
          includesMainTabsPreview: launch.includesMainTabsPreview && !sessionSignOutPreview,
          storageDirectory: storage.directory
        ),
        accountCycles: (arguments.contains("--ui-replacement-device") || programChangePreview) ? PreviewRestoredCycles()
          : (arguments.contains("--ui-switch-test") ? switchSync : nil),
        previousPerformance: PreviewPreviousPerformanceService(),
        accountProgress: (arguments.contains("--ui-replacement-device") || programChangePreview) ? PreviewRestoredProgress()
          : (progressRestoreError ? PreviewAccountProgressService(fails: true) : nil),
        completedSessionUpload: arguments.contains("--ui-switch-online") ? switchSync : nil,
        sessionHistory: PreviewSessionHistoryService(
          pages: arguments.contains("--ui-history-pagination")
            ? [[Self.previewDownloadedHistorySession(
                id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", workout: "machine-full-body-workout-b",
                startedAt: Date(timeIntervalSince1970: 1_801_000_000), day: 2
              )], [Self.previewDownloadedHistorySession(
                id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", workout: "machine-full-body-workout-a",
                startedAt: Date(timeIntervalSince1970: 1_792_000_000), day: 1
              )]]
            : (arguments.contains("--ui-history-offline-boundary")
              ? [[Self.previewDownloadedHistorySession(
                  id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", workout: "machine-full-body-workout-b",
                  startedAt: Date(timeIntervalSince1970: 1_801_000_000), day: 2
                )]] : []),
          failsInitial: arguments.contains("--ui-history-error") || arguments.contains("--ui-history-refresh-error"),
          failsOlder: arguments.contains("--ui-history-offline-boundary")
        ),
        subscriptionAccess: Self.previewSubscriptionAccess(launch: launch, arguments: arguments),
        workoutRepositoryFactory: {
          if arguments.contains("--ui-workout-storage-error") {
            throw CocoaError(.fileReadNoPermission)
          }
          let repository = try WorkoutRepository(databaseURL: previewWorkoutURL)
          if arguments.contains("--ui-program-change-active"),
             let program = ProgramCatalog.bundled.program(id: "bro-split"), let workout = program.workouts.first {
            let session = WorkoutSession(accountID: "preview-user",
              cycleID: PreviewCycleID.previous,
              program: program, workout: workout, week: 1, day: 1, weightUnit: .pounds, startedAt: .now)
            _ = try repository.start(session)
          }
          if sessionSignOutPreview {
            try Self.seedCompletedPreviewSession(
              in: repository,
              cycleID: PreviewCycleID.pendingSignOut,
              startedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
          }
          if accountDeletionUnsyncedPreview {
            try Self.seedCompletedPreviewSession(
              in: repository,
              cycleID: PreviewCycleID.pendingSignOut,
              startedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
          }
          if setupCycleConflictPreview {
            try Self.seedCompletedPreviewSession(
              in: repository,
              cycleID: PreviewCycleID.previous,
              startedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
          }
          if historyPreview && (arguments.contains("--ui-history-populated")
            || arguments.contains("--ui-history-partial-detail")
            || arguments.contains("--ui-history-refresh-error")) {
            try Self.seedHistoryPreviewSessions(in: repository)
          }
          return repository
        },
        accountDeletion: AccountDeletionServices(
          service: PreviewAccountDeletionService(arguments: arguments),
          onboardingProgress: progress,
          savedSubscriptionAccess: FileSavedSubscriptionAccessStore(
            fileURL: storage.directory.appending(path: "Preview/saved-access.json")),
          pendingSubscriptionOperations: FilePendingSubscriptionOperationStore(
            fileURL: storage.directory.appending(path: "Preview/pending-operations.json"))
        )
      )
    }
    #endif

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
  private static func previewWorkoutFile(
    _ arguments: [String], restoreError: Bool, signOut: Bool, history: Bool
  ) -> String {
    if arguments.contains("--ui-finish-review") { return "finish-review-workouts.sqlite" }
    if restoreError { return "progress-restore-error-workouts.sqlite" }
    if signOut { return "session-signout-workouts.sqlite" }
    return history ? "history-preview-workouts.sqlite" : "workouts.sqlite"
  }

  /// Setup journeys stay on the trial screen unless a test presets Pro. Tab previews and
  /// accounts with completed setup start with Pro.
  private static func previewSubscriptionAccess(
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
  private static func seedCompletedPreviewSession(
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

  private static func seedHistoryPreviewSessions(in repository: WorkoutRepository) throws {
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

  private static func previewDownloadedHistorySession(
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
private struct PreviewProgramCatalogService: ProgramCatalogService {
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
private final class PreviewSwitchSyncService: AccountCycleService, CompletedSessionUploadService {
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
private struct PreviewRestoredCycles: AccountCycleService {
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
private struct PreviewRestoredProgress: AccountProgressService {
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
