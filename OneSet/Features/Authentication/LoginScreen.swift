import SwiftUI

struct LoginScreen: View {
  @Bindable var model: AuthenticationModel
  var onContinueAfterAuthentication: (() -> Void)?

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
        Button("Back to Welcome") {
          model.cancel()
          dismiss()
        }
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityIdentifier("login.backToWelcome")

        Text(model.entryPoint.title)
          .font(OneSetTypography.h1)
          .foregroundStyle(OneSetColors.textPrimary)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("login.title")

        switch model.step {
        case .email:
          emailEntry
        case .accountCreationOffer:
          accountCreationOffer
        case .code:
          codeEntry
        }

        if model.isWorking {
          ProgressView()
            .tint(OneSetColors.accent)
            .accessibilityIdentifier("login.progress")
        }

        errorMessageView
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

  private var emailEntry: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(model.entryPoint == .continueWithEmail
        ? "Enter your email and we’ll send a verification code."
        : "Enter your email and we’ll send a code to log in.")
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
    }
  }

  private var accountCreationOffer: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("No account was found for \(model.emailAddress). Would you like to create one?")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("login.accountNotFound")

      actionButton("Create an account", identifier: "login.createAccount") {
        await model.createAccount()
      }

      Button("Use another email", action: model.changeEmail)
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityIdentifier("login.changeEmail")
    }
  }

  private var codeEntry: some View {
    VStack(alignment: .leading, spacing: 20) {
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
        await verifyCode()
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
  }

  @ViewBuilder
  private var errorMessageView: some View {
    if let errorMessage = model.errorMessage {
      Text(errorMessage)
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.error)
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

      if let onContinueAfterAuthentication {
        actionButton("Continue", identifier: "login.continue") {
          onContinueAfterAuthentication()
        }
      }

      actionButton("Sign out", identifier: "login.signOut") {
        await model.signOut()
      }

      errorMessageView
    }
  }

  private func verifyCode() async {
    await model.verifyCode()
    guard model.didCompleteAuthentication else { return }
    onContinueAfterAuthentication?()
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
