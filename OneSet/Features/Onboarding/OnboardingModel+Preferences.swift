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

  /// Single hook for uploading preference changes (ticket #124): fold the values into a pending
  /// setup upload, or record a pending preference update. Nothing is uploaded yet.
  private func preferencesSavedLocally(unit: WeightUnit, days: Int, accountID: String) {}
}
