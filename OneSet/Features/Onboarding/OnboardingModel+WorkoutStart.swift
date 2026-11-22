import Foundation

// MARK: - Starting a new workout

extension OnboardingModel {
  var currentAccountSelection: AccountSelection? {
    resolvedAccountID.map { AccountSelection(accountID: $0, generation: accountSelectionGeneration) }
  }

  private var visiblePath: [OnboardingRoute] { hasCompletedSetup ? programPath : path }

  /// Starts a new session for the previewed workout once Pro is verified. Resuming an existing
  /// session never comes through here. A start already waiting on a check ignores further taps.
  func startWorkout(programID: String, workoutID: String, accountID: String, week: Int? = nil) async {
    guard workoutStartAttempt == nil else { return }
    guard let request = captureWorkoutStart(programID: programID, workoutID: workoutID,
                                            accountID: accountID, week: week) else { return }
    guard let subscriptionAccess else {
      saveNewWorkout(request)
      return
    }
    let attempt = UUID()
    workoutStartAttempt = attempt
    workoutStartGate = WorkoutStartGate(route: request.route, selection: request.selection, status: .checking)
    defer { if workoutStartAttempt == attempt { workoutStartAttempt = nil } }

    let result = await subscriptionAccess.currentAccess(for: request.selection)
    guard workoutStartAttempt == attempt, result.applies(to: currentAccountSelection) else { return }
    if result.access.allowsNewWorkout(), isCurrent(request) {
      workoutStartGate = nil
      saveNewWorkout(request)
      return
    }
    settleGate(for: request.route, selection: request.selection, access: result.access,
               keepsGate: isCurrent(request))
  }

  /// Checks access again after a failed or pending check. Never starts a workout: the user taps Start.
  func recheckWorkoutAccess(route: OnboardingRoute) async {
    guard workoutStartAttempt == nil, let subscriptionAccess, let selection = currentAccountSelection,
          workoutStartGate?.route == route, workoutStartGate?.selection == selection else { return }
    let attempt = UUID()
    workoutStartAttempt = attempt
    workoutStartGate?.status = .checking
    defer { if workoutStartAttempt == attempt { workoutStartAttempt = nil } }
    let result = await subscriptionAccess.refresh(for: selection)
    guard workoutStartAttempt == attempt, result.applies(to: currentAccountSelection) else { return }
    settleGate(for: route, selection: selection, access: result.access, keepsGate: visiblePath.last == route)
  }

  func clearWorkoutStartGate(for route: OnboardingRoute) {
    guard let gate = workoutStartGate, gate.route == route, gate.status != .checking else { return }
    workoutStartGate = nil
  }

  private func settleGate(for route: OnboardingRoute, selection: AccountSelection,
                          access: SubscriptionAccess, keepsGate: Bool) {
    guard keepsGate else {
      workoutStartGate = nil
      return
    }
    let status: WorkoutStartStatus = switch access {
    case .proVerified where access.allowsNewWorkout(): .proActive
    case .verifiedInactive: .proRequired
    case .pendingApproval: .pendingApproval
    default: .unconfirmed
    }
    workoutStartGate = WorkoutStartGate(route: route, selection: selection, status: status)
  }

  private func captureWorkoutStart(programID: String, workoutID: String, accountID: String,
                                   week: Int?) -> WorkoutStartRequest? {
    guard !requiresProgramUpdate, accountID == resolvedAccountID, programID == selectedProgramID,
          let selection = currentAccountSelection else {
      showStartError("Update your program before starting a workout.")
      return nil
    }
    guard let workoutRepository = ensureWorkoutRepository(), let cycleID = restoredCycleID,
          let program = catalog.program(id: programID),
          program.workouts.contains(where: { $0.id == workoutID }) else {
      showStartError("Your workout could not be started. Please try again.")
      return nil
    }
    do {
      let next = try nextOccurrence(repository: workoutRepository, accountID: accountID, cycleID: cycleID,
                                    program: program)
      guard next.workoutID == workoutID, week == nil || next.week == week else {
        showStartError("Complete the earlier workout day before starting this one.")
        return nil
      }
      let route = OnboardingRoute.workoutPreview(programID: programID, workoutID: workoutID, week: week)
      return WorkoutStartRequest(selection: selection, programID: programID, workoutID: workoutID,
        week: week, cycleID: cycleID, occurrenceWeek: next.week, occurrenceDay: next.day,
        route: route, routeWasVisible: visiblePath.last == route)
    } catch {
      showStartError(error.localizedDescription)
      return nil
    }
  }

