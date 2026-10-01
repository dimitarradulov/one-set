import SwiftUI

struct WelcomeScreen: View {
  let onContinue: () -> Void
  let onLogIn: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Image("WelcomeGym")
          .resizable()
          .scaledToFill()
          .frame(
            width: geometry.size.width,
            height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
          )
          .clipped()
          .overlay {
            LinearGradient(
              stops: [
                .init(color: .black.opacity(0.18), location: 0),
                .init(color: .clear, location: 0.32),
                .init(color: .black.opacity(0.30), location: 0.53),
                .init(color: .black.opacity(0.94), location: 1)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          }
          .offset(y: -geometry.safeAreaInsets.top)
          .accessibilityHidden(true)

        ScrollView {
          VStack(spacing: 0) {
            OneSetBrandMark()
              .padding(.top, 22)

            Spacer(minLength: 20)

            VStack(spacing: 20) {
              Text("Guided HIT programs.\nReal progress.")
                .font(OneSetTypography.h2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

              VStack(spacing: 10) {
                DemoAccountButton(
                  title: "Continue with Apple",
                  systemImage: "apple.logo",
                  identifier: "continue.apple",
                  prominent: true,
                  action: onContinue
                )
                DemoAccountButton(
                  title: "Continue with Google",
                  systemImage: "g.circle.fill",
                  identifier: "continue.google",
                  prominent: false,
                  action: onContinue
                )
                DemoAccountButton(
                  title: "Continue with email",
                  systemImage: "envelope",
                  identifier: "continue.email",
                  prominent: false,
                  action: onContinue
                )
              }

              HStack(spacing: 5) {
                Text("Already have an account?")
                  .foregroundStyle(.white.opacity(0.85))
                Button("Log in", action: onLogIn)
                  .font(OneSetTypography.label)
                  .foregroundStyle(OneSetColors.accent)
                  .underline()
                  .frame(minWidth: 44, minHeight: 44)
                  .accessibilityIdentifier("welcome.login")
              }
              .font(OneSetTypography.caption)

              Text("Demo only · no account is created")
                .font(OneSetTypography.caption)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityIdentifier("welcome.demoNotice")
            }
          }
          .frame(maxWidth: 500, minHeight: geometry.size.height)
          .padding(.horizontal, 20)
          .padding(.bottom, 12)
          .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(OneSetColors.background)
    }
    .background(OneSetColors.background)
  }
}
