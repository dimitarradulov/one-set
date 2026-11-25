import Foundation

#if DEBUG
/// The launch arguments that put the app into a fixed preview state for UI tests and simulator routes.
struct PreviewLaunchFlags {
  let arguments: [String]
  let launch: AppLaunchConfiguration
  let uploadPreview: Bool
  let setupCycleConflict: Bool
  let programChange: Bool
  let sessionSignOut: Bool
  let history: Bool
  let removedProgram: Bool
  let accountDeletionUnsynced: Bool
  let completionSaveError: Bool
  let progressRestoreError: Bool
  let mainTabs: Bool

  init(arguments: [String]) {
    self.arguments = arguments
    launch = AppLaunchConfiguration(arguments: arguments)
    uploadPreview = Self.any(arguments, [
      "--ui-setup-upload-pending", "--ui-setup-upload-discard", "--ui-setup-upload-removed",
      "--ui-setup-cycle-conflict"
    ])
    setupCycleConflict = arguments.contains("--ui-setup-cycle-conflict")
    programChange = Self.any(arguments, [
      "--ui-program-change", "--ui-program-change-preview", "--ui-program-change-active"
    ])
    sessionSignOut = Self.any(arguments, ["--ui-session-signout-confirmation", "--ui-session-signout-error"])
    history = Self.any(arguments, [
      "--ui-history-populated", "--ui-history-partial-detail", "--ui-history-empty", "--ui-history-error",
      "--ui-history-refresh-error", "--ui-history-pagination", "--ui-history-offline-boundary"
    ])
    removedProgram = Self.any(arguments, [
      "--ui-programs-removed", "--ui-setup-removed-follower", "--ui-setup-upload-removed"
    ])
    accountDeletionUnsynced = arguments.contains("--ui-account-deletion-unsynced")
    completionSaveError = arguments.contains("--ui-completion-save-error")
    progressRestoreError = arguments.contains("--ui-progress-restore-error")
    mainTabs = launch.includesMainTabsPreview
  }

  func has(_ argument: String) -> Bool { arguments.contains(argument) }

  func hasAny(_ candidates: [String]) -> Bool { Self.any(arguments, candidates) }

  /// True when any preview state is requested, so the app uses preview services instead of live ones.
  var isPreview: Bool {
    completionSaveError || uploadPreview || removedProgram || mainTabs || progressRestoreError || sessionSignOut
      || hasAny([
        "--ui-workout-storage-error", "--ui-auth-test", "--ui-account-setup-error", "--ui-setup-timeout",
        "--ui-email-auth", "--ui-auth-persist-session-test", "--ui-progress-save-error",
        "--ui-apple-auth-error", "--ui-google-auth-error", "--ui-catalog-seed", "--ui-catalog-seed-edited",
        "--ui-catalog-offline", "--ui-workout-banner-fallback", "--ui-workout-banner-legacy",
        "--ui-workout-preview-superset"
      ])
  }

  /// True when the preview workout database must start empty.
  var resetsWorkouts: Bool {
    setupCycleConflict || sessionSignOut || progressRestoreError || programChange || accountDeletionUnsynced
      || hasAny([
        "--ui-workouts-reset", "--ui-finish-review", "--ui-main-workout-gated", "--ui-switch-programs",
        "--ui-switch-detail"
      ])
  }

  private static func any(_ arguments: [String], _ candidates: [String]) -> Bool {
    candidates.contains(where: arguments.contains)
  }
}

extension AppDependencies {
  /// Prepares preview storage for the launch arguments and returns preview dependencies, or nil
  /// when no preview state is requested and the app should use live services.
  static func launchPreview(
    arguments: [String], storage: AppStorage, onboardingDirectory directory: URL
  ) -> AppDependencies? {
    let flags = PreviewLaunchFlags(arguments: arguments)
    let preview = flags.isPreview
    let progressURL = directory.appending(path: preview ? "preview-progress.json" : "progress.json")
    if preview && (!flags.has("--ui-progress-keep") || flags.has("--ui-progress-reset")) {
      try? FileManager.default.removeItem(at: progressURL)
    }
    if flags.has("--ui-development-progress-reset") {
      try? FileManager.default.removeItem(at: storage.directory.appending(path: "Development/onboarding.json"))
    }
    let previewWorkoutFile = Self.previewWorkoutFile(
      arguments, restoreError: flags.progressRestoreError, signOut: flags.sessionSignOut, history: flags.history
    )
    let previewWorkoutURL = storage.directory.appending(path: "Preview/\(previewWorkoutFile)")
    if flags.resetsWorkouts {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(atPath: previewWorkoutURL.path + suffix)
      }
    }
    guard preview else { return nil }