  /// Rechecks the captured account, program, cycle, occurrence and preview, and that no session exists yet.
  private func isCurrent(_ request: WorkoutStartRequest) -> Bool {
    guard currentAccountSelection == request.selection, !isSigningOut, !requiresProgramUpdate,
          selectedProgramID == request.programID, restoredCycleID == request.cycleID,
          activeWorkoutSession == nil,
          !request.routeWasVisible || visiblePath.last == request.route,
          let workoutRepository, let program = catalog.program(id: request.programID),
          (try? workoutRepository.activeSession(accountID: request.selection.accountID)) == nil,
          let next = try? nextOccurrence(repository: workoutRepository, accountID: request.selection.accountID,
                                         cycleID: request.cycleID, program: program)
    else { return false }
    return next.workoutID == request.workoutID && next.week == request.occurrenceWeek
      && next.day == request.occurrenceDay
  }

  private func nextOccurrence(repository: WorkoutRepository, accountID: String, cycleID: UUID,
                              program: TrainingProgram) throws -> (week: Int, day: Int, workoutID: String) {
    try repository.nextOccurrence(accountID: accountID, cycleID: cycleID,
      programID: program.id, workoutIDs: program.workouts(inWeek: 1).map(\.id),
      evenWeekWorkoutIDs: program.evenWeekWorkoutIDs)
  }

  private func saveNewWorkout(_ request: WorkoutStartRequest) {
    guard let workoutRepository, let program = catalog.program(id: request.programID),
          let workout = program.workouts.first(where: { $0.id == request.workoutID }) else { return }
    do {
      #if DEBUG
      let startedAt = ProcessInfo.processInfo.arguments.contains("--ui-elapsed-session")
        ? Date.now.addingTimeInterval(-120) : .now
      #else
      let startedAt = Date.now
      #endif
      let session = WorkoutSession(accountID: request.selection.accountID, cycleID: request.cycleID,
        program: program, workout: workout, week: request.occurrenceWeek, day: request.occurrenceDay,
        weightUnit: weightUnit, startedAt: startedAt)
      let startedSession = try workoutRepository.start(session, exerciseLibrary: catalog.exerciseLibrary)
      activeWorkoutSession = startedSession
      let route = OnboardingRoute.workoutRecording(startedSession.id)
      if hasCompletedSetup { programPath.append(route) } else { path.append(route) }
    } catch {
      showStartError(error.localizedDescription)
    }
  }

  private func showStartError(_ message: String) {
    workoutErrorMessage = message
    workoutErrorPresented = true
  }

  /// Opens the existing session for a preview that matches it, under the existing ownership rules.
  /// Returns false when the preview has no matching session to resume.
  func resumeWorkout(programID: String, workoutID: String, accountID: String, week: Int?) -> Bool {
    guard let session = activeWorkoutSession, session.accountID == accountID,
          session.programID == programID, session.workoutID == workoutID,
          week == nil || week == session.week else { return false }
    let route = OnboardingRoute.workoutRecording(session.id)
    if hasCompletedSetup { programPath.append(route) } else { path.append(route) }
    return true
  }
}

// MARK: - Checkout entry point

extension OnboardingModel {
  /// Shows the paywall entry point over a preview whose fresh check verified no active Pro.
  func presentPlans(for route: OnboardingRoute) {
    guard let gate = workoutStartGate, gate.route == route, gate.status == .proRequired,
          gate.selection == currentAccountSelection, plansRequest == nil else { return }
    plansRequest = PlansRequest(route: route, selection: gate.selection)
  }

  func dismissPlans() {
    plansRequest = nil
  }

  /// Reports the outcome of checkout. Returns to the preview if it is still the one the user left,
  /// without starting the workout.
  func finishCheckout(_ request: PlansRequest, result: SubscriptionAccessResult) {
    guard plansRequest?.id == request.id, result.applies(to: currentAccountSelection),
          request.selection == result.selection else { return }
    if result.access != .verifiedInactive { plansRequest = nil }
    guard workoutStartGate?.route == request.route, visiblePath.last == request.route else { return }
    settleGate(for: request.route, selection: request.selection, access: result.access, keepsGate: true)
  }

  /// Purchases a package through the access service on behalf of an open plans sheet.
  func purchasePlan(_ package: SubscriptionPackage, request: PlansRequest) async throws {
    guard let subscriptionAccess, plansRequest?.id == request.id else { throw SubscriptionOperationError.failed }
    let result = try await subscriptionAccess.purchase(package, for: request.selection)
    finishCheckout(request, result: result)
  }
}
