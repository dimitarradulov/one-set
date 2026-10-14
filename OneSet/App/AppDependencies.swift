import Foundation

@MainActor
struct AppDependencies {
  let catalog: ProgramCatalog
  let authentication: any AuthenticationService
  let onboardingProgress: any OnboardingProgressStore
  let accountSetup: any AccountSetupService

  static func live(arguments: [String]) -> AppDependencies {
    let directory = URL.applicationSupportDirectory.appending(path: "Onboarding")
    #if DEBUG
    let uploadPreview = arguments.contains("--ui-setup-upload-pending")
      || arguments.contains("--ui-setup-upload-discard") || arguments.contains("--ui-setup-upload-removed")
    let removedProgramPreview = arguments.contains("--ui-programs-removed")
      || arguments.contains("--ui-setup-removed-follower") || arguments.contains("--ui-setup-upload-removed")
    let completionSaveError = arguments.contains("--ui-completion-save-error")
    let preview = completionSaveError || uploadPreview || removedProgramPreview || arguments.contains("--ui-auth-test") || arguments.contains("--ui-account-setup-error")
      || arguments.contains("--ui-email-auth") || arguments.contains("--ui-auth-persist-session-test")
      || arguments.contains("--ui-progress-save-error") || arguments.contains("--ui-apple-auth-error")
      || arguments.contains("--ui-google-auth-error")
      || arguments.contains("--ui-catalog-seed") || arguments.contains("--ui-catalog-seed-edited")
      || arguments.contains("--ui-catalog-offline")
    let progressURL = directory.appending(path: preview ? "preview-progress.json" : "progress.json")
    if preview && (!arguments.contains("--ui-progress-keep") || arguments.contains("--ui-progress-reset")) {
      try? FileManager.default.removeItem(at: progressURL)
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
        preferredUnit: .pounds, trainingDays: 3, programID: "machine-full-body", cycleID: UUID()
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
        guard removedProgramPreview, program.id == "machine-full-body" else { return program }
        return TrainingProgram(
          id: program.id, name: program.name, trainingDaysPerWeek: program.trainingDaysPerWeek,
          format: program.format, emphasis: program.emphasis, workouts: program.workouts,
          recommendedWeeks: program.recommendedWeeks, isOffered: false
        )
      }
      let catalogURL = URL.applicationSupportDirectory
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
          emailIsRegistered: arguments.contains("--ui-auth-existing"),
          startsSignedIn: uploadPreview || arguments.contains("--ui-auth-restored")
            || arguments.contains("--ui-setup-removed-follower") || arguments.contains("--ui-account-setup-error")
            || arguments.contains("--ui-progress-save-error"),
          persistsSession: arguments.contains("--ui-auth-persist-session-test"),
          resetPersistedSession: arguments.contains("--ui-auth-reset"),
          signOutFails: arguments.contains("--ui-auth-signout-error"),
          googleIncomplete: arguments.contains("--ui-google-incomplete"),
          googleFails: arguments.contains("--ui-google-error") || arguments.contains("--ui-google-auth-error"),
          googleCancels: arguments.contains("--ui-google-cancel"),
          appleCancels: arguments.contains("--ui-apple-cancel"),
          appleFails: arguments.contains("--ui-apple-error") || arguments.contains("--ui-apple-auth-error")
        ),
        onboardingProgress: progress,
        accountSetup: PreviewAccountSetupService(arguments: arguments)
      )
    }
    #endif

    let authentication = ClerkAuthenticationService()
    let catalogDirectory = URL.applicationSupportDirectory.appending(path: "Catalog")
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
      accountSetup: HTTPAccountSetupService(authentication: authentication)
    )
  }
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
        id: current.id, name: "Push Pull Legs Updated", trainingDaysPerWeek: current.trainingDaysPerWeek,
        format: current.format, emphasis: "Updated publication for refresh continuity.",
        workouts: current.workouts, recommendedWeeks: current.recommendedWeeks, isOffered: current.isOffered
      )
    }
    programs.append(TrainingProgram(
      id: "founder-authored-plan", name: "Founder Authored Plan", trainingDaysPerWeek: 3,
      format: "A / B / C", emphasis: "A newly published plan.",
      workouts: [WorkoutTemplate(id: "founder-authored-plan-day-a", name: "Day A", exercises: [
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
