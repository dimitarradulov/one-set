import SwiftUI

struct AccountSetupScreen: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel

  var body: some View {
    VStack(spacing: 24) {
      switch model.setupResolution {
      case .loading:
        if model.showsSetupSpinner {
          ProgressView()
            .tint(OneSetColors.textPrimary)
            .accessibilityLabel("Loading your account")
            .accessibilityIdentifier("setup.loading")
        }
      case .failed(let message):
        VStack(alignment: .leading, spacing: 20) {
          Text(message)
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityIdentifier("setup.error")
          Button("Retry") {
            Task { await model.resolveAccountSetup(using: authentication) }
          }
          .font(OneSetTypography.button)
          .foregroundStyle(.black)
          .frame(maxWidth: .infinity, minHeight: 52)
          .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: OneSetColors.accent)
          .accessibilityIdentifier("setup.retry")
          Button("Sign out") {
            Task { await model.signOut(using: authentication) }
          }
          .disabled(authentication.isWorking)
          .font(OneSetTypography.label)
          .accessibilityIdentifier("account.signOut")
          if let message = authentication.errorMessage {
            Text(message).font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.error)
          }
        }
        .frame(maxWidth: 420)
      case .idle:
        EmptyView()
      }
    }
    .foregroundStyle(OneSetColors.textPrimary)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OneSetColors.background)
  }
}
