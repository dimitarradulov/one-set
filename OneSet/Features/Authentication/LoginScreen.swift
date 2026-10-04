import SwiftUI

struct LoginScreen: View {
  @Bindable var model: AuthenticationModel
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?

  private enum Field {
    case email
    case code
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if let user = model.signedInUser {
        signedInContent(user)
      } else {
        Button("Back to Welcome", action: dismiss.callAsFunction)
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textPrimary)
          .accessibilityIdentifier("login.backToWelcome")

        signInContent
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: 560, alignment: .leading)
    .padding(20)
    .padding(.top, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(OneSetColors.background)
    .animation(.easeInOut(duration: 0.2), value: model.signedInUser)
  }

  @ViewBuilder
  private var signInContent: some View {
    Text("Log in")
      .font(OneSetTypography.h1)
      .foregroundStyle(OneSetColors.textPrimary)
      .accessibilityAddTraits(.isHeader)
      .accessibilityIdentifier("login.title")

    if model.step == .email {
      Text("Enter your email and we’ll send you a verification code.")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      TextField("Email address", text: $model.emailAddress)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: .email)
        .padding(16)
        .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("login.email")

      actionButton("Send code", identifier: "login.sendCode") {
        await model.sendCode()
      }
    } else {
      Text("Enter the code sent to \(model.emailAddress).")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      TextField("Verification code", text: $model.verificationCode)
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .focused($focusedField, equals: .code)
        .padding(16)
        .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("login.code")

      actionButton("Verify code", identifier: "login.verifyCode") {
        await model.verifyCode()
      }

      HStack(spacing: 20) {
        Button("Use another email", action: model.changeEmail)
          .accessibilityIdentifier("login.changeEmail")
        Button("Resend code") {
          Task { await model.resendCode() }
        }
        .disabled(model.isWorking)
        .accessibilityIdentifier("login.resendCode")
      }
      .font(OneSetTypography.label)
      .foregroundStyle(OneSetColors.textPrimary)
    }

    if model.isWorking {
      ProgressView()
        .tint(OneSetColors.accent)
        .accessibilityIdentifier("login.progress")
    }

    errorMessageView
  }

  @ViewBuilder
  private var errorMessageView: some View {
    if let errorMessage = model.errorMessage {
      Text(errorMessage)
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.accent)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("login.error")
        .accessibilityAddTraits(.updatesFrequently)
    }
  }

  private func signedInContent(_ user: AuthenticatedUser) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("You’re signed in")
        .font(OneSetTypography.h1)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("login.signedInTitle")

      Text(user.emailAddress ?? user.id)
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityIdentifier("login.account")

      actionButton("Sign out", identifier: "login.signOut") {
        await model.signOut()
      }

      errorMessageView
    }
  }

  private func actionButton(
    _ title: String,
    identifier: String,
    action: @escaping () async -> Void
  ) -> some View {
    Button {
      Task { await action() }
    } label: {
      Text(title)
        .font(OneSetTypography.button)
        .foregroundStyle(Color.black)
        .frame(maxWidth: .infinity, minHeight: 52)
        .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: OneSetColors.accent)
    }
    .disabled(model.isWorking)
    .accessibilityIdentifier(identifier)
  }
}