    let fileStore = FileOnboardingProgressStore(fileURL: progressURL)
    seedPreviewProgress(in: fileStore, flags: flags)
    let progress: any OnboardingProgressStore = (flags.completionSaveError || flags.has("--ui-progress-save-error"))
      ? PreviewOnboardingProgressStore(store: fileStore, completionOnly: flags.completionSaveError) : fileStore
    return previewDependencies(
      flags: flags, storage: storage, progress: progress, workoutURL: previewWorkoutURL
    )
  }

  private static func previewDependencies(
    flags: PreviewLaunchFlags, storage: AppStorage, progress: any OnboardingProgressStore, workoutURL: URL
  ) -> AppDependencies {
    let arguments = flags.arguments
    let switchSync = PreviewSwitchSyncService(online: flags.has("--ui-switch-online"))
    let restoresDevice = flags.has("--ui-replacement-device") || flags.programChange
    return AppDependencies(
      catalog: previewCatalog(flags: flags, storage: storage),
      authentication: previewAuthentication(flags: flags, storage: storage),
      onboardingProgress: progress,
      accountSetup: PreviewAccountSetupService(
        arguments: arguments,
        includesMainTabsPreview: flags.launch.includesMainTabsPreview && !flags.sessionSignOut,
        storageDirectory: storage.directory
      ),
      accountCycles: restoresDevice ? PreviewRestoredCycles()
        : (flags.has("--ui-switch-test") ? switchSync : nil),
      previousPerformance: PreviewPreviousPerformanceService(),
      accountProgress: restoresDevice ? PreviewRestoredProgress()
        : (flags.progressRestoreError ? PreviewAccountProgressService(fails: true) : nil),
      completedSessionUpload: flags.has("--ui-switch-online") ? switchSync : nil,
      sessionHistory: previewSessionHistory(flags: flags),
      subscriptionAccess: Self.previewSubscriptionAccess(launch: flags.launch, arguments: arguments),
      workoutRepositoryFactory: previewWorkoutRepositoryFactory(flags: flags, databaseURL: workoutURL),
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

  private static func seedPreviewProgress(in fileStore: FileOnboardingProgressStore, flags: PreviewLaunchFlags) {
    if flags.uploadPreview {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                        selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
        cycleID: flags.setupCycleConflict ? PreviewCycleID.previous : UUID()
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
    if flags.programChange {
      let old = AccountSetup(preferredUnit: .pounds, trainingDays: 3, programID: "bro-split",
                             cycleID: PreviewCycleID.previous)
      var saved = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                     selectedProgramID: old.programID, nextStep: .overview)
      saved.completed = CompletedOnboarding(setup: old, needsUpload: false)
      try? fileStore.save(saved, accountID: "preview-user")
    }
    if flags.sessionSignOut {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                        selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
        cycleID: PreviewCycleID.pendingSignOut
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
  }

  private static func previewCatalog(flags: PreviewLaunchFlags, storage: AppStorage) -> ProgramCatalog {
    let catalogURL = storage.directory
      .appending(path: "Catalog", directoryHint: .isDirectory)
      .appending(path: "preview-catalog.json")
    let catalogSeed = flags.hasAny(["--ui-catalog-seed", "--ui-catalog-seed-edited"])
    if catalogSeed {
      try? FileManager.default.removeItem(at: catalogURL)
    }
    let catalogService: (any ProgramCatalogService)? = catalogSeed
      ? PreviewProgramCatalogService(editedProgram: flags.has("--ui-catalog-seed-edited")) : nil
    return ProgramCatalog(
      programs: ProgramCatalog.bundled.programs.map { previewProgram($0, flags: flags) },
      bundledExercises: ProgramCatalog.unassignedBundledExercises,
      service: catalogService,
      persistence: catalogSeed || flags.has("--ui-catalog-offline")
        ? FileProgramCatalogPersistence(fileURL: catalogURL) : nil
    )
  }

  /// Applies the banner, superset, and removed-program preview variants to a bundled program.
  private static func previewProgram(_ program: TrainingProgram, flags: PreviewLaunchFlags) -> TrainingProgram {
    if program.id == "upper-lower", flags.hasAny(["--ui-workout-banner-fallback", "--ui-workout-banner-legacy"]) {
      let workouts = program.workouts.map { workout in
        guard workout.id == "upper-lower-lower-a" else { return workout }
        let banner = flags.has("--ui-workout-banner-legacy") ? nil : "future-theme-v2"
        return WorkoutTemplate(id: workout.id, name: workout.name, banner: banner, exercises: workout.exercises)
      }
      return program.replacingWorkouts(workouts)
    }
    if program.id == "machine-full-body",
       flags.hasAny(["--ui-workout-preview-superset", "--ui-main-workout-superset"]) {
      let workouts = program.workouts.map { workout in
        guard workout.id == "machine-full-body-workout-a", workout.exercises.count >= 2 else { return workout }
        return WorkoutTemplate(
          id: workout.id, name: workout.name, banner: workout.banner, exercises: workout.exercises,
          supersets: [SupersetPair(firstSlotID: workout.exercises[0].id, secondSlotID: workout.exercises[1].id)]
        )
      }
      return program.replacingWorkouts(workouts)
    }
    guard flags.removedProgram, program.id == "machine-full-body" else { return program }
    return TrainingProgram(
      id: program.id, name: program.name,
      format: program.format, emphasis: program.emphasis, workouts: program.workouts,
      recommendedWeeks: program.recommendedWeeks, isOffered: false
    )
  }

  private static func previewAuthentication(
    flags: PreviewLaunchFlags, storage: AppStorage
  ) -> PreviewAuthenticationService {
    PreviewAuthenticationService(
      defaults: storage.authenticationDefaults,
      emailIsRegistered: flags.has("--ui-auth-existing"),
      startsSignedIn: flags.uploadPreview || flags.mainTabs || flags.progressRestoreError
        || flags.hasAny([
          "--ui-setup-timeout", "--ui-auth-restored", "--ui-setup-removed-follower",
          "--ui-account-setup-error", "--ui-progress-save-error"
        ]),
      persistsSession: flags.has("--ui-auth-persist-session-test"),
      resetPersistedSession: flags.has("--ui-auth-reset"),
      signOutFails: flags.hasAny(["--ui-auth-signout-error", "--ui-session-signout-error"]),
      googleIncomplete: flags.has("--ui-google-incomplete"),
      googleFails: flags.hasAny(["--ui-google-error", "--ui-google-auth-error"]),
      googleCancels: flags.has("--ui-google-cancel"),
      appleCancels: flags.has("--ui-apple-cancel"),
      appleFails: flags.hasAny(["--ui-apple-error", "--ui-apple-auth-error"])
    )
  }

  private static func previewSessionHistory(flags: PreviewLaunchFlags) -> PreviewSessionHistoryService {
    let newer = Self.previewDownloadedHistorySession(
      id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", workout: "machine-full-body-workout-b",
      startedAt: Date(timeIntervalSince1970: 1_801_000_000), day: 2
    )
    let older = Self.previewDownloadedHistorySession(
      id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", workout: "machine-full-body-workout-a",
      startedAt: Date(timeIntervalSince1970: 1_792_000_000), day: 1
    )
    let pages: [[WorkoutSession]]
    if flags.has("--ui-history-pagination") {
      pages = [[newer], [older]]
    } else if flags.has("--ui-history-offline-boundary") {
      pages = [[newer]]
    } else {
      pages = []
    }
    return PreviewSessionHistoryService(
      pages: pages,
      failsInitial: flags.hasAny(["--ui-history-error", "--ui-history-refresh-error"]),
      failsOlder: flags.has("--ui-history-offline-boundary")
    )
  }

  private static func previewWorkoutRepositoryFactory(
    flags: PreviewLaunchFlags, databaseURL: URL
  ) -> @MainActor () throws -> WorkoutRepository {
    {
      if flags.has("--ui-workout-storage-error") {
        throw CocoaError(.fileReadNoPermission)
      }
      let repository = try WorkoutRepository(databaseURL: databaseURL)
      if flags.has("--ui-program-change-active"),
         let program = ProgramCatalog.bundled.program(id: "bro-split"), let workout = program.workouts.first {
        let session = WorkoutSession(accountID: "preview-user",
          cycleID: PreviewCycleID.previous,
          program: program, workout: workout, week: 1, day: 1, weightUnit: .pounds, startedAt: .now)
        _ = try repository.start(session)
      }
      let previewStart = Date(timeIntervalSince1970: 1_800_000_000)
      if flags.sessionSignOut {
        try Self.seedCompletedPreviewSession(in: repository, cycleID: PreviewCycleID.pendingSignOut, startedAt: previewStart)
      }
      if flags.accountDeletionUnsynced {
        try Self.seedCompletedPreviewSession(in: repository, cycleID: PreviewCycleID.pendingSignOut, startedAt: previewStart)
      }
      if flags.setupCycleConflict {
        try Self.seedCompletedPreviewSession(in: repository, cycleID: PreviewCycleID.previous, startedAt: previewStart)
      }
      if flags.history && flags.hasAny([
        "--ui-history-populated", "--ui-history-partial-detail", "--ui-history-refresh-error"
      ]) {
        try Self.seedHistoryPreviewSessions(in: repository)
      }
      return repository
    }
  }
}

private extension TrainingProgram {
  func replacingWorkouts(_ workouts: [WorkoutTemplate]) -> TrainingProgram {
    TrainingProgram(
      id: id, name: name, format: format, emphasis: emphasis,
      workouts: workouts, recommendedWeeks: recommendedWeeks, isOffered: isOffered
    )
  }
}
#endif
