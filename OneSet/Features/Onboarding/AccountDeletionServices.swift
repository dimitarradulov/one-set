import Foundation

/// The app-level pieces account deletion needs beyond what `OnboardingModel` already owns.
@MainActor
struct AccountDeletionServices {
  let service: any AccountDeletionService
  let onboardingProgress: any OnboardingProgressStore
  let savedSubscriptionAccess: any SavedSubscriptionAccessStore
  let pendingSubscriptionOperations: any PendingSubscriptionOperationStore
}

extension OnboardingModel {
  /// Builds the deletion model for the signed-in account, wired to the live coordinators,
  /// repository and sign-out. Nil when the app has no deletion services or no signed-in user.
  func makeAccountDeletionModel(
    authentication: AuthenticationModel, network: WorkoutNetworkMonitor
  ) -> AccountDeletionModel? {
    guard let services = accountDeletion, let user = authentication.signedInUser else { return nil }
    return AccountDeletionModel(
      user: user,
      uploads: OnboardingAccountDeletionUploads(model: self, authentication: authentication),
      service: services.service,
      erasure: OnboardingAccountDeletionErasure(model: self, services: services),
      signOut: AuthenticationAccountDeletionSignOut(authentication: authentication, onboarding: self),
      connectivity: NetworkAccountDeletionConnectivity(monitor: network),
      workouts: OnboardingAccountDeletionWorkoutState(model: self)
    )
  }
}

@MainActor
private struct OnboardingAccountDeletionUploads: AccountDeletionUploads {
  let model: OnboardingModel
  let authentication: AuthenticationModel

  func suspend(accountID: String) async {
    await model.completedSessionUploadCoordinator?.suspend(accountID: accountID)
    await model.cycleSyncCoordinator.suspend(accountID: accountID)
  }

  func resume(accountID: String) {
    model.completedSessionUploadCoordinator?.resume(accountID: accountID)
    model.cycleSyncCoordinator.resume(accountID: accountID)
  }

  func drain(for user: AuthenticatedUser) async {
    await model.uploadPendingCycles(using: authentication)
    await model.retryPendingSessionUploads(using: authentication)
  }
}

@MainActor
private struct OnboardingAccountDeletionWorkoutState: AccountDeletionWorkoutState {
  let model: OnboardingModel

  var hasActiveWorkout: Bool { model.activeWorkoutSession != nil }

  func unsyncedCompletedSessionCount(accountID: String) throws -> Int {
    // Without an open repository there is nothing on this device to lose.
    try model.workoutRepository?.sessionUploadQueue(accountID: accountID).count ?? 0
  }
}

@MainActor
private struct OnboardingAccountDeletionErasure: AccountDeletionLocalErasure {
  let model: OnboardingModel
  let services: AccountDeletionServices

  func erase(accountID: String) throws {
    // Reopens storage if needed, so a closed repository can never skip the workout data.
    guard let repository = model.ensureWorkoutRepository() else {
      throw LocalAccountErasureError(failures: [CocoaError(.fileReadNoPermission)])
    }
    try LocalAccountErasure.standard(
      repository: repository,
      onboardingProgress: services.onboardingProgress,
      savedSubscriptionAccess: services.savedSubscriptionAccess,
      pendingSubscriptionOperations: services.pendingSubscriptionOperations
    ).erase(accountID: accountID)
  }
}

@MainActor
private struct AuthenticationAccountDeletionSignOut: AccountDeletionSignOut {
  let authentication: AuthenticationModel
  let onboarding: OnboardingModel

  func signOut() async throws {
    try await authentication.signOutThrowing()
    // The deletion screen leaves with the session, so the confirmation is carried to Welcome here.
    onboarding.noteAccountDeleted()
  }
}

@MainActor
private struct NetworkAccountDeletionConnectivity: AccountDeletionConnectivity {
  let monitor: WorkoutNetworkMonitor

  var isOnline: Bool {
    #if DEBUG
    // Simulator routes need a fixed state, not whatever the host network is doing.
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-account-deletion-offline") { return false }
    if arguments.contains(where: AppLaunchConfiguration.accountDeletionRoutes.contains) { return true }
    #endif
    return monitor.isConnected
  }
}
