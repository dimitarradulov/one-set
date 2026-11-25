import Foundation

// MARK: - Preferred unit and training frequency (Settings)

extension OnboardingModel {
  /// The preferred unit is fixed while a session is active so one session never mixes units.
  var canChangeUnits: Bool { activeWorkoutSession == nil }

  static let unitsLockedNote = "Finish or discard your workout to change units."

  @discardableResult
  func setPreferredUnit(_ unit: WeightUnit) -> Bool {
    guard canChangeUnits else { return false }
    return savePreferences(unit: unit, days: trainingDays)
  }

  @discardableResult
  func setTrainingDays(_ days: Int) -> Bool {
    savePreferences(unit: weightUnit, days: days)
  }

  /// Saves to the account's local onboarding document first, then updates in-memory values.
  /// A failed save leaves both unchanged and reports the failure.
  private func savePreferences(unit: WeightUnit, days: Int) -> Bool {
    guard !isSigningOut, (2...5).contains(days) else { return false }
    guard unit != weightUnit || days != trainingDays else { return true }
    if let accountID = resolvedAccountID, let progressStore, var progress = savedProgress {
      progress.weightUnit = unit
      progress.trainingDays = days
      if let completed = progress.completed {
        let setup = AccountSetup(preferredUnit: unit, trainingDays: days,
          programID: completed.setup.programID, cycleID: completed.setup.cycleID)
        progress.completed = CompletedOnboarding(setup: setup, needsUpload: completed.needsUpload)
        if completed.needsUpload {
          // Setup has not reached the account yet: the pending setup carries the latest values.
          progress.pendingPreferenceUpdate = nil
        } else {
          progress.pendingPreferenceUpdate = nextPendingPreferenceUpdate(unit: unit, days: days, current: progress)
        }
      }
      do {
        try progressStore.save(progress, accountID: accountID)
      } catch {
        progressErrorMessage = "Your change couldn’t be saved on this device. Please try again. "
          + error.localizedDescription
        progressErrorPresented = true
        return false
      }
      savedProgress = progress
      weightUnit = unit
      trainingDays = days
      preferencesSavedLocally(unit: unit, days: days, accountID: accountID)
    } else {
      // Development preview routes have no account or store and do not persist.
      weightUnit = unit
      trainingDays = days
    }
    return true
  }

  private func nextPendingPreferenceUpdate(
    unit: WeightUnit, days: Int, current progress: OnboardingProgress
  ) -> PendingPreferenceUpdate {
    preferenceChangeCounter = max(preferenceChangeCounter, progress.pendingPreferenceUpdate?.sequence ?? 0) + 1
    return PendingPreferenceUpdate(
      preferences: AccountPreferences(preferredUnit: unit, trainingDays: days),
      sequence: preferenceChangeCounter
    )
  }

  /// Called after a successful local save. The values are already folded into the pending setup
  /// or recorded as a pending preference update, so this only starts the background upload.
  private func preferencesSavedLocally(unit: WeightUnit, days: Int, accountID: String) {
    guard let authentication = preferenceUploadAuthentication,
          authentication.signedInUser?.id == accountID else { return }
    Task { await uploadCompletedSetup(using: authentication) }
  }
}
