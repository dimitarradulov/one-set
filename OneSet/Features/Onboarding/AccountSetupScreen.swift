import SwiftUI

struct AccountSetupScreen: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("Your account setup")
        .font(OneSetTypography.h1)
        .accessibilityAddTraits(.isHeader)

      switch model.setupResolution {
      case .loading:
        ProgressView("Loading your program…")
          .tint(OneSetColors.accent)
          .accessibilityIdentifier("setup.loading")
      case .failed(let message):
        Text(message)
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityIdentifier("setup.error")
        Button("Retry") {
          Task { await model.resolveAccountSetup(using: authentication) }
        }
        .font(OneSetTypography.button)
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 52)
        .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: OneSetColors.accent)
        .accessibilityIdentifier("setup.retry")
      case .idle:
        EmptyView()
      }

      Button("Sign out") {
        Task {
          await model.signOut(using: authentication)
        }
      }
      .disabled(authentication.isWorking)
      .font(OneSetTypography.label)
      .accessibilityIdentifier("account.signOut")
      if let message = authentication.errorMessage {
        Text(message).font(OneSetTypography.label)
      }
      Spacer()
    }
    .foregroundStyle(OneSetColors.textPrimary)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(OneSetColors.background)
  }
}
