import Foundation

@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService
  let onboardingProgress: any OnboardingProgressStore
  let accountSetup: any AccountSetupService
  let previousPerformance: any PreviousPerformanceService
  let accountProgress: (any AccountProgressService)?
  let completedSessionUpload: (any CompletedSessionUploadService)?
  let workoutRepositoryFactory: @MainActor () throws -> WorkoutRepository

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
      previousPerformance: PreviewPreviousPerformanceService(),
      accountProgress: nil,
      completedSessionUpload: nil,
      workoutRepositoryFactory: { try WorkoutRepository(databaseURL: workoutURL) }
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
    let sessionSignOutPreview = arguments.contains("--ui-session-signout-confirmation")
      || arguments.contains("--ui-session-signout-error")
    let removedProgramPreview = arguments.contains("--ui-programs-removed")
      || arguments.contains("--ui-setup-removed-follower") || arguments.contains("--ui-setup-upload-removed")
    let completionSaveError = arguments.contains("--ui-completion-save-error")
    let progressRestoreError = arguments.contains("--ui-progress-restore-error")
    let mainTabsPreview = launch.includesMainTabsPreview
    let preview = completionSaveError || uploadPreview || removedProgramPreview || mainTabsPreview || arguments.contains("--ui-workout-storage-error") || arguments.contains("--ui-auth-test") || arguments.contains("--ui-account-setup-error")
      || arguments.contains("--ui-email-auth") || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-progress-save-error") || arguments.contains("--ui-apple-auth-error")
      || progressRestoreError
      || arguments.contains("--ui-google-auth-error")
      || arguments.contains("--ui-catalog-seed") || arguments.contains("--ui-catalog-seed-edited")
      || arguments.contains("--ui-catalog-offline") || arguments.contains("--ui-workout-banner-fallback")
      || arguments.contains("--ui-workout-banner-legacy")
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
    let previewWorkoutFile = progressRestoreError ? "progress-restore-error-workouts.sqlite"
      : (sessionSignOutPreview ? "session-signout-workouts.sqlite" : "workouts.sqlite")
    let previewWorkoutURL = storage.directory.appending(path: "Preview/\(previewWorkoutFile)")
    if arguments.contains("--ui-workouts-reset") || setupCycleConflictPreview || sessionSignOutPreview || progressRestoreError {
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
          ? UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
          : UUID()
      ), needsUpload: true)
      try? fileStore.save(progress, accountID: "preview-user")
    }
    if sessionSignOutPreview {
      var progress = OnboardingProgress(weightUnit: .pounds, trainingDays: 3,
                                        selectedProgramID: "machine-full-body", nextStep: .overview)
      progress.completed = CompletedOnboarding(setup: AccountSetup(
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body",
        cycleID: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
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
      return AppDependencies(
        catalog: ProgramCatalog(
          programs: bundledPrograms,
          service: catalogService,
          persistence: catalogSeed || arguments.contains("--ui-catalog-offline")
            ? FileProgramCatalogPersistence(fileURL: catalogURL) : nil
        ),
        authentication: PreviewAuthenticationService(
          defaults: storage.authenticationDefaults,
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: uploadPreview || mainTabsPreview || arguments.contains("--ui-auth-restored")
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
        previousPerformance: PreviewPreviousPerformanceService(),
        accountProgress: progressRestoreError ? PreviewAccountProgressService(fails: true) : nil,
        completedSessionUpload: nil,
        workoutRepositoryFactory: {
          if arguments.contains("--ui-workout-storage-error") {
            throw CocoaError(.fileReadNoPermission)
          }
          let repository = try WorkoutRepository(databaseURL: previewWorkoutURL)
          if sessionSignOutPreview {
            try Self.seedCompletedPreviewSession(
              in: repository,
              cycleID: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
              startedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
          }
          if setupCycleConflictPreview {
            try Self.seedCompletedPreviewSession(
              in: repository,
              cycleID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
              startedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
          }
          return repository
        }
      )
    }
    #endif

    let authentication = ClerkAuthenticationService()
    let catalogDirectory = storage.directory.appending(path: "Catalog")
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
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
      previousPerformance: HTTPPreviousPerformanceService(authentication: authentication),
      accountProgress: HTTPAccountProgressService(authentication: authentication),
      completedSessionUpload: HTTPCompletedSessionUploadService(authentication: authentication),
      workoutRepositoryFactory: {
        try WorkoutRepository(databaseURL: storage.directory.appending(path: "Workouts/workouts.sqlite"))
      }
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
