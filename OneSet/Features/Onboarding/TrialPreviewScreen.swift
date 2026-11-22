import SwiftUI

/// The trial step of setup. It shows the shared access decision and offers checkout only after a
/// fresh check verified there is no active Pro. Continue Without Trial is always available until
/// Pro is verified and setup is saving.
struct TrialPreviewScreen: View {
  let program: TrainingProgram
  let status: TrialAccessStatus
  let onSeePlans: () -> Void
  let onRetryAccess: () -> Void
  let onRetrySave: () -> Void
  let onContinueWithoutTrial: () -> Void

  private var offersSkip: Bool {
    status != .saving && status != .saveFailed
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Train with OneSet Pro")
                .font(OneSetTypography.h1)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("trial.title")

              Text("Start workouts in your selected program. Eligible Apple accounts get a 7-day free trial.")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            programCard

            statusNotice
          }
          .frame(maxWidth: 560, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 24)
          .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)

        VStack(spacing: 0) {
          if let action = primaryAction {
            Button(action: action.run) {
              Text(action.title)
                .font(OneSetTypography.button)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(action.identifier)
          }

          if offersSkip {
            Button("Continue Without Trial", action: onContinueWithoutTrial)
              .font(OneSetTypography.button)
              .foregroundStyle(OneSetColors.textSecondary)
              .frame(maxWidth: .infinity, minHeight: 52)
              .contentShape(Rectangle())
              .accessibilityIdentifier("trial.continueWithoutTrial")
          }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
        .frame(maxWidth: .infinity)
        .background(OneSetColors.background)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(OneSetColors.background)
    }
  }

  private var programCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Selected program")
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textSecondary)

      Text(program.name)
        .font(OneSetTypography.h2)
        .foregroundStyle(OneSetColors.textPrimary)
        .fixedSize(horizontal: false, vertical: true)

      Text("\(program.trainingDaysPerWeek) days per week · \(program.workoutCountLabel)")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(OneSetColors.border, lineWidth: 1)
    }
  }

  @ViewBuilder private var statusNotice: some View {
    switch status {
    case .checking:
      PaywallNotice(icon: .spinner, title: "Checking subscription access", message: nil,
                    identifier: "trial.status")
    case .offer:
      EmptyView()
    case .unconfirmed:
      PaywallNotice(icon: .symbol("exclamationmark.triangle"), title: "Couldn’t check access",
                    message: "Connect to the internet and try again.", identifier: "trial.status")
    case .pendingApproval:
      PaywallNotice(icon: .symbol("clock"), title: "Waiting for purchase approval",
                    message: "You can check again after Apple approves the purchase.", identifier: "trial.status")
    case .saving:
      PaywallNotice(icon: .spinner, title: "Pro verified", message: "Saving your program setup…",
                    identifier: "trial.status")
    case .saveFailed:
      PaywallNotice(icon: .symbol("exclamationmark.triangle"), title: "Couldn’t save setup",
                    message: "Your Pro access is confirmed. Try saving your setup again.", identifier: "trial.status")
    }
  }

  private var primaryAction: (title: String, identifier: String, run: () -> Void)? {
    switch status {
    case .offer: ("See plans", "trial.seePlans", onSeePlans)
    case .unconfirmed: ("Try Again", "trial.tryAgain", onRetryAccess)
    case .pendingApproval: ("Check status", "trial.checkStatus", onRetryAccess)
    case .saveFailed: ("Retry saving setup", "trial.retrySave", onRetrySave)
    case .checking, .saving: nil
    }
  }
}
