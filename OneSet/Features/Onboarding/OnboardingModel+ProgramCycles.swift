import Foundation

extension OnboardingModel {
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
          let cycleService, let progress = savedProgress, let setup = progress.completed?.setup,
          let progressStore else { return }
    let generation = lookupGeneration
    let cycleGeneration = cycleKnowledgeGeneration
    cycleDiscoveryGeneration += 1
    let discoveryGeneration = cycleDiscoveryGeneration
    var discoveryReturned = false
    do {
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
            || latest.pendingRemoteSelection != nil {
          latest.pendingRemoteSelection = AccountSetup(preferredUnit: latest.weightUnit,
            trainingDays: latest.trainingDays, programID: selected.programID, cycleID: selected.cycleID)
          latest.remoteSelectionDiscoveryPending = nil
        }
      }
      state.knownCycles = remote.cycles
      for cycle in state.pendingCreations where !state.knownCycles.contains(where: { $0.cycleID == cycle.cycleID }) {
        state.knownCycles.append(cycle)
      }
      state.discoveryComplete = true
      latest.cycles = state
      savedProgress = latest
      try progressStore.save(latest, accountID: user.id)
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
            do {
              try workoutRepository.restoreProgress(summary, accountID: user.id)
            } catch {
              workoutErrorMessage = "Your updated training progress couldn’t be saved. Your saved workouts remain on this device. Free space and try again."
              workoutErrorPresented = true
            }
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
}
