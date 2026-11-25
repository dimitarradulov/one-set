import Foundation
import OSLog

private let logger = Logger(subsystem: "OneSet", category: "PreferenceUpload")

// MARK: - Uploading preference changes (PATCH /v1/me)

extension OnboardingModel {
  /// Whether this account has a preference change that has not reached the server and is still
  /// being retried. A rejected change is kept locally but no longer counts as unsent.
  var hasUnsentPreferenceUpdate: Bool { savedProgress?.pendingPreferenceUpdate?.isUnsent == true }

  /// Sends the latest pending preference update once setup has been acknowledged. Temporary
  /// failures leave it pending for the next trigger. A `400` keeps the local value and stops retrying.
  func uploadPendingPreferenceUpdate(using authentication: AuthenticationModel) async {
    while await uploadPreferenceUpdateOnce(using: authentication) {}
  }

  /// Returns true when a newer change replaced the one just sent and should be sent right away.
  private func uploadPreferenceUpdateOnce(using authentication: AuthenticationModel) async -> Bool {
    guard !isSigningOut, let user = authentication.signedInUser, resolvedAccountID == user.id,
          savedProgress?.completed?.needsUpload == false,
          let update = savedProgress?.pendingPreferenceUpdate, update.isUnsent,
          let setupService, preferenceUploadingGeneration != lookupGeneration else { return false }
    let generation = lookupGeneration
    preferenceUploadingGeneration = generation
    defer { if preferenceUploadingGeneration == generation { preferenceUploadingGeneration = nil } }
    do {
      _ = try await setupService.updatePreferences(update.preferences, for: user)
      guard isCurrent(generation: generation, user: user, authentication: authentication) else { return false }
      // A newer change keeps its own pending record, whatever these values were.
      guard var progress = savedProgress, progress.pendingPreferenceUpdate?.sequence == update.sequence else {
        return savedProgress?.pendingPreferenceUpdate?.isUnsent == true
      }
      progress.pendingPreferenceUpdate = nil
      persistPreferenceProgress(progress, accountID: user.id)
      return false
    } catch {
      guard isCurrent(generation: generation, user: user, authentication: authentication) else { return false }
      guard (error as? AccountSetupError) == .invalidPreferences else { return false }
      logger.error("Account rejected the preference update with 400; keeping the local value")
      guard var progress = savedProgress, progress.pendingPreferenceUpdate?.sequence == update.sequence else {
        return savedProgress?.pendingPreferenceUpdate?.isUnsent == true
      }
      progress.pendingPreferenceUpdate?.rejected = true
      persistPreferenceProgress(progress, accountID: user.id)
      return false
    }
  }

  private func isCurrent(generation: Int, user: AuthenticatedUser, authentication: AuthenticationModel) -> Bool {
    generation == lookupGeneration && resolvedAccountID == user.id
      && authentication.signedInUser?.id == user.id && !isSigningOut
  }

  /// A setup acknowledgment that carried older values must not undo a change made while it was in
  /// flight: keep the local values and send them as a preference update.
  func keepLocalPreferencesAfterSetupAcknowledgment(_ preferences: AccountPreferences, accountID: String) {
    guard var progress = savedProgress, let completed = progress.completed else { return }
    preferenceChangeCounter = max(preferenceChangeCounter, progress.pendingPreferenceUpdate?.sequence ?? 0) + 1
    progress.weightUnit = preferences.preferredUnit
    progress.trainingDays = preferences.trainingDays
    progress.completed = CompletedOnboarding(
      setup: AccountSetup(preferredUnit: preferences.preferredUnit, trainingDays: preferences.trainingDays,
        programID: completed.setup.programID, cycleID: completed.setup.cycleID),
      needsUpload: completed.needsUpload
    )
    progress.pendingPreferenceUpdate = PendingPreferenceUpdate(
      preferences: preferences, sequence: preferenceChangeCounter)
    persistPreferenceProgress(progress, accountID: accountID)
    weightUnit = preferences.preferredUnit
    trainingDays = preferences.trainingDays
  }

  private func persistPreferenceProgress(_ progress: OnboardingProgress, accountID: String) {
    do {
      try progressStore?.save(progress, accountID: accountID)
      savedProgress = progress
    } catch {
      // The in-memory state stays as it was, so the next trigger retries; the upload is idempotent.
      logger.error("Preference update bookkeeping could not be saved: \(error.localizedDescription)")
    }
  }
}
