import SwiftUI

struct MockLoginScreen: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Log in")
        .font(OneSetTypography.h1)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("login.title")

      Text("This demo does not connect to an account. Your existing account and workout history are not restored here.")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      Label("Informational demo screen", systemImage: "info.circle")
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textPrimary)

      Button("Back to Welcome", action: dismiss.callAsFunction)
        .font(OneSetTypography.button)
        .foregroundStyle(Color.black)
        .frame(maxWidth: .infinity, minHeight: 52)
        .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: OneSetColors.accent)
        .accessibilityIdentifier("login.backToWelcome")

      Spacer(minLength: 0)
    }
    .frame(maxWidth: 560, alignment: .leading)
    .padding(20)
    .padding(.top, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(OneSetColors.background)
  }
}
