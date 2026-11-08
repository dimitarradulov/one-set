import Foundation
import Observation

@MainActor
@Observable
final class OnboardingModel {
  var path: [OnboardingRoute]
  var programPath: [OnboardingRoute]
  var settingsPath: [SettingsDestination]
  var selectedMainTab: MainTab
  var weightUnit: WeightUnit = .kilograms
  var trainingDays = 3
  private(set) var selectedProgramID: TrainingProgram.ID?

  enum SetupResolution {
    case idle
    case loading
    case failed(String)
  }

  private(set) var setupResolution: SetupResolution = .idle
  private(set) var restoredCycleID: UUID?
  var switchBlockedPresented = false
  var signOutConfirmationPresented = false
  private var signOutConfirmationAccountID: String?
  var discardSetupPresented = false
  var pendingSessionSignOutPresented = false
  private(set) var pendingSessionSignOutMessage = ""
  private var pendingSessionSignOutDiscardsSetup = false
  private var pendingSessionSignOutAccountID: String?
  private(set) var uploadMessage: String?
  private(set) var programSelectionMessage: String?
  var requiresProgramUpdate: Bool { savedProgress?.pendingRemoteSelection != nil }
  var programUpdateDefaultMessage: String {
    savedProgress?.remoteSelectionDiscoveryPending == true
      ? "Your program couldn’t be checked. Update to check before starting a workout."
      : "Your program changed on another device. Update to start new workouts."
  }
  private(set) var programUpdateMessage: String?
  private var uploadingGeneration: Int?
  var hasCompletedSetup: Bool { savedProgress?.completed != nil || restoredCycleID != nil }
  var hasPendingSetup: Bool { savedProgress?.completed?.needsUpload == true }
  var signOutErrorPresented = false
  private(set) var signOutErrorMessage = ""
  var progressErrorPresented = false
  private(set) var progressErrorMessage = ""
  private let progressStore: (any OnboardingProgressStore)?
  private var savedProgress: OnboardingProgress?
  private var isSigningOut = false
  private var didResolveInitialAccount = false
  private let setupService: (any AccountSetupService)?
  private let cycleService: (any AccountCycleService)?
  private let cycleSyncCoordinator: ProgramCycleSyncCoordinator
  private var cycleKnowledgeGeneration = 0
  private var cycleDiscoveryGeneration = 0
  private(set) var cycleMessage: String?
  var cycleConflictMessage: String? {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--ui-switch-conflict") {
      return Self.cycleConflictText
    }
    #endif
    guard let state = savedProgress?.cycles,
          state.rejectedCycleIDs?.isEmpty == false || state.rejectedActivationIDs?.isEmpty == false else { return nil }
    return Self.cycleConflictText
  }
  private static let cycleConflictText = "A program change couldn’t be saved to your account. The program may no longer be available. Choose an available program and keep this device to preserve your workouts."
  private let previousPerformanceService: (any PreviousPerformanceService)?
  private let progressService: (any AccountProgressService)?
  private var lookupGeneration = 0
  private var resolvedAccountID: String?
  private let catalog: ProgramCatalog
  private var workoutRepository: WorkoutRepository?
  private var completedSessionUploadCoordinator: CompletedSessionUploadCoordinator?
  private let completedSessionUploadService: (any CompletedSessionUploadService)?
  private let sessionHistoryService: (any SessionHistoryService)?
  private let waitForSessionUploadRetry: @MainActor (TimeInterval) async throws -> Void
  private let workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)?
  private(set) var activeWorkoutSession: WorkoutSession?
  var workoutErrorPresented = false
  private(set) var workoutErrorMessage = ""
  var sessionUploadErrorPresented = false
  private(set) var sessionUploadErrorMessage = ""
  private(set) var workoutStorageOpenFailed = false
  private(set) var previousPerformanceUnavailable = false

  init(
    catalog: ProgramCatalog,
    setupService: (any AccountSetupService)? = nil,
    cycleService: (any AccountCycleService)? = nil,
    cycleSyncCoordinator: ProgramCycleSyncCoordinator = ProgramCycleSyncCoordinator(),
    previousPerformanceService: (any PreviousPerformanceService)? = nil,
    progressService: (any AccountProgressService)? = nil,
    completedSessionUploadService: (any CompletedSessionUploadService)? = nil,
    sessionHistoryService: (any SessionHistoryService)? = nil,
    waitForSessionUploadRetry: @escaping @MainActor (TimeInterval) async throws -> Void = { delay in
      try await Task.sleep(for: .seconds(delay))
    },
    progressStore: (any OnboardingProgressStore)? = nil,
    workoutRepository: WorkoutRepository? = nil,
    workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil,
    initialProgramPath: [OnboardingRoute] = [],
    initialSettingsPath: [SettingsDestination] = [],
    initialMainTab: MainTab = .program
  ) {
    self.catalog = catalog
    self.setupService = setupService
    self.cycleService = cycleService
    self.cycleSyncCoordinator = cycleSyncCoordinator
    self.previousPerformanceService = previousPerformanceService
    self.progressService = progressService
    self.progressStore = progressStore
    self.workoutRepositoryFactory = workoutRepositoryFactory
    self.completedSessionUploadService = completedSessionUploadService
    self.sessionHistoryService = sessionHistoryService
    self.waitForSessionUploadRetry = waitForSessionUploadRetry
    do {
      self.workoutRepository = try workoutRepository ?? workoutRepositoryFactory?()
    } catch {
      self.workoutRepository = nil
      workoutStorageOpenFailed = true
      workoutErrorMessage = "Workout storage couldn’t be opened. Your saved workouts are still on this device. Try opening storage again.\n\(error.localizedDescription)"
      workoutErrorPresented = true
    }
    path = initialPath
    selectedProgramID = initialSelectedProgramID
    programPath = initialProgramPath
    settingsPath = initialSettingsPath
    selectedMainTab = initialMainTab
    configureCompletedSessionUploads()
  }

  private func configureCompletedSessionUploads() {
    completedSessionUploadCoordinator?.cancelPendingWork()
    completedSessionUploadCoordinator = nil
    if let repository = workoutRepository, let completedSessionUploadService {
      completedSessionUploadCoordinator = CompletedSessionUploadCoordinator(
        repository: repository,
        service: completedSessionUploadService,
        waitForRetry: waitForSessionUploadRetry
      )
    }
  }

  func resolveAccountSetup(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser else {
      if resolvedAccountID != nil || !isSetupIdle { resetAccount() }
      return
    }
    guard !isSigningOut, resolvedAccountID != user.id, let setupService else { return }
    resetAccount(preservingNavigation: !didResolveInitialAccount)
    didResolveInitialAccount = true
    lookupGeneration += 1
    let generation = lookupGeneration
    setupResolution = .loading
    var discoveryReservation: OnboardingProgress?
    var discoveryReturned = false
    var discoveryStorageFailure = false
    do {
      await catalog.refresh()
      savedProgress = try progressStore?.load(accountID: user.id)
      if let savedProgress { try validate(savedProgress) }
      // Persist a fail-closed reservation before asking the server. A crash or a
      // failed subsequent write must not turn a discovered change into offline access.
      if var local = savedProgress, local.pendingRemoteSelection == nil,
         let completed = local.completed, !completed.needsUpload,
         local.cycles?.pendingCreations.isEmpty != false,
         (local.cycles?.pendingActivations ?? []).isEmpty {
        guard let progressStore else { throw AccountSetupError.unavailable }
        discoveryReservation = local
        local.pendingRemoteSelection = AccountSetup(preferredUnit: local.weightUnit,
          trainingDays: local.trainingDays, programID: local.cycles?.selectedProgramID ?? completed.setup.programID,
          cycleID: local.cycles?.selectedCycleID ?? completed.setup.cycleID)
        local.remoteSelectionDiscoveryPending = true
        savedProgress = local
        discoveryStorageFailure = true
        try progressStore.save(local, accountID: user.id)
        discoveryStorageFailure = false
      }
      let setup = try await setupService.lookup(for: user)
      discoveryReturned = true
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if let setup {
        if var local = savedProgress, let completed = local.completed,
           !completed.needsUpload, local.cycles?.pendingCreations.isEmpty != false,
           (local.cycles?.pendingActivations ?? []).isEmpty {
          let currentProgram = local.cycles?.selectedProgramID ?? completed.setup.programID
          let currentCycle = local.cycles?.selectedCycleID ?? completed.setup.cycleID
          let changed = setup.programID != currentProgram || setup.cycleID != currentCycle
          if changed || discoveryReservation == nil && local.pendingRemoteSelection != nil
              && local.remoteSelectionDiscoveryPending != true {
            local.pendingRemoteSelection = setup
          } else if discoveryReservation != nil || local.remoteSelectionDiscoveryPending == true {
            local.pendingRemoteSelection = nil
          }
          local.remoteSelectionDiscoveryPending = nil
          discoveryStorageFailure = true
          try progressStore?.save(local, accountID: user.id)
          discoveryStorageFailure = false
          savedProgress = local
          discoveryReservation = nil
        }
        if let local = savedProgress, local.pendingRemoteSelection != nil {
          restore(local)
        } else {
        if let pending = savedProgress?.completed, pending.needsUpload,
           pending.setup.cycleID != setup.cycleID {
          _ = try workoutRepository?.blockSessionUploadsForSetupCycle(
            accountID: user.id, cycleID: pending.setup.cycleID, establishedCycleID: setup.cycleID
          )
        }
        try storeCompleted(setup, needsUpload: false, accountID: user.id)
        apply(setup)
        if let cycles = savedProgress?.cycles,
           !cycles.pendingCreations.isEmpty || !(cycles.pendingActivations ?? []).isEmpty {
          selectedProgramID = cycles.selectedProgramID
          restoredCycleID = cycles.selectedCycleID
          path = [.programOverview(cycles.selectedProgramID)]
          if cycles.authenticationDeferred == true {
            cycleMessage = "Sign in again to sync your program change. Your workouts remain on this device."
          }
        }
        if let progressService, restoredCycleID == setup.cycleID {
          do {
            let summary = try await progressService.lookup(for: user)
            guard !Task.isCancelled, generation == lookupGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            guard let summary,
                  summary.cycleID == setup.cycleID, summary.programID == setup.programID else {
              throw AccountSetupError.unavailable
            }
            try workoutRepository?.restoreProgress(summary, accountID: user.id)
          } catch {
            guard !Task.isCancelled, generation == lookupGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            guard try workoutRepository?.hasRestorableProgress(accountID: user.id, cycleID: setup.cycleID) == true else {
              setupResolution = .failed("Your training progress couldn’t be restored. Retry to continue.")
              return
            }
          }
        }
        }
      } else if let original = discoveryReservation {
        discoveryStorageFailure = true
        try progressStore?.save(original, accountID: user.id)
        discoveryStorageFailure = false
        savedProgress = original
        discoveryReservation = nil
        restore(original)
      } else if let savedProgress {
        restore(savedProgress)
      } else {
        let progress = OnboardingProgress(
          weightUnit: .kilograms, trainingDays: 3, selectedProgramID: nil, nextStep: .preferences
        )
        try progressStore?.save(progress, accountID: user.id)
        savedProgress = progress
        weightUnit = .kilograms
        trainingDays = 3
        selectedProgramID = nil
        restoredCycleID = nil
        path = [.preferences]
      }
      resolvedAccountID = user.id
      releaseReofferedCycleOperations()
      activeWorkoutSession = try workoutRepository?.activeSession(accountID: user.id)
      if let activeWorkoutSession {
        selectedMainTab = .program
        programPath = [.workoutRecording(activeWorkoutSession.id)]
      }
      presentSessionUploadErrorIfNeeded(accountID: user.id)
      setupResolution = .idle
      await refreshPreviousPerformances(for: user, generation: generation, authentication: authentication)
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if !discoveryStorageFailure, !discoveryReturned, let original = discoveryReservation, let progressStore,
         (try? progressStore.save(original, accountID: user.id)) != nil {
        savedProgress = original
      }
      if let savedProgress, (try? validate(savedProgress)) != nil,
         (discoveryStorageFailure || !(error is CocoaError)), !(error is DecodingError),
         (error as? AccountSetupError) != .invalidSetup {
        restore(savedProgress)
        if discoveryStorageFailure {
          programUpdateMessage = "Your program status couldn’t be saved. Free space on this device and try Update again."
        }
        resolvedAccountID = user.id
        do {
          activeWorkoutSession = try workoutRepository?.activeSession(accountID: user.id)
        } catch {
          setupResolution = .failed("Your saved workout couldn’t be checked. Retry to continue.")
          return
        }
        if let activeWorkoutSession {
          selectedMainTab = .program
          programPath = [.workoutRecording(activeWorkoutSession.id)]
        }
        setupResolution = .idle
        await refreshPreviousPerformances(for: user, generation: generation, authentication: authentication)
      } else {
        setupResolution = .failed(error.localizedDescription)
      }
    }
  }

  private var isSetupIdle: Bool {
    if case .idle = setupResolution { return true }
    return false
  }

  func signOut(
    using authentication: AuthenticationModel,
    discardPending: Bool = false,
    retainingPendingSessions: Bool = false,
    confirmed: Bool = false
  ) async {
    guard !isSigningOut, let accountID = authentication.signedInUser?.id else { return }
    if activeWorkoutSession != nil {
      signOutErrorMessage = "Finish or discard your current workout first."
      signOutErrorPresented = true
      return
    }

    let progress: OnboardingProgress?
    do {
      if let progressStore {
        progress = try progressStore.load(accountID: accountID)
      } else {
        progress = savedProgress
      }
    } catch {
      signOutErrorMessage = "Your workouts are still saved on this device, but OneSet couldn’t check their upload status. Please try again."
      signOutErrorPresented = true
      return
    }
    let hasPendingSessions: Bool
    do {
      hasPendingSessions = try workoutRepository?.hasPendingSessionUploads(accountID: accountID) ?? false
    } catch {
      signOutErrorMessage = "Your workouts are still saved on this device, but OneSet couldn’t check their upload status. Please try again."
      signOutErrorPresented = true
      return
    }
    let hasPendingSetupForAccount = progress?.completed?.needsUpload == true
    let hasPendingCycles = progress?.cycles?.pendingCreations.isEmpty == false
      || progress?.cycles?.pendingActivations?.isEmpty == false
    if hasPendingCycles && !retainingPendingSessions {
      pendingSessionSignOutMessage = "Your program change and any completed workouts will stay on this device. Sign in again with this account to continue uploading them."
      pendingSessionSignOutAccountID = accountID
      pendingSessionSignOutDiscardsSetup = false
      pendingSessionSignOutPresented = true
      return
    }
    if hasPendingSessions && !retainingPendingSessions {
      presentPendingSessionSignOut(for: accountID, progress: progress)
      return
    }
    if hasPendingSetupForAccount && !discardPending && !retainingPendingSessions {
      discardSetupPresented = true
      return
    }

    if !confirmed && !discardPending && !retainingPendingSessions {
      signOutConfirmationAccountID = accountID
      signOutConfirmationPresented = true
      return
    }

    isSigningOut = true
    var resumeUploadsAfterFailure = false
    defer {
      isSigningOut = false
      if resumeUploadsAfterFailure {
        Task { @MainActor [weak self] in
          guard let self,
                authentication.signedInUser?.id == accountID,
                self.resolvedAccountID == accountID else { return }
          await self.uploadCompletedSetup(using: authentication)
          await self.uploadPendingCycles(using: authentication)
          await self.retryPendingSessionUploads(using: authentication)
        }
      }
    }
    lookupGeneration += 1
    let previousResolution = setupResolution
    let progressForFailure: OnboardingProgress? = progress
    do {
      let shouldRemoveProgress = progress != nil && !hasPendingCycles && (!hasPendingSetupForAccount || discardPending)
      if shouldRemoveProgress { try progressStore?.remove(accountID: accountID) }
      await authentication.signOut()
      if authentication.signedInUser == nil {
        resetAccount()
      } else if authentication.signedInUser?.id == accountID {
        if shouldRemoveProgress, let progress { try progressStore?.save(progress, accountID: accountID) }
        setupResolution = previousResolution
        if case .loading = previousResolution {
          await resolveAfterFailedSignOut(using: authentication)
        }
        signOutErrorMessage = signOutFailureMessage(
          authentication.errorMessage ?? "Please try again.", retainingPendingSessions: hasPendingSessions
        )
        signOutErrorPresented = true
        resumeUploadsAfterFailure = true
      }
    } catch {
      if let progressForFailure { try? progressStore?.save(progressForFailure, accountID: accountID) }
      if case .loading = previousResolution {
        await resolveAfterFailedSignOut(using: authentication)
      }
      signOutErrorMessage = signOutFailureMessage(
        error.localizedDescription, retainingPendingSessions: hasPendingSessions
      )
      signOutErrorPresented = true
      resumeUploadsAfterFailure = true
    }
  }

  func confirmSignOut(using authentication: AuthenticationModel) async {
    let accountID = signOutConfirmationAccountID
    signOutConfirmationPresented = false
    signOutConfirmationAccountID = nil
    guard let accountID, authentication.signedInUser?.id == accountID else { return }
    await signOut(using: authentication, confirmed: true)
  }

  func confirmPendingSessionSignOut(using authentication: AuthenticationModel) async {
    guard let accountID = pendingSessionSignOutAccountID,
          authentication.signedInUser?.id == accountID else {
      pendingSessionSignOutPresented = false
      pendingSessionSignOutMessage = ""
      pendingSessionSignOutDiscardsSetup = false
      pendingSessionSignOutAccountID = nil
      return
    }
    let discardSetup = pendingSessionSignOutDiscardsSetup
    pendingSessionSignOutPresented = false
    pendingSessionSignOutMessage = ""
    pendingSessionSignOutAccountID = nil
    await signOut(using: authentication, discardPending: discardSetup, retainingPendingSessions: true)
  }

  private func presentPendingSessionSignOut(for accountID: String, progress: OnboardingProgress?) {
    let pendingSetup = progress?.completed
    let requiredCycleID = pendingSetup?.setup.cycleID
    var setupIsRequired = false
    if pendingSetup?.needsUpload == true, let requiredCycleID {
      do {
        setupIsRequired = try workoutRepository?.hasPendingSessionUploads(
          accountID: accountID, cycleID: requiredCycleID
        ) ?? true
      } catch {
        setupIsRequired = true
      }
    }
    pendingSessionSignOutDiscardsSetup = pendingSetup?.needsUpload == true && !setupIsRequired
    pendingSessionSignOutAccountID = accountID
    if setupIsRequired {
      pendingSessionSignOutMessage = "Your completed workouts and the account setup they depend on will stay on this device. Sign in again with this account to continue uploading them."
    } else if pendingSessionSignOutDiscardsSetup {
      pendingSessionSignOutMessage = "Your completed workouts will stay on this device. Sign in again with this account to continue uploading them. The unsaved setup is not needed for these workouts and will be discarded."
    } else {
      pendingSessionSignOutMessage = "Your completed workouts will stay on this device. Sign in again with this account to continue uploading them."
    }
    pendingSessionSignOutPresented = true
  }

  private func signOutFailureMessage(_ message: String, retainingPendingSessions: Bool) -> String {
    guard retainingPendingSessions else { return message }
    return "Your workouts are still saved on this device. Sign out didn’t finish. Please try again."
  }

  private func resolveAfterFailedSignOut(using authentication: AuthenticationModel) async {
    isSigningOut = false
    await resolveAccountSetup(using: authentication)
    isSigningOut = true
  }

  func resetAccount() {
    resetAccount(preservingNavigation: false)
  }

  private func resetAccount(preservingNavigation: Bool) {
    lookupGeneration += 1
    cycleKnowledgeGeneration += 1
    resolvedAccountID = nil
    previousPerformanceUnavailable = false
    setupResolution = .idle
    restoredCycleID = nil
    activeWorkoutSession = nil
    savedProgress = nil
    uploadingGeneration = nil
    completedSessionUploadCoordinator?.cancelPendingWork()
    uploadMessage = nil
    cycleMessage = nil
    programSelectionMessage = nil
    programUpdateMessage = nil
    signOutConfirmationPresented = false
    signOutConfirmationAccountID = nil
    discardSetupPresented = false
    pendingSessionSignOutPresented = false
    pendingSessionSignOutMessage = ""
    pendingSessionSignOutDiscardsSetup = false
    pendingSessionSignOutAccountID = nil
    progressErrorPresented = false
    sessionUploadErrorPresented = false
    sessionUploadErrorMessage = ""
    signOutErrorPresented = false
    weightUnit = .kilograms
    trainingDays = 3
    selectedProgramID = nil
    if !preservingNavigation {
      path = []
      programPath = []
      settingsPath = []
      selectedMainTab = .program
    }
  }

  var programs: [TrainingProgram] {
    TrainingProgram.matchingPreferenceFirst(catalog.offeredPrograms, days: trainingDays)
  }

  func refreshCatalog() async {
    await catalog.refresh()
    releaseReofferedCycleOperations()
  }

  private func releaseReofferedCycleOperations() {
    guard let accountID = resolvedAccountID, let publication = catalog.publicationID,
          let progressStore, var progress = savedProgress, var state = progress.cycles,
          let rejected = state.unavailableAtPublication else { return }
    let released = state.knownCycles.filter { cycle in
      guard let previous = rejected[cycle.cycleID.uuidString], previous != publication else { return false }
      return catalog.offeredPrograms.contains { $0.id == cycle.programID }
    }.map(\.cycleID)
    guard !released.isEmpty else { return }
    state.rejectedCycleIDs?.removeAll { released.contains($0) }
    state.rejectedActivationIDs?.removeAll { released.contains($0) }
    for id in released { state.unavailableAtPublication?.removeValue(forKey: id.uuidString) }
    progress.cycles = state
    if (try? progressStore.save(progress, accountID: accountID)) != nil { savedProgress = progress }
  }

  func program(id: TrainingProgram.ID) -> TrainingProgram? {
    catalog.program(id: id)
  }

  func continueWithGoogle(using authentication: AuthenticationModel) async {
    if authentication.signedInUser == nil {
      await authentication.signInWithGoogle()
    } else if let selectedProgramID, hasCompletedSetup {
      path = [.programOverview(selectedProgramID)]
    } else {
      // Returning from preferences keeps choices still being edited in this workflow.
      path.append(.preferences)
    }
  }

  func showEmailAuthentication() {
    guard resolvedAccountID != nil else {
      path.append(.emailAuthentication)
      return
    }
    if let selectedProgramID, hasCompletedSetup {
      path = [.programOverview(selectedProgramID)]
    } else if let savedProgress {
      restore(savedProgress)
    } else {
      path = [.preferences]
    }
  }

  func showProgramSwitcher() {
    guard !requiresProgramUpdate else { return }
    guard !workoutStorageOpenFailed else { workoutErrorPresented = true; return }
    guard activeWorkoutSession == nil else {
      switchBlockedPresented = true
      return
    }
    programPath.append(.programs)
  }

  func clearCycleMessage() { cycleMessage = nil }

  func refreshCycleKnowledge(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser, user.id == resolvedAccountID,
          let cycleService, var progress = savedProgress, let setup = progress.completed?.setup,
          let progressStore else { return }
    let generation = lookupGeneration
    let cycleGeneration = cycleKnowledgeGeneration
    cycleDiscoveryGeneration += 1
    let discoveryGeneration = cycleDiscoveryGeneration
    var discoveryReservation: OnboardingProgress?
    var discoveryReturned = false
    do {
      if progress.pendingRemoteSelection == nil, progress.completed?.needsUpload != true,
         progress.cycles?.pendingCreations.isEmpty != false,
         (progress.cycles?.pendingActivations ?? []).isEmpty {
        discoveryReservation = progress
        let state = progress.cycles
        progress.pendingRemoteSelection = AccountSetup(preferredUnit: progress.weightUnit,
          trainingDays: progress.trainingDays, programID: state?.selectedProgramID ?? setup.programID,
          cycleID: state?.selectedCycleID ?? setup.cycleID)
        progress.remoteSelectionDiscoveryPending = true
        try progressStore.save(progress, accountID: user.id)
      }
      let remote = try await cycleService.lookup(for: user)
      discoveryReturned = true
      guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration,
            authentication.signedInUser?.id == user.id, var latest = savedProgress else { return }
      var state = latest.cycles ?? ProgramCycleState(selectedProgramID: setup.programID,
        selectedCycleID: setup.cycleID, knownCycles: [], discoveryComplete: false, pendingCreations: [])
      if latest.completed?.needsUpload != true, state.pendingCreations.isEmpty,
         (state.pendingActivations ?? []).isEmpty,
         let selectedID = remote.selectedCycleID,
         let selected = remote.cycles.first(where: { $0.cycleID == selectedID }) {
        if selected.cycleID != state.selectedCycleID || selected.programID != state.selectedProgramID
            || (latest.pendingRemoteSelection != nil && discoveryReservation == nil) {
          latest.pendingRemoteSelection = AccountSetup(preferredUnit: latest.weightUnit,
            trainingDays: latest.trainingDays, programID: selected.programID, cycleID: selected.cycleID)
        } else if discoveryReservation != nil {
          latest.pendingRemoteSelection = nil
        }
      } else if discoveryReservation != nil {
        latest.pendingRemoteSelection = nil
      }
      latest.remoteSelectionDiscoveryPending = nil
      state.knownCycles = remote.cycles
      for cycle in state.pendingCreations where !state.knownCycles.contains(where: { $0.cycleID == cycle.cycleID }) {
        state.knownCycles.append(cycle)
      }
      state.discoveryComplete = true
      latest.cycles = state
      savedProgress = latest
      try progressStore.save(latest, accountID: user.id)
      discoveryReservation = nil
      cycleMessage = nil
      // Each response is scoped to the verified owner and fixed cycle identity. Do not
      // let a late response modify storage after a selection or account transition.
      if let progressService, let workoutRepository {
        for cycle in remote.cycles {
          do {
            let summary = try await progressService.lookup(cycleID: cycle.cycleID, for: user)
            guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
                  discoveryGeneration == cycleDiscoveryGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            guard let summary, summary.cycleID == cycle.cycleID,
                  summary.programID == cycle.programID else { continue }
            try workoutRepository.restoreProgress(summary, accountID: user.id)
          } catch {
            guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
                  discoveryGeneration == cycleDiscoveryGeneration,
                  authentication.signedInUser?.id == user.id else { return }
            // A failed read is not an empty cycle. Existing cached progress stays usable.
          }
        }
      }
    } catch {
      guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, authentication.signedInUser?.id == user.id else { return }
      if !discoveryReturned, let original = discoveryReservation,
         (try? progressStore.save(original, accountID: user.id)) != nil {
        savedProgress = original
      }
      if discoveryReturned, savedProgress?.pendingRemoteSelection != nil {
        programUpdateMessage = "Your program status couldn’t be saved. Free space on this device and try Update again."
      }
      if progress.cycles?.discoveryComplete != true {
        cycleMessage = "Your program history couldn’t be checked. Connect and try again."
      }
    }
  }

  func updateRemoteProgram(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser, user.id == resolvedAccountID,
          let pending = savedProgress?.pendingRemoteSelection, !isSigningOut else { return }
    guard activeWorkoutSession == nil else {
      programUpdateMessage = "Finish or discard your current workout before updating your program."
      return
    }
    guard let cycleService, let progressService, let progressStore, let workoutRepository else {
      programUpdateMessage = "Connect and try Update again to restore your program."
      return
    }
    let generation = lookupGeneration
    let cycleGeneration = cycleKnowledgeGeneration
    cycleDiscoveryGeneration += 1
    let discoveryGeneration = cycleDiscoveryGeneration
    do {
      let remote = try await cycleService.lookup(for: user)
      guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, !isSigningOut,
            authentication.signedInUser?.id == user.id, activeWorkoutSession == nil else { return }
      guard let selectedID = remote.selectedCycleID,
            let selected = remote.cycles.first(where: { $0.cycleID == selectedID }),
            catalog.program(id: selected.programID) != nil,
            let summary = try await progressService.lookup(cycleID: selectedID, for: user),
            summary.cycleID == selectedID, summary.programID == selected.programID else {
        throw AccountSetupError.unavailable
      }
      guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, !isSigningOut,
            authentication.signedInUser?.id == user.id, activeWorkoutSession == nil,
            var latest = savedProgress, latest.pendingRemoteSelection?.cycleID == pending.cycleID,
            latest.pendingRemoteSelection?.programID == pending.programID else { return }
      try workoutRepository.restoreProgress(summary, accountID: user.id)
      var state = latest.cycles ?? ProgramCycleState(selectedProgramID: selected.programID,
        selectedCycleID: selectedID, knownCycles: [], discoveryComplete: true, pendingCreations: [])
      state.selectedProgramID = selected.programID
      state.selectedCycleID = selectedID
      state.knownCycles = remote.cycles
      state.discoveryComplete = true
      latest.cycles = state
      latest.pendingRemoteSelection = nil
      latest.remoteSelectionDiscoveryPending = nil
      try progressStore.save(latest, accountID: user.id)
      savedProgress = latest
      cycleKnowledgeGeneration += 1
      selectedProgramID = selected.programID
      restoredCycleID = selectedID
      programPath = []
      path = [.programOverview(selected.programID)]
      programUpdateMessage = nil
    } catch {
      guard generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, !isSigningOut,
            authentication.signedInUser?.id == user.id else { return }
      programUpdateMessage = "Your program couldn’t be updated safely. Connect and try Update again."
    }
  }

  func hasFollowedProgram(_ programID: String) -> Bool {
    savedProgress?.cycles?.knownCycles.contains(where: { $0.programID == programID }) == true
      || savedProgress?.completed?.setup.programID == programID
  }

  func switchToProgram(_ programID: String, using authentication: AuthenticationModel) {
    guard !requiresProgramUpdate else { return }
    guard !workoutStorageOpenFailed else { workoutErrorPresented = true; return }
    guard activeWorkoutSession == nil else { switchBlockedPresented = true; return }
    guard let user = authentication.signedInUser, user.id == resolvedAccountID,
          let progressStore, var progress = savedProgress else { return }
    guard var state = progress.cycles, state.discoveryComplete else {
      cycleMessage = "Your program history couldn’t be checked. Connect and try again."
      return
    }
    guard catalog.offeredPrograms.contains(where: { $0.id == programID }),
          programID != state.selectedProgramID else { return }
    let existing = state.knownCycles.first(where: { $0.programID == programID })
    let setupCycleID = progress.completed?.setup.programID == programID ? progress.completed?.setup.cycleID : nil
    let targetCycleID: UUID
    if let cycleID = existing?.cycleID ?? setupCycleID {
      let trusted = state.locallyKnownProgressCycleIDs?.contains(cycleID) == true
        || (try? workoutRepository?.hasRestoredCycleSummary(accountID: user.id, cycleID: cycleID)) == true
      guard trusted else {
        cycleMessage = "Your saved training progress isn’t available yet. Connect and try again."
        return
      }
      targetCycleID = cycleID
    } else {
      let sourcePreferences: [CyclePreference]
      if let known = state.knownCycles.first(where: { $0.cycleID == state.selectedCycleID })?.preferences {
        sourcePreferences = known
      } else if progress.completed?.needsUpload == true,
                progress.completed?.setup.cycleID == state.selectedCycleID {
        sourcePreferences = []
      } else {
        cycleMessage = "Your program preferences couldn’t be checked. Connect and try again."
        return
      }
      guard let target = catalog.program(id: programID) else { return }
      let slots = Set(target.workouts.flatMap { $0.exercises.map(\.id) })
      let cycle = AccountCycle(cycleID: UUID(), programID: programID,
        startedAt: ISO8601DateFormatter().string(from: .now),
        preferences: sourcePreferences.filter { slots.contains($0.workoutExerciseID) })
      targetCycleID = cycle.cycleID
      state.knownCycles.append(cycle)
      state.pendingCreations.append(cycle)
    }
    var trustedCycles = state.locallyKnownProgressCycleIDs ?? []
    for cycleID in [state.selectedCycleID, targetCycleID] where !trustedCycles.contains(cycleID) {
      trustedCycles.append(cycleID)
    }
    state.locallyKnownProgressCycleIDs = trustedCycles
    state.unavailableAtPublication?.removeValue(forKey: targetCycleID.uuidString)
    state.rejectedCycleIDs?.removeAll { $0 == targetCycleID }
    state.rejectedActivationIDs?.removeAll { $0 == targetCycleID }
    state.selectedProgramID = programID
    state.selectedCycleID = targetCycleID
    state.pendingActivations = (state.pendingActivations ?? []) + [targetCycleID]
    progress.cycles = state
    do {
      try progressStore.save(progress, accountID: user.id)
      savedProgress = progress
      cycleKnowledgeGeneration += 1
      selectedProgramID = programID
      restoredCycleID = targetCycleID
      programPath = []
      cycleMessage = nil
      Task { await uploadPendingCycles(using: authentication) }
    } catch {
      cycleMessage = "Your program couldn’t be saved on this device. Please try again."
    }
  }

  func uploadPendingCycles(using authentication: AuthenticationModel, at date: Date = .now) async {
    guard !isSigningOut, !hasPendingSetup,
          let user = authentication.signedInUser, user.id == resolvedAccountID,
          let cycleService, let progressStore,
          savedProgress?.cycles?.authenticationDeferred != true else { return }
    let generation = lookupGeneration
    await cycleSyncCoordinator.upload(
      user: user, generation: generation, at: date, publicationID: catalog.publicationID, service: cycleService, store: progressStore,
      current: { [weak self] in
        guard let self, self.lookupGeneration == generation, !self.isSigningOut,
              authentication.signedInUser?.id == user.id else { return nil }
        return self.savedProgress
      },
      didSave: { [weak self] progress in
        self?.savedProgress = progress
        self?.cycleKnowledgeGeneration += 1
      },
      authenticationRequired: { [weak self] in
        self?.cycleMessage = "Sign in again to sync your program change. Your workouts remain on this device."
      },
      creationAcknowledged: { [weak self] in
        await self?.retryPendingSessionUploads(using: authentication)
      }
    )
    guard generation == lookupGeneration, authentication.signedInUser?.id == user.id,
          !isSigningOut else { return }
    await retryPendingSessionUploads(using: authentication)
  }

  func returnToActiveWorkout() {
    guard let session = activeWorkoutSession else { return }
    programPath = [.workoutRecording(session.id)]
  }

  func showPrograms() {
    guard saveProgress(nextStep: .programs, programID: selectedProgramID) else { return }
    path.append(.programs)
  }

  func selectProgram(_ id: TrainingProgram.ID) {
    guard catalog.offeredPrograms.contains(where: { $0.id == id }) else { return }
    guard path.last == .programDetail(id),
          saveProgress(nextStep: .trial, programID: id) else { return }
    selectedProgramID = id
    programSelectionMessage = nil
    if path.last == .programDetail(id) {
      path.append(.trialPreview(id))
    }
  }

  private func saveProgress(nextStep: OnboardingProgress.Step, programID: TrainingProgram.ID?) -> Bool {
    guard !isSigningOut else { return false }
    // Development preview routes have no authenticated account and do not persist.
    guard let accountID = resolvedAccountID, let progressStore else { return true }
    let progress = OnboardingProgress(
      weightUnit: weightUnit, trainingDays: trainingDays,
      selectedProgramID: programID, nextStep: nextStep
    )
    do {
      try validate(progress)
      try progressStore.save(progress, accountID: accountID)
      savedProgress = progress
      return true
    } catch {
      progressErrorMessage = "Your choices couldn’t be saved on this device. Please try Continue again. "
        + error.localizedDescription
      progressErrorPresented = true
      return false
    }
  }

  private func validate(_ progress: OnboardingProgress) throws {
    if let completed = progress.completed {
      guard progress.nextStep == .overview,
            completed.setup.preferredUnit == progress.weightUnit,
            completed.setup.trainingDays == progress.trainingDays,
            completed.setup.programID == progress.selectedProgramID else {
        throw AccountSetupError.invalidSetup
      }
    }
    guard (2...5).contains(progress.trainingDays),
          progress.selectedProgramID.map({ catalog.program(id: $0) != nil }) ?? true,
          progress.nextStep != .trial || progress.selectedProgramID != nil,
          progress.nextStep != .overview || progress.completed != nil else {
      throw AccountSetupError.invalidSetup
    }
  }

  private func restore(_ progress: OnboardingProgress) {
    if let completed = progress.completed {
      apply(completed.setup)
      if let cycles = progress.cycles {
        selectedProgramID = cycles.selectedProgramID
        restoredCycleID = cycles.selectedCycleID
        path = [.programOverview(cycles.selectedProgramID)]
      }
      if progress.cycles?.authenticationDeferred == true {
        cycleMessage = "Sign in again to sync your program change. Your workouts remain on this device."
      } else if progress.cycles?.rejectedCycleIDs?.isEmpty == false {
        cycleMessage = "Your program change couldn’t be saved to your account. Your workouts remain on this device."
      }
      uploadMessage = completed.needsUpload ? "Setup saved on this device. Waiting to upload." : nil
      return
    }
    weightUnit = progress.weightUnit
    trainingDays = progress.trainingDays
    selectedProgramID = progress.selectedProgramID
    restoredCycleID = nil
    switch progress.nextStep {
    case .overview:
      break
    case .preferences:
      path = [.preferences]
    case .programs:
      path = [.preferences, .programs]
    case .trial:
      if let programID = progress.selectedProgramID {
        path = [.preferences, .programs, .programDetail(programID), .trialPreview(programID)]
      }
    }
  }

  func continueWithoutTrial() {
    guard !isSigningOut, let selectedProgramID,
          catalog.offeredPrograms.contains(where: { $0.id == selectedProgramID }),
          path.last == .trialPreview(selectedProgramID)
    else { return }

    if let accountID = resolvedAccountID {
      let setup = AccountSetup(preferredUnit: weightUnit, trainingDays: trainingDays,
                               programID: selectedProgramID, cycleID: UUID())
      do {
        try storeCompleted(setup, needsUpload: true, accountID: accountID)
        apply(setup)
        uploadMessage = "Setup saved on this device. Waiting to upload."
      } catch {
        progressErrorMessage = "Your setup couldn’t be saved on this device. Please try again. " + error.localizedDescription
        progressErrorPresented = true
      }
    } else {
      path.append(.programOverview(selectedProgramID))
    }
  }

  private func apply(_ setup: AccountSetup, replacePath: Bool = true) {
    weightUnit = setup.preferredUnit
    trainingDays = setup.trainingDays
    selectedProgramID = setup.programID
    restoredCycleID = setup.cycleID
    if replacePath { path = [.programOverview(setup.programID)] }
  }

  private func storeCompleted(_ setup: AccountSetup, needsUpload: Bool, accountID: String) throws {
    guard (2...5).contains(setup.trainingDays), catalog.program(id: setup.programID) != nil else {
      throw AccountSetupError.invalidSetup
    }
    var progress = OnboardingProgress(weightUnit: setup.preferredUnit, trainingDays: setup.trainingDays,
                                       selectedProgramID: setup.programID, nextStep: .overview)
    progress.completed = CompletedOnboarding(setup: setup, needsUpload: needsUpload)
    progress.cycles = savedProgress?.cycles
    if var state = progress.cycles, state.pendingCreations.isEmpty,
       (state.pendingActivations ?? []).isEmpty {
      state.selectedProgramID = setup.programID
      state.selectedCycleID = setup.cycleID
      progress.cycles = state
    }
    try progressStore?.save(progress, accountID: accountID)
    savedProgress = progress
  }

  func retryCompletedUploads(using authentication: AuthenticationModel) async {
    while !Task.isCancelled, authentication.signedInUser != nil {
      await uploadCompletedSetup(using: authentication)
      await uploadPendingCycles(using: authentication)
      do { try await Task.sleep(for: .seconds(15)) } catch { break }
    }
  }

  func uploadCompletedSetup(using authentication: AuthenticationModel) async {
    guard !isSigningOut, let user = authentication.signedInUser,
          resolvedAccountID == user.id, let completed = savedProgress?.completed,
          completed.needsUpload, let setupService,
          uploadingGeneration != lookupGeneration else { return }
    let generation = lookupGeneration
    uploadingGeneration = generation
    defer { if uploadingGeneration == generation { uploadingGeneration = nil } }
    uploadMessage = "Uploading setup…"
    do {
      let setup = try await setupService.save(completed.setup, for: user)
      guard generation == lookupGeneration, authentication.signedInUser?.id == user.id,
            !isSigningOut else { return }
      if setup.cycleID != completed.setup.cycleID {
        _ = try workoutRepository?.blockSessionUploadsForSetupCycle(
          accountID: user.id, cycleID: completed.setup.cycleID, establishedCycleID: setup.cycleID
        )
      }
      try storeCompleted(setup, needsUpload: false, accountID: user.id)
      // A different device may have established setup first. Respect its cycle.
      if savedProgress?.cycles?.pendingCreations.isEmpty != false
        && savedProgress?.cycles?.pendingActivations?.isEmpty != false {
        apply(setup, replacePath: setup.cycleID != completed.setup.cycleID)
      }
      uploadMessage = nil
      presentSessionUploadErrorIfNeeded(accountID: user.id)
      await uploadPendingCycles(using: authentication)
      await retryPendingSessionUploads(using: authentication)
    } catch {
      guard generation == lookupGeneration, authentication.signedInUser?.id == user.id else { return }
      if (error as? AccountSetupError) == .programUnavailable {
        if savedProgress?.cycles?.pendingCreations.isEmpty == false {
          cycleMessage = "Your original program is no longer available for account setup. Your program change and workouts remain on this device."
        } else {
          recoverPendingSetupAfterProgramRemoval(completed, accountID: user.id)
        }
        return
      }
      uploadMessage = "Setup saved on this device. Upload pending. You can retry now or stay here for automatic retry."
    }
  }

  private func recoverPendingSetupAfterProgramRemoval(_ completed: CompletedOnboarding, accountID: String) {
    let progress = OnboardingProgress(
      weightUnit: completed.setup.preferredUnit,
      trainingDays: completed.setup.trainingDays,
      selectedProgramID: nil,
      nextStep: .programs
    )
    do {
      try progressStore?.save(progress, accountID: accountID)
    } catch {
      progressErrorMessage = "Your available program choices couldn’t be saved on this device. "
        + error.localizedDescription
      progressErrorPresented = true
    }
    savedProgress = progress
    selectedProgramID = nil
    restoredCycleID = nil
    path = [.preferences, .programs]
    uploadMessage = nil
    programSelectionMessage = "That program is no longer available. Choose an available program to finish setup."
  }

  private func presentSessionUploadErrorIfNeeded(accountID: String) {
    guard let workoutRepository,
          (try? workoutRepository.hasUnresolvedSetupCycleConflict(accountID: accountID)) == true else { return }
    sessionUploadErrorMessage = "Your completed workout is still saved on this device. It belongs to a different cycle than the one already on your account, so it wasn’t uploaded or moved. Keep this device while the cycle conflict is resolved."
    sessionUploadErrorPresented = true
  }

  func previewWorkout(programID: TrainingProgram.ID, workoutID: WorkoutTemplate.ID) {
    guard selectedProgramID == programID,
          let program = catalog.program(id: programID),
          program.workouts.contains(where: { $0.id == workoutID })
    else { return }

    let route = OnboardingRoute.workoutPreview(programID: programID, workoutID: workoutID)
    if hasCompletedSetup {
      programPath.append(route)
    } else if path.last == .programOverview(programID) {
      path.append(route)
    }
  }

  func startWorkout(programID: String, workoutID: String, accountID: String) {
    guard !requiresProgramUpdate, accountID == resolvedAccountID, programID == selectedProgramID else {
      workoutErrorMessage = "Update your program before starting a workout."
      workoutErrorPresented = true
      return
    }
    guard let workoutRepository = ensureWorkoutRepository(), let cycleID = restoredCycleID,
          let program = catalog.program(id: programID),
          let index = program.workouts.firstIndex(where: { $0.id == workoutID }) else {
      workoutErrorMessage = "Your workout could not be started. Please try again."
      workoutErrorPresented = true
      return
    }
    do {
      let next = try workoutRepository.nextOccurrence(accountID: accountID, cycleID: cycleID,
        programID: programID, workoutIDs: program.workouts.map(\.id))
      guard next.workoutID == workoutID else {
        workoutErrorMessage = "Complete the earlier workout day before starting this one."
        workoutErrorPresented = true
        return
      }
      let session = WorkoutSession(accountID: accountID, cycleID: cycleID, program: program,
        workout: program.workouts[index], week: next.week, day: next.day, weightUnit: weightUnit)
      activeWorkoutSession = try workoutRepository.start(session)
      let route = OnboardingRoute.workoutRecording(activeWorkoutSession!.id)
      if hasCompletedSetup { programPath.append(route) } else { path.append(route) }
    } catch {
      workoutErrorMessage = error.localizedDescription
      workoutErrorPresented = true
    }
  }

  func retryWorkoutStorage() {
    guard let workoutRepositoryFactory else { return }
    do {
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
      workoutStorageOpenFailed = false
      workoutErrorPresented = false
      if let resolvedAccountID {
        activeWorkoutSession = try workoutRepository?.activeSession(accountID: resolvedAccountID)
      }
    } catch {
      workoutStorageOpenFailed = true
      workoutErrorMessage = "Workout storage couldn’t be opened. Your saved workouts are still on this device. Try opening storage again.\n\(error.localizedDescription)"
      workoutErrorPresented = true
    }
  }

  private func ensureWorkoutRepository() -> WorkoutRepository? {
    if let workoutRepository { return workoutRepository }
    retryWorkoutStorage()
    return workoutRepository
  }

  func discardActiveWorkout(accountID: String) {
    guard let activeWorkoutSession else { return }
    do {
      try workoutRepository?.discard(sessionID: activeWorkoutSession.id, accountID: accountID)
      self.activeWorkoutSession = nil
      if path.last == .workoutRecording(activeWorkoutSession.id) { path.removeLast() }
      if programPath.last == .workoutRecording(activeWorkoutSession.id) { programPath.removeLast() }
    } catch {
      workoutErrorMessage = error.localizedDescription
      workoutErrorPresented = true
    }
  }

  func saveWorkoutDraft(slotID: String, weightInput: String, repsInput: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.saveDraft(
        sessionID: session.id, accountID: session.accountID, slotID: slotID,
        weightInput: weightInput, repsInput: repsInput
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func completeWorkoutSet(slotID: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      let restSeconds = session.exercises.first(where: { $0.slotID == slotID })?.restSeconds
      activeWorkoutSession = try workoutRepository.completeSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID, restSeconds: restSeconds
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func updateWorkoutSet(slotID: String, weightInput: String, repsInput: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.updateSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID,
        weightInput: weightInput, repsInput: repsInput
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func unmarkWorkoutSet(slotID: String) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.unmarkSet(
        sessionID: session.id, accountID: session.accountID, slotID: slotID
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func completedWorkoutIDs(programID: String, week: Int) -> Set<String> {
    guard let workoutRepository, let cycleID = restoredCycleID,
          let accountID = resolvedAccountID else { return [] }
    return (try? workoutRepository.completedOccurrenceIDs(accountID: accountID, cycleID: cycleID, week: week)) ?? []
  }

  func currentWorkoutWeek(programID: String) -> Int {
    guard let workoutRepository, let cycleID = restoredCycleID,
          let accountID = resolvedAccountID, let program = catalog.program(id: programID) else { return 1 }
    return (try? workoutRepository.nextOccurrence(accountID: accountID, cycleID: cycleID,
      programID: programID, workoutIDs: program.workouts.map(\.id)).week) ?? 1
  }

  func finishActiveWorkout(note: String?, using authentication: AuthenticationModel? = nil) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      _ = try workoutRepository.finish(sessionID: session.id, accountID: session.accountID, note: note)
      activeWorkoutSession = nil
      if path.last == .workoutRecording(session.id) { path.removeLast() }
      if programPath.last == .workoutRecording(session.id) { programPath.removeLast() }
      if let last = path.last, case .workoutPreview = last { path.removeLast() }
      if let last = programPath.last, case .workoutPreview = last { programPath.removeLast() }
      if let authentication {
        let queue = try? workoutRepository.sessionUploadQueue(accountID: session.accountID)
        if queue?.contains(where: { $0.upload.sessionID == session.id
          && $0.permanentFailure == .setupCycleConflict }) == true {
          presentSessionUploadErrorIfNeeded(accountID: session.accountID)
        }
        if queue?.contains(where: { $0.permanentFailure == nil && !$0.isAuthenticationDeferred }) == true {
          Task { await retryPendingSessionUploads(using: authentication) }
        }
      }
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func resumeDeferredSessionUploads(
    using authentication: AuthenticationModel,
    at date: Date = .now,
    scheduleRetries: Bool = true
  ) async {
    guard !isSigningOut, let user = authentication.signedInUser,
          resolvedAccountID == user.id else { return }
    let generation = lookupGeneration
    if var progress = savedProgress, var state = progress.cycles,
       state.authenticationDeferred == true, let progressStore {
      state.authenticationDeferred = false
      progress.cycles = state
      if (try? progressStore.save(progress, accountID: user.id)) != nil {
        savedProgress = progress
        cycleMessage = nil
        await uploadPendingCycles(using: authentication)
      }
    }
    guard !isSigningOut, generation == lookupGeneration,
          authentication.signedInUser?.id == user.id, resolvedAccountID == user.id else { return }
    try? workoutRepository?.resumeAuthenticationDeferredUploads(accountID: user.id)
    await retryPendingSessionUploads(using: authentication, at: date, scheduleRetries: scheduleRetries)
  }

  func retryPendingSessionUploads(
    using authentication: AuthenticationModel,
    at date: Date = .now,
    scheduleRetries: Bool = true
  ) async {
    guard !isSigningOut, !hasPendingSetup,
          let user = authentication.signedInUser,
          resolvedAccountID == user.id,
          let completedSessionUploadCoordinator else { return }
    let generation = lookupGeneration
    let isCurrent: @MainActor () -> Bool = { [weak self] in
      guard let self else { return false }
      return !self.isSigningOut && generation == self.lookupGeneration
        && authentication.signedInUser?.id == user.id
        && self.resolvedAccountID == user.id
    }
    presentSessionUploadErrorIfNeeded(accountID: user.id)
    await completedSessionUploadCoordinator.drain(
      for: user,
      whileCurrent: isCurrent,
      at: date,
      scheduleRetries: scheduleRetries,
      blockedCycleIDs: Set(savedProgress?.cycles?.pendingCreations.map(\.cycleID) ?? [])
    )
    guard isCurrent() else { return }
    presentSessionUploadErrorIfNeeded(accountID: user.id)
  }

  func adjustWorkoutRest(by seconds: Int) -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.adjustRest(
        sessionID: session.id, accountID: session.accountID, by: seconds
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func skipWorkoutRest() -> Bool {
    guard let session = activeWorkoutSession, let workoutRepository else { return false }
    do {
      activeWorkoutSession = try workoutRepository.skipRest(
        sessionID: session.id, accountID: session.accountID
      )
      return true
    } catch {
      showWorkoutSaveError(error)
      return false
    }
  }

  func previousPerformances(for session: WorkoutSession) -> [String: WorkoutRepository.PreviousPerformance] {
    guard let workoutRepository else { return [:] }
    return (try? workoutRepository.previousPerformances(accountID: session.accountID,
      exercises: session.exercises.map { .init(slotID: $0.slotID, exerciseKey: $0.exerciseKey) },
      programID: session.programID, workoutID: session.workoutID)) ?? [:]
  }

  func completedHistorySessions(accountID: String) throws -> [WorkoutSession] {
    guard resolvedAccountID == accountID else { throw HistoryDataError.accountUnavailable }
    if workoutRepository == nil {
      guard let workoutRepositoryFactory else { throw HistoryDataError.storageUnavailable }
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
    }
    guard let workoutRepository else { throw HistoryDataError.storageUnavailable }
    workoutStorageOpenFailed = false
    return try workoutRepository.completedSessions(accountID: accountID)
  }

  var canRefreshAccountHistory: Bool { sessionHistoryService != nil }

  func completedHistoryCoverage(accountID: String) throws -> SessionHistoryCoverage {
    try historyRepository(accountID: accountID).historyCoverage(accountID: accountID)
  }

  func saveCompletedHistoryPage(_ page: SessionHistoryPage, accountID: String) throws {
    try historyRepository(accountID: accountID).saveHistoryPage(page, accountID: accountID)
  }

  func fetchHistoryPage(
    accountID: String, cursor: String?, using authentication: AuthenticationModel
  ) async throws -> SessionHistoryPage {
    guard let user = authentication.signedInUser, user.id == accountID,
          resolvedAccountID == accountID, let sessionHistoryService else {
      throw HistoryDataError.accountUnavailable
    }
    let page = try await sessionHistoryService.fetchPage(for: user, cursor: cursor)
    guard authentication.signedInUser?.id == accountID, resolvedAccountID == accountID else {
      throw HistoryDataError.accountUnavailable
    }
    return page
  }

  private func historyRepository(accountID: String) throws -> WorkoutRepository {
    guard resolvedAccountID == accountID else { throw HistoryDataError.accountUnavailable }
    if workoutRepository == nil {
      guard let workoutRepositoryFactory else { throw HistoryDataError.storageUnavailable }
      workoutRepository = try workoutRepositoryFactory()
      configureCompletedSessionUploads()
    }
    guard let workoutRepository else { throw HistoryDataError.storageUnavailable }
    workoutStorageOpenFailed = false
    return workoutRepository
  }

  func programName(id: String) -> String? {
    catalog.program(id: id)?.name
  }

  private func refreshPreviousPerformances(
    for user: AuthenticatedUser, generation: Int, authentication: AuthenticationModel
  ) async {
    guard let previousPerformanceService, let workoutRepository else { return }
    do {
      let results = try await previousPerformanceService.lookup(for: user)
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            resolvedAccountID == user.id else { return }
      try workoutRepository.saveRestoredPreviousPerformances(results, accountID: user.id)
      previousPerformanceUnavailable = false
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            resolvedAccountID == user.id else { return }
      previousPerformanceUnavailable = true
    }
  }

  func retryPreviousPerformances(using authentication: AuthenticationModel) async {
    guard let user = authentication.signedInUser, resolvedAccountID == user.id else { return }
    await refreshPreviousPerformances(for: user, generation: lookupGeneration, authentication: authentication)
  }

  private func showWorkoutSaveError(_ error: Error) {
    workoutErrorMessage = error.localizedDescription
    workoutErrorPresented = true
  }
}
