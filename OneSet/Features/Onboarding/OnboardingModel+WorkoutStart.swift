import Foundation

// MARK: - Starting a new workout

extension OnboardingModel {
  var currentAccountSelection: AccountSelection? {
    guard let accountID = resolvedAccountID else { return nil }
    if let accountSelectionProvider {
      return accountSelectionProvider().flatMap { $0.accountID == accountID ? $0 : nil }
    }
    return AccountSelection(accountID: accountID, generation: accountSelectionGeneration)
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
  /// Opens checkout over a preview whose fresh check verified no active Pro.
  func presentPlans(for route: OnboardingRoute) {
    guard let gate = workoutStartGate, gate.route == route, gate.status == .proRequired,
          gate.selection == currentAccountSelection, paywall == nil,
          let subscriptionAccess, let paywallHost else { return }
    let selection = gate.selection
    var opened: PaywallModel?
    let model = PaywallModel(
      selection: selection,
      currentSelection: { [weak self] in self?.currentAccountSelection },
      access: subscriptionAccess, host: paywallHost, approval: paywallApproval,
      onResult: { [weak self] result in
        guard let self, let opened else { return }
        finishCheckout(opened, route: route, selection: selection, result: result)
      })
    opened = model
    paywallRoute = route
    paywall = model
  }

  /// Returns to the preview after checkout without starting the workout. A verified purchase
  /// shows Start again, and an unresolved one rechecks access in place.
  private func finishCheckout(_ model: PaywallModel, route: OnboardingRoute, selection: AccountSelection,
                              result: PaywallResult) {
    if paywall?.id == model.id {
      paywall = nil
      paywallRoute = nil
    }
    guard selection == currentAccountSelection, workoutStartGate?.route == route,
          visiblePath.last == route else { return }
    switch result {
    case .verifiedPro:
      settleGate(for: route, selection: selection, access: .proVerified(expiresAt: .distantFuture),
                 keepsGate: true)
    case .closed:
      break
    case .unresolved:
      Task { await recheckWorkoutAccess(route: route) }
    }
  }
}
