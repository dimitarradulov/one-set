import SwiftUI

struct WelcomeScreen: View {
  let isAuthenticating: Bool
  let authenticationError: String?
  let onContinueWithApple: () -> Void
  let onContinueWithGoogle: () -> Void
  let onContinueWithEmail: () -> Void

  #if DEBUG
  var onDevelopmentSignIn: (() -> Void)?
  #endif

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
            Image("OneSetLogo")
              .resizable()
              .scaledToFit()
              .frame(width: 140, height: 80)
              .accessibilityLabel("OneSet")
              .padding(.top, 16)

            Spacer(minLength: 20)

            VStack(spacing: 20) {
              Text("Guided HIT programs.\nReal progress.")
                .font(OneSetTypography.h2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

              VStack(spacing: 10) {
                AccountButton(
                  title: "Continue with Apple",
                  systemImage: "apple.logo",
                  identifier: "continue.apple",
                  prominent: true,
                  showsDemo: false,
                  action: onContinueWithApple
                )
                AccountButton(
                  title: "Continue with Google",
                  systemImage: "g.circle.fill",
                  identifier: "continue.google",
                  prominent: false,
                  showsDemo: false,
                  action: onContinueWithGoogle
                )
                AccountButton(
                  title: "Continue with email",
                  systemImage: "envelope",
                  identifier: "continue.email",
                  prominent: false,
                  showsDemo: false,
                  action: onContinueWithEmail
                )
                #if DEBUG
                if let onDevelopmentSignIn {
                  Button("Dev: sign in instantly", systemImage: "hammer", action: onDevelopmentSignIn)
                    .font(OneSetTypography.caption)
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                    .accessibilityHint("Uses a local test account without connecting to providers or the server")
                    .accessibilityIdentifier("continue.development")
                }
                #endif
              }
              .padding(.horizontal, 8)
              .disabled(isAuthenticating)

              if isAuthenticating {
                ProgressView("Signing in…")
                  .font(OneSetTypography.caption)
                  .accessibilityIdentifier("welcome.authProgress")
              }
              if let authenticationError {
                Text(authenticationError)
                  .font(OneSetTypography.caption)
                  .foregroundStyle(OneSetColors.error)
                  .multilineTextAlignment(.center)
                  .accessibilityIdentifier("welcome.authError")
              }
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
