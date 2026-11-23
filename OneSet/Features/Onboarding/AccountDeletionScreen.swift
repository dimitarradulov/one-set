import SwiftUI

/// Settings > Account deletion. Finds the signed-in user and builds the deletion model once.
struct AccountDeletionRoute: View {
  let onboarding: OnboardingModel
  let authentication: AuthenticationModel
  @Environment(WorkoutNetworkMonitor.self) private var network

  var body: some View {
    if let model = onboarding.makeAccountDeletionModel(authentication: authentication, network: network) {
      AccountDeletionScreen(model: model, onboarding: onboarding, network: network)
    } else {
      ContentUnavailableView("Account deletion unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
        .background(OneSetColors.background)
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct AccountDeletionScreen: View {
  @State private var model: AccountDeletionModel
  let onboarding: OnboardingModel
  let network: WorkoutNetworkMonitor
  @State private var confirmationPresented = false
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase

  init(model: AccountDeletionModel, onboarding: OnboardingModel, network: WorkoutNetworkMonitor) {
    _model = State(initialValue: model)
    self.onboarding = onboarding
    self.network = network
  }

  private var isDeleting: Bool { model.phase == .deleting }

  var body: some View {
    Form {
      Section {
        AccountDeletionNotice(
          symbol: "trash", text: Copy.whatGetsDeleted, identifier: "accountDeletion.whatGetsDeleted")
      }
      .listRowBackground(OneSetColors.surface)

      Section {
        AccountDeletionNotice(
          symbol: "creditcard", text: Copy.subscriptionNotice, identifier: "accountDeletion.subscriptionNotice")
        Button {
          Task { await ManageSubscriptions.open(fallback: openURL) }
        } label: {
          Label(Copy.manageSubscription, systemImage: "arrow.up.forward.square")
        }
        .accessibilityIdentifier("accountDeletion.manageSubscription")
      } header: {
        Text("Apple subscription")
      }
      .listRowBackground(OneSetColors.surface)

      if model.showsUnsyncedWarning {
        Section {
          AccountDeletionNotice(
            symbol: "exclamationmark.triangle", text: Copy.unsyncedWarning,
            identifier: "accountDeletion.unsyncedWarning")
        }
        .listRowBackground(OneSetColors.surface)
      }

      if let blocker = model.blocker {
        blockerSection(blocker)
      }

      if case .failed(let failure) = model.phase {
        failureSection(failure)
      } else {
        deleteSection
      }
    }
    .scrollContentBackground(.hidden)
    .background(OneSetColors.background)
    .navigationTitle(Copy.title)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(isDeleting)
    .interactiveDismissDisabled(isDeleting)
    .toolbar(.visible, for: .tabBar)
    .alert(Copy.confirmationTitle, isPresented: $confirmationPresented) {
      Button(Copy.deleteButton, role: .destructive) {
        Task { await model.confirmDeletion() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(Copy.confirmationMessage)
    }
    .accessibilityIdentifier("accountDeletion.screen")
    .task { model.refresh() }
    .onChange(of: network.isConnected) { model.refresh() }
    .onChange(of: onboarding.activeWorkoutSession?.id) { model.refresh() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { model.refresh() }
    }
  }

  // MARK: Sections

  @ViewBuilder
  private func blockerSection(_ blocker: AccountDeletionModel.Blocker) -> some View {
    Section {
      switch blocker {
      case .offline:
        AccountDeletionNotice(
          symbol: "wifi.slash", text: Copy.offlineBlock, identifier: "accountDeletion.blocker.offline")
      case .activeWorkout:
        AccountDeletionNotice(
          symbol: "dumbbell", text: Copy.activeWorkoutBlock, identifier: "accountDeletion.blocker.activeWorkout")
        Button {
          onboarding.selectedMainTab = .program
          onboarding.returnToActiveWorkout()
        } label: {
          Label(Copy.goToWorkout, systemImage: "arrow.right.circle")
        }
        .accessibilityIdentifier("accountDeletion.goToWorkout")
      }
    }
    .listRowBackground(OneSetColors.surface)
  }

  @ViewBuilder
  private func failureSection(_ failure: AccountDeletionModel.Failure) -> some View {
    Section {
      AccountDeletionNotice(
        symbol: "exclamationmark.octagon",
        text: failure == .request ? Copy.requestFailure : Copy.cleanupFailure,
        tint: OneSetColors.error, identifier: "accountDeletion.failure")
    }
    .listRowBackground(OneSetColors.surface)

    Section {
      actionButton(
        title: Copy.retry, systemImage: "arrow.clockwise", identifier: "accountDeletion.retry",
        isEnabled: failure == .cleanup || model.canDelete
      ) {
        Task { await model.retry() }
      }
    }
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }

  private var deleteSection: some View {
    Section {
      actionButton(
        title: Copy.deleteButton, systemImage: nil, identifier: "accountDeletion.delete",
        isEnabled: model.canDelete
      ) {
        confirmationPresented = true
      }
    }
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }

  /// The destructive action: a filled error-color button with dark text, 52 pt tall like other primary actions.
  private func actionButton(
    title: String, systemImage: String?, identifier: String, isEnabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isDeleting {
          ProgressView().tint(Color.black)
        } else if let systemImage {
          Image(systemName: systemImage)
        }
        Text(title)
      }
      .font(OneSetTypography.button)
      .foregroundStyle(isEnabled || isDeleting ? Color.black : OneSetColors.textSecondary)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(
        isEnabled || isDeleting ? OneSetColors.error : OneSetColors.surfaceRaised,
        in: RoundedRectangle(cornerRadius: 12)
      )
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled || isDeleting)
    .accessibilityIdentifier(identifier)
  }

  private enum Copy {
    static let title = "Delete account"
    static let whatGetsDeleted =
      "Deleting your account permanently removes your programs, workout history, progress, and settings from OneSet and from this device. This can’t be undone."
    static let subscriptionNotice =
      "Deleting your account doesn’t cancel your subscription. Apple keeps billing you until you cancel it in your Apple Account settings."
    static let manageSubscription = "Manage subscription"
    static let unsyncedWarning =
      "Some finished workouts haven’t been saved to your account yet. They’ll be deleted too."
    static let activeWorkoutBlock = "Finish or discard your current workout before deleting your account."
    static let goToWorkout = "Go to workout"
    static let offlineBlock = "Connect to the internet to delete your account."
    static let deleteButton = "Delete account"
    static let confirmationTitle = "Delete your account?"
    static let confirmationMessage = "Your programs, history, and progress will be permanently deleted."
    static let requestFailure = "Your account couldn’t be deleted. Check your connection and try again."
    static let cleanupFailure =
      "Your account was deleted, but this device couldn’t finish signing you out. Try again."
    static let retry = "Retry"
  }
}

/// An icon beside a short sentence, the same row shape as the subscription status.
private struct AccountDeletionNotice: View {
  let symbol: String
  let text: String
  var tint: Color = OneSetColors.accent
  let identifier: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(OneSetTypography.bodyStrong)
        .foregroundStyle(tint)
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
      Text(text)
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier)
  }
}
