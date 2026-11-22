import Foundation

// MARK: - Trial access

extension OnboardingModel {
  func continueWithoutTrial() {
    completeSetupFromTrial(alertOnFailure: true)
  }

  /// Saves the setup locally and opens the program from the trial screen. Returns false when the
  /// trial route no longer matches or the save failed. Upload is left to the caller.
  @discardableResult
  func completeSetupFromTrial(alertOnFailure: Bool) -> Bool {
    guard !isSigningOut, let selectedProgramID,
          catalog.offeredPrograms.contains(where: { $0.id == selectedProgramID }),
          path.last == .trialPreview(selectedProgramID)
    else { return false }

    if let accountID = resolvedAccountID {
      let setup = AccountSetup(preferredUnit: weightUnit, trainingDays: trainingDays,
                               programID: selectedProgramID, cycleID: UUID())
      do {
        try storeCompleted(setup, needsUpload: true, accountID: accountID)
        apply(setup)
        uploadMessage = "Setup saved on this device. Waiting to upload."
        return true
      } catch {
        if alertOnFailure {
          progressErrorMessage = "Your setup couldn’t be saved on this device. Please try again. "
            + error.localizedDescription
          progressErrorPresented = true
        }
        return false
      }
    }
    path.append(.programOverview(selectedProgramID))
    return true
  }

  /// The status the trial screen shows for `programID`. Without a gate the screen is waiting for its
  /// first check, or has no account or service to check with.
  func trialStatus(for programID: String) -> TrialAccessStatus {
    if let gate = trialGate, gate.programID == programID, gate.selection == currentAccountSelection {
      return gate.status
    }
    return subscriptionAccess == nil || currentAccountSelection == nil ? .unconfirmed : .checking
  }

  /// Checks access for the trial screen, then follows later updates until the task is cancelled.
  /// Confirmed Pro saves the setup and opens the program, whichever result reports it first.
  func watchTrialAccess(programID: String, using authentication: AuthenticationModel) async {
    guard let subscriptionAccess, let selection = currentAccountSelection,
          isTrialCurrent(programID: programID, selection: selection) else { return }
    let watchID = UUID()
    trialWatchID = watchID
    defer {
      // A stream that simply ends keeps the last decision. Leaving the screen clears it.
      if trialWatchID == watchID, Task.isCancelled {
        trialWatchID = nil
        if trialGate?.programID == programID { trialGate = nil }
      }
    }
    let stream = subscriptionAccess.updates(for: selection)
    let checkID = beginTrialCheck(programID: programID, selection: selection)
    let first = await subscriptionAccess.currentAccess(for: selection)
    guard !Task.isCancelled else { return }
    applyTrialResult(first, programID: programID, checkID: checkID, using: authentication)
    // Setup completing or the trial route changing ends the watch.
    guard isTrialCurrent(programID: programID, selection: selection) else { return }
    for await update in stream {
      guard !Task.isCancelled, trialWatchID == watchID else { return }
      applyTrialResult(update, programID: programID, checkID: nil, using: authentication)
      guard isTrialCurrent(programID: programID, selection: selection) else { return }
    }
  }

  /// Checks again after a failed or pending result, without opening checkout.
  func retryTrialAccess(programID: String, using authentication: AuthenticationModel) async {
    guard let subscriptionAccess, let selection = currentAccountSelection,
          let gate = trialGate, gate.programID == programID, gate.selection == selection,
          gate.status == .unconfirmed || gate.status == .pendingApproval || gate.status == .offer,
          isTrialCurrent(programID: programID, selection: selection) else { return }
    let checkID = beginTrialCheck(programID: programID, selection: selection)
    let result = await subscriptionAccess.refresh(for: selection)
    applyTrialResult(result, programID: programID, checkID: checkID, using: authentication)
  }

