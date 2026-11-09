import Foundation

extension OnboardingModel {
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
      let startedSession = try workoutRepository.start(session)
      activeWorkoutSession = startedSession
      let route = OnboardingRoute.workoutRecording(startedSession.id)
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

  func scheduleWorkoutEdit(sessionID: UUID, slotID: String, input: WorkoutDraftSaves.Input) {
    guard !isApplyingWorkoutEdit, let save = workoutDraftWriter(sessionID: sessionID) else { return }
    workoutDraftSaves.schedule(input, for: slotID, save: save)
  }

  @discardableResult
  func flushWorkoutEdits(sessionID: UUID, slotID: String? = nil) async -> Bool {
    guard let save = workoutDraftWriter(sessionID: sessionID) else { return false }
    let saved = await workoutDraftSaves.flush(slotID: slotID, save: save)
    return saved && activeWorkoutSession?.id == sessionID
  }

  func applyWorkoutEdit(sessionID: UUID, slotID: String? = nil, action: () -> Bool) async -> Bool {
    guard !isApplyingWorkoutEdit else { return false }
    isApplyingWorkoutEdit = true
    defer { isApplyingWorkoutEdit = false }
    guard await flushWorkoutEdits(sessionID: sessionID, slotID: slotID) else {
      let failures = workoutDraftSaves.failures
      if activeWorkoutSession?.id == sessionID,
         let message = slotID.flatMap({ failures[$0] }) ?? failures.values.first {
        workoutErrorMessage = message
        workoutErrorPresented = true
      }
      return false
    }
    return action()
  }

  private func workoutDraftWriter(sessionID: UUID) -> WorkoutDraftSaves.Save? {
    guard let session = activeWorkoutSession, session.id == sessionID, let workoutRepository else { return nil }
    let accountID = session.accountID
    return { [weak self] slotID, input in
      try await workoutRepository.saveRecordingInput(sessionID: sessionID, accountID: accountID, slotID: slotID,
                                                     weightInput: input.weight, repsInput: input.reps)
      guard let self, var current = activeWorkoutSession, current.id == sessionID else { return }
      // Keep completion and rest changes made while the write was in flight.
      var entry = current.setEntries[slotID] ?? .init()
      entry.weightInput = input.weight
      entry.repsInput = input.reps
      current.setEntries[slotID] = entry
      activeWorkoutSession = current
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

  func refreshPreviousPerformances(
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
