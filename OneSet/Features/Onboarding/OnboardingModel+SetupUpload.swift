import Foundation

extension OnboardingModel {
  func retryCompletedUploads(using authentication: AuthenticationModel) async {
    preferenceUploadAuthentication = authentication
    while !Task.isCancelled, authentication.signedInUser != nil {
      await uploadCompletedSetup(using: authentication)
      await uploadPendingCycles(using: authentication)
      do { try await Task.sleep(for: .seconds(15)) } catch { break }
    }
  }

  /// Uploads pending setup, then any pending preference update. Every setup upload trigger
  /// (restoration, foreground entry, connectivity, periodic retry) therefore also retries preferences.
  func uploadCompletedSetup(using authentication: AuthenticationModel) async {
    await uploadPendingSetup(using: authentication)
    await uploadPendingPreferenceUpdate(using: authentication)
  }

  func recoverPendingSetupAfterProgramRemoval(_ completed: CompletedOnboarding, accountID: String) {
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