  /// Retries saving the setup after Pro was verified. Never checks or charges again.
  func retryTrialSetupSave(programID: String, using authentication: AuthenticationModel) {
    guard let gate = trialGate, gate.programID == programID, gate.status == .saveFailed,
          gate.selection == currentAccountSelection,
          isTrialCurrent(programID: programID, selection: gate.selection) else { return }
    completeTrialSetup(programID: programID, selection: gate.selection, using: authentication)
  }

  /// Opens checkout from a trial screen whose fresh check verified no active Pro.
  func presentTrialPlans(programID: String, using authentication: AuthenticationModel) {
    guard let gate = trialGate, gate.programID == programID, gate.status == .offer,
          gate.selection == currentAccountSelection, paywall == nil,
          let subscriptionAccess, let paywallHost else { return }
    let selection = gate.selection
    let route = OnboardingRoute.trialPreview(programID)
    openCheckout(route: route, selection: selection, access: subscriptionAccess, host: paywallHost,
                 onResult: { [weak self] opened, result in
      self?.finishTrialCheckout(opened, programID: programID, selection: selection, result: result,
                                using: authentication)
    })
  }

  // MARK: Private

  private func beginTrialCheck(programID: String, selection: AccountSelection) -> UUID {
    let checkID = UUID()
    trialCheckID = checkID
    trialGate = TrialGate(programID: programID, selection: selection, status: .checking)
    return checkID
  }

  /// The trial route is still the visible step for this account, program, and unfinished setup.
  private func isTrialCurrent(programID: String, selection: AccountSelection) -> Bool {
    !isSigningOut && !hasCompletedSetup && selectedProgramID == programID
      && path.last == .trialPreview(programID) && currentAccountSelection == selection
      && catalog.offeredPrograms.contains(where: { $0.id == programID })
  }

  /// `checkID` is nil for pushed updates, which are always newer than the check that preceded them.
  private func applyTrialResult(_ result: SubscriptionAccessResult, programID: String, checkID: UUID?,
                                using authentication: AuthenticationModel) {
    guard checkID == nil || trialCheckID == checkID, result.applies(to: currentAccountSelection),
          isTrialCurrent(programID: programID, selection: result.selection) else { return }
    if trialGate?.status == .saveFailed || trialGate?.status == .saving { return }
    if result.access.allowsNewWorkout() {
      completeTrialSetup(programID: programID, selection: result.selection, using: authentication)
      return
    }
    let status: TrialAccessStatus = switch result.access {
    case .verifiedInactive: .offer
    case .pendingApproval: .pendingApproval
    case .checking: .checking
    default: .unconfirmed
    }
    trialGate = TrialGate(programID: programID, selection: result.selection, status: status)
  }

  /// Pro is verified. Saves the setup and opens the program once, then uploads it in the background.
  private func completeTrialSetup(programID: String, selection: AccountSelection,
                                  using authentication: AuthenticationModel) {
    guard isTrialCurrent(programID: programID, selection: selection) else { return }
    trialGate = TrialGate(programID: programID, selection: selection, status: .saving)
    paywall = nil
    paywallRoute = nil
    guard completeSetupFromTrial(alertOnFailure: false) else {
      trialGate = TrialGate(programID: programID, selection: selection, status: .saveFailed)
      return
    }
    trialGate = nil
    Task { await uploadCompletedSetup(using: authentication) }
  }

  private func finishTrialCheckout(_ model: PaywallModel, programID: String, selection: AccountSelection,
                                   result: PaywallResult, using authentication: AuthenticationModel) {
    if paywall?.id == model.id {
      paywall = nil
      paywallRoute = nil
    }
    guard isTrialCurrent(programID: programID, selection: selection) else { return }
    switch result {
    case .verifiedPro:
      completeTrialSetup(programID: programID, selection: selection, using: authentication)
    case .closed:
      break
    case .unresolved:
      Task { await retryTrialAccess(programID: programID, using: authentication) }
    }
  }
}
