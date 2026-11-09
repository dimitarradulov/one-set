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
  var selectedProgramID: TrainingProgram.ID?

  enum SetupResolution {
    case idle
    case loading
    case failed(String)
  }

  private(set) var setupResolution: SetupResolution = .idle
  private(set) var showsSetupSpinner = false
  private let waitForSetupDelay: @MainActor (TimeInterval) async throws -> Void
  var restoredCycleID: UUID?
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
  var programUpdateMessage: String?
  private var uploadingGeneration: Int?
  var hasCompletedSetup: Bool { savedProgress?.completed != nil || restoredCycleID != nil }
  var hasPendingSetup: Bool { savedProgress?.completed?.needsUpload == true }
  var signOutErrorPresented = false
  private(set) var signOutErrorMessage = ""
  var progressErrorPresented = false
  private(set) var progressErrorMessage = ""
  let progressStore: (any OnboardingProgressStore)?
  var savedProgress: OnboardingProgress?
  private(set) var isSigningOut = false
  private var didResolveInitialAccount = false
  private let setupService: (any AccountSetupService)?
  let cycleService: (any AccountCycleService)?
  let cycleSyncCoordinator: ProgramCycleSyncCoordinator
  var cycleKnowledgeGeneration = 0
  var cycleDiscoveryGeneration = 0
  var cycleMessage: String?
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
  let previousPerformanceService: (any PreviousPerformanceService)?
  let progressService: (any AccountProgressService)?
  var lookupGeneration = 0
  private var backgroundRestoration: Task<Void, Never>?
  private(set) var resolvedAccountID: String?
  let catalog: ProgramCatalog
  var workoutRepository: WorkoutRepository?
  var completedSessionUploadCoordinator: CompletedSessionUploadCoordinator?
  private let completedSessionUploadService: (any CompletedSessionUploadService)?
  let sessionHistoryService: (any SessionHistoryService)?
  private let waitForSessionUploadRetry: @MainActor (TimeInterval) async throws -> Void
  let workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)?
  private let restAlerts: WorkoutRestAlerts?
  var activeWorkoutSession: WorkoutSession? {
    didSet {
      if oldValue?.id != activeWorkoutSession?.id {
        workoutDraftSaves.cancel()
        workoutDraftSaves = WorkoutDraftSaves()
      }
      let previousDeadline = oldValue?.restSlotID == nil ? nil : oldValue?.restDeadline
      let deadline = activeWorkoutSession?.restSlotID == nil ? nil : activeWorkoutSession?.restDeadline
      if previousDeadline != deadline || oldValue?.id != activeWorkoutSession?.id {
        restAlerts?.update(deadline: deadline, canRequestPermission: oldValue?.id == activeWorkoutSession?.id)
      }
    }
  }
  var workoutDraftSaves = WorkoutDraftSaves()
  var isApplyingWorkoutEdit = false
  var workoutErrorPresented = false
  var workoutErrorMessage = ""
  var sessionUploadErrorPresented = false
  private(set) var sessionUploadErrorMessage = ""
  var workoutStorageOpenFailed = false
  var previousPerformanceUnavailable = false

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
    waitForSetupDelay: @escaping @MainActor (TimeInterval) async throws -> Void = { delay in
      try await Task.sleep(for: .seconds(delay))
    },
    progressStore: (any OnboardingProgressStore)? = nil,
    workoutRepository: WorkoutRepository? = nil,
    workoutRepositoryFactory: (@MainActor () throws -> WorkoutRepository)? = nil,
    restAlerts: WorkoutRestAlerts? = nil,
    initialPath: [OnboardingRoute] = [],
    initialSelectedProgramID: TrainingProgram.ID? = nil,
    initialProgramPath: [OnboardingRoute] = [],
    initialSettingsPath: [SettingsDestination] = [],
    initialMainTab: MainTab = .program
  ) {
    self.catalog = catalog
    self.waitForSetupDelay = waitForSetupDelay
    self.setupService = setupService
    self.cycleService = cycleService
    self.cycleSyncCoordinator = cycleSyncCoordinator
    self.previousPerformanceService = previousPerformanceService
    self.progressService = progressService
    self.progressStore = progressStore
    self.workoutRepositoryFactory = workoutRepositoryFactory
    self.restAlerts = restAlerts
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

  func configureCompletedSessionUploads() {
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
}

// MARK: - Account resolution

extension OnboardingModel {
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
    if await openSavedAccount(user: user, generation: generation, authentication: authentication) { return }
    setupResolution = .loading
    var discoveryStorageFailure = false
    showsSetupSpinner = false
    let spinnerTask = Task { @MainActor in
      do { try await waitForSetupDelay(1) } catch { return }
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            case .loading = setupResolution else { return }
      showsSetupSpinner = true
    }
    let deadlineTask = Task { @MainActor in
      do { try await waitForSetupDelay(15) } catch { return }
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id,
            case .loading = setupResolution else { return }
      lookupGeneration += 1
      setupResolution = .failed("Your account is taking longer than expected to load. Retry to continue.")
    }
    defer {
      spinnerTask.cancel()
      deadlineTask.cancel()
    }
    do {
      await catalog.refresh()
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      savedProgress = try progressStore?.load(accountID: user.id)
      if let savedProgress { try validate(savedProgress) }
      let setup = try await setupService.lookup(for: user)
      guard !Task.isCancelled, generation == lookupGeneration,
            authentication.signedInUser?.id == user.id else { return }
      if let setup {
        guard try await applyRestoredSetup(setup, user: user, generation: generation,
          authentication: authentication, discoveryStorageFailure: &discoveryStorageFailure) else { return }
      } else if let savedProgress {
        guard savedProgress.completed == nil || hasSafeLocalProgress(savedProgress, accountID: user.id) else {
          setupResolution = .failed("Your training progress couldn’t be restored. Retry to continue.")
          return
        }
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
      await recoverAccountSetup(error, user: user, generation: generation,
        authentication: authentication, discoveryStorageFailure: discoveryStorageFailure)
    }
  }

  private func recoverAccountSetup(
    _ error: any Error, user: AuthenticatedUser, generation: Int,
    authentication: AuthenticationModel, discoveryStorageFailure: Bool
  ) async {
    guard !Task.isCancelled, generation == lookupGeneration,
          authentication.signedInUser?.id == user.id else { return }
    let canRecoverFromError = discoveryStorageFailure || !(error is CocoaError)
    if let savedProgress, (try? validate(savedProgress)) != nil,
       savedProgress.completed == nil || hasSafeLocalProgress(savedProgress, accountID: user.id),
       canRecoverFromError, !(error is DecodingError),
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

  private func applyRestoredSetup(
    _ setup: AccountSetup, user: AuthenticatedUser, generation: Int,
    authentication: AuthenticationModel, discoveryStorageFailure: inout Bool
  ) async throws -> Bool {
    if var local = savedProgress, let completed = local.completed,
       !completed.needsUpload, local.cycles?.pendingCreations.isEmpty != false,
       (local.cycles?.pendingActivations ?? []).isEmpty {
      let currentProgram = local.cycles?.selectedProgramID ?? completed.setup.programID
      let currentCycle = local.cycles?.selectedCycleID ?? completed.setup.cycleID
      let changed = setup.programID != currentProgram || setup.cycleID != currentCycle
      if changed || local.pendingRemoteSelection != nil && local.remoteSelectionDiscoveryPending != true {
        local.pendingRemoteSelection = setup
        local.remoteSelectionDiscoveryPending = nil
      }
      savedProgress = local
      discoveryStorageFailure = true
      try progressStore?.save(local, accountID: user.id)
      discoveryStorageFailure = false
    }
    if let local = savedProgress, local.pendingRemoteSelection != nil {
      if !hasSafeLocalProgress(local, accountID: user.id), let completed = local.completed,
         let progressService, let workoutRepository {
        let cycleID = local.cycles?.selectedCycleID ?? completed.setup.cycleID
        let programID = local.cycles?.selectedProgramID ?? completed.setup.programID
        if let summary = try await progressService.lookup(cycleID: cycleID, for: user) {
          guard !Task.isCancelled, generation == lookupGeneration,
                authentication.signedInUser?.id == user.id else { return false }
          if summary.cycleID == cycleID, summary.programID == programID {
            try workoutRepository.restoreProgress(summary, accountID: user.id)
          }
        }
      }
      guard hasSafeLocalProgress(local, accountID: user.id) else {
        setupResolution = .failed("Your training progress couldn’t be restored. Retry to continue.")
        return false
      }
      restore(local)
      return true
    }
    let pendingCycles = savedProgress?.cycles
    let hasPendingCycles = pendingCycles.map {
      !$0.pendingCreations.isEmpty || !($0.pendingActivations ?? []).isEmpty
    } ?? false
    if let progressService, !hasPendingCycles || pendingCycles?.selectedCycleID == setup.cycleID {
      do {
        let summary = try await progressService.lookup(for: user)
        guard !Task.isCancelled, generation == lookupGeneration,
              authentication.signedInUser?.id == user.id else { return false }
        guard let summary,
              summary.cycleID == setup.cycleID, summary.programID == setup.programID else {
          throw AccountSetupError.unavailable
        }
        try workoutRepository?.restoreProgress(summary, accountID: user.id)
      } catch {
        guard !Task.isCancelled, generation == lookupGeneration,
              authentication.signedInUser?.id == user.id else { return false }
        guard try workoutRepository?.hasRestorableProgress(accountID: user.id, cycleID: setup.cycleID) == true else {
          setupResolution = .failed("Your training progress couldn’t be restored. Retry to continue.")
          return false
        }
      }
    }
    if let pending = savedProgress?.completed, pending.needsUpload,
       pending.setup.cycleID != setup.cycleID {
      _ = try workoutRepository?.blockSessionUploadsForSetupCycle(
        accountID: user.id, cycleID: pending.setup.cycleID, establishedCycleID: setup.cycleID
      )
    }
    try storeCompleted(setup, needsUpload: false, accountID: user.id)
    apply(setup)
    if let cycles = pendingCycles, hasPendingCycles {
      selectedProgramID = cycles.selectedProgramID
      restoredCycleID = cycles.selectedCycleID
      path = [.programOverview(cycles.selectedProgramID)]
      if cycles.authenticationDeferred == true {
        cycleMessage = "Sign in again to sync your program change. Your workouts remain on this device."
      }
    }
    return true
  }

  private func openSavedAccount(
    user: AuthenticatedUser, generation: Int, authentication: AuthenticationModel
  ) async -> Bool {
    // Resolve the authenticated account's durable state before waiting for any service.
    // An incomplete onboarding checkpoint still needs the server-first path below.
    if let local = try? progressStore?.load(accountID: user.id),
       (try? validate(local)) != nil, let completed = local.completed,
       let repository = workoutRepository {
      let selectedProgram = local.cycles?.selectedProgramID ?? completed.setup.programID
      if catalog.program(id: selectedProgram) != nil, hasSafeLocalProgress(local, accountID: user.id),
         let sessionResult = try? [repository.activeSession(accountID: user.id)] {
        let session = sessionResult[0]
        savedProgress = local
        restore(local)
        resolvedAccountID = user.id
        activeWorkoutSession = session
        if let session {
          selectedMainTab = .program
          programPath = [.workoutRecording(session.id)]
        }
        releaseReofferedCycleOperations()
        presentSessionUploadErrorIfNeeded(accountID: user.id)
        setupResolution = .idle
        backgroundRestoration = Task { [weak self] in
          await self?.reconcileSavedAccount(user: user, generation: generation, authentication: authentication)
        }
        await backgroundRestoration?.value
        return true
      }
    }
    return false
  }

  private func hasSafeLocalProgress(_ progress: OnboardingProgress, accountID: String) -> Bool {
    guard let completed = progress.completed else { return false }
    let cycleID = progress.cycles?.selectedCycleID ?? completed.setup.cycleID
    return (completed.needsUpload && completed.setup.cycleID == cycleID)
      || progress.cycles?.pendingCreations.contains(where: { $0.cycleID == cycleID }) == true
      || progress.cycles?.locallyKnownProgressCycleIDs?.contains(cycleID) == true
      || (try? workoutRepository?.hasRestorableProgress(accountID: accountID, cycleID: cycleID)) == true
  }

  private func reconcileSavedAccount(
    user: AuthenticatedUser, generation: Int, authentication: AuthenticationModel
  ) async {
    guard let setupService, let progressStore, savedProgress?.completed != nil else { return }
    let cycleGeneration = cycleKnowledgeGeneration
    cycleDiscoveryGeneration += 1
    let discoveryGeneration = cycleDiscoveryGeneration
    do {
      let remote = try await setupService.lookup(for: user)
      guard !Task.isCancelled, generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, authentication.signedInUser?.id == user.id,
            var latest = savedProgress, let current = latest.completed else { return }
      let selectedProgram = latest.cycles?.selectedProgramID ?? current.setup.programID
      let selectedCycle = latest.cycles?.selectedCycleID ?? current.setup.cycleID
      let hasLocalChanges = current.needsUpload || latest.cycles?.pendingCreations.isEmpty == false
        || !(latest.cycles?.pendingActivations ?? []).isEmpty
      if let remote, !hasLocalChanges,
         remote.programID != selectedProgram || remote.cycleID != selectedCycle {
        latest.pendingRemoteSelection = remote
        latest.remoteSelectionDiscoveryPending = nil
      }
      do {
        try progressStore.save(latest, accountID: user.id)
        savedProgress = latest
      } catch {
        // Keep a confirmed change blocked in this process when the save fails.
        savedProgress = latest
        if latest.pendingRemoteSelection != nil {
          programUpdateMessage = "Your program status couldn’t be saved. Free space on this device and try Update again."
        } else {
          workoutErrorMessage = "Your account status couldn’t be saved. Your saved workouts remain on this device. Free space and try again."
          workoutErrorPresented = true
        }
        return
      }
      if latest.pendingRemoteSelection == nil, !hasLocalChanges, let remote,
         let progressService, let workoutRepository {
        if let summary = try? await progressService.lookup(for: user),
           !Task.isCancelled, generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
           discoveryGeneration == cycleDiscoveryGeneration, authentication.signedInUser?.id == user.id,
           summary.cycleID == remote.cycleID, summary.programID == remote.programID {
          do {
            try workoutRepository.restoreProgress(summary, accountID: user.id)
          } catch {
            workoutErrorMessage = "Your updated training progress couldn’t be saved. Your saved workouts remain on this device. Free space and try again."
            workoutErrorPresented = true
          }
        }
      }
      await refreshPreviousPerformances(for: user, generation: generation, authentication: authentication)
    } catch {
      guard !Task.isCancelled, generation == lookupGeneration, cycleGeneration == cycleKnowledgeGeneration,
            discoveryGeneration == cycleDiscoveryGeneration, authentication.signedInUser?.id == user.id else { return }
    }
  }

  private var isSetupIdle: Bool {
    if case .idle = setupResolution { return true }
    return false
  }
}

// MARK: - Sign-out and account reset

extension OnboardingModel {
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
    backgroundRestoration?.cancel()
    backgroundRestoration = nil
    lookupGeneration += 1
    cycleKnowledgeGeneration += 1
    resolvedAccountID = nil
    previousPerformanceUnavailable = false
    setupResolution = .idle
    showsSetupSpinner = false
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
}

// MARK: - Setup and program selection

extension OnboardingModel {
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

  func restore(_ progress: OnboardingProgress) {
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
    let isLocallyCreatedCycle = needsUpload || (savedProgress?.completed?.needsUpload == true
      && savedProgress?.completed?.setup.cycleID == setup.cycleID)
    if isLocallyCreatedCycle {
      var state = progress.cycles ?? ProgramCycleState(selectedProgramID: setup.programID,
        selectedCycleID: setup.cycleID, knownCycles: [], discoveryComplete: false, pendingCreations: [])
      var known = state.locallyKnownProgressCycleIDs ?? []
      if !known.contains(setup.cycleID) { known.append(setup.cycleID) }
      state.locallyKnownProgressCycleIDs = known
      progress.cycles = state
    }
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

  func presentSessionUploadErrorIfNeeded(accountID: String) {
    guard let workoutRepository,
          (try? workoutRepository.hasUnresolvedSetupCycleConflict(accountID: accountID)) == true else { return }
    sessionUploadErrorMessage = "Your completed workout is still saved on this device. It belongs to a different cycle than the one already on your account, so it wasn’t uploaded or moved. Keep this device while the cycle conflict is resolved."
    sessionUploadErrorPresented = true
  }
}
