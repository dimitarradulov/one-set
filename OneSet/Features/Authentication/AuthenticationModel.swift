import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationModel {
  enum EntryPoint: Equatable {
    case continueWithEmail
    case logIn

    var title: String {
      switch self {
      case .continueWithEmail: "Continue with email"
      case .logIn: "Log in"
      }
    }
  }

  enum Step: Equatable {
    case email
    case accountCreationOffer
    case code
  }

  var emailAddress = ""
  var verificationCode = ""
  private(set) var entryPoint: EntryPoint
  private(set) var step: Step = .email
  private(set) var isWorking = false
  private(set) var errorMessage: String?
  private(set) var didCompleteAuthentication = false

  private let service: any AuthenticationService
  private var hasPendingCode = false

  var signedInUser: AuthenticatedUser? { service.signedInUser }

  init(service: any AuthenticationService, entryPoint: EntryPoint = .logIn) {
    self.service = service
    self.entryPoint = entryPoint
  }

  func signInWithApple() async {
    await authenticate(incompleteError: .incompleteAppleAuthentication) {
      try await service.signInWithApple()
    }
  }

  func signInWithGoogle() async {
    await authenticate(incompleteError: .incompleteGoogleAuthentication) {
      try await service.signInWithGoogle()
    }
  }

  private func authenticate(
    incompleteError: AuthenticationError,
    action: () async throws -> Void
  ) async {
    guard !isWorking, signedInUser == nil else { return }
    cancel()
    isWorking = true
    defer { isWorking = false }
    do {
      try await action()
      guard signedInUser != nil else { throw incompleteError }
      didCompleteAuthentication = true
    } catch is CancellationError {
      // Dismissing a provider's sheet leaves Welcome available for another attempt.
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func begin(_ entryPoint: EntryPoint) {
    service.cancelPendingEmailFlow()
    self.entryPoint = entryPoint
    emailAddress = ""
    verificationCode = ""
    step = .email
    isWorking = false
    errorMessage = nil
    didCompleteAuthentication = false
    hasPendingCode = false
  }

  func sendCode() async {
    errorMessage = nil
    didCompleteAuthentication = false
    let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedEmail.isEmpty else {
      errorMessage = AuthenticationError.emailRequired.localizedDescription
      return
    }
    emailAddress = normalizedEmail
    isWorking = true
    defer { isWorking = false }

    do {
      switch try await service.requestSignInCode(to: normalizedEmail) {
      case .codeSent:
        hasPendingCode = true
        step = .code
      case .accountNotFound:
        hasPendingCode = false
        step = .accountCreationOffer
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func createAccount() async {
    guard step == .accountCreationOffer else { return }
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.requestSignUpCode(to: emailAddress)
      hasPendingCode = true
      verificationCode = ""
      step = .code
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func verifyCode() async {
    errorMessage = nil
    guard hasPendingCode else {
      errorMessage = AuthenticationError.noCodeRequested.localizedDescription
      return
    }
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.verifyEmailCode(verificationCode)
      verificationCode = ""
      didCompleteAuthentication = true
      hasPendingCode = false
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func resendCode() async {
    guard hasPendingCode else { return }
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.resendEmailCode()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func changeEmail() {
    service.cancelPendingEmailFlow()
    step = .email
    verificationCode = ""
    hasPendingCode = false
    errorMessage = nil
    didCompleteAuthentication = false
  }

  func cancel() {
    service.cancelPendingEmailFlow()
    emailAddress = ""
    verificationCode = ""
    step = .email
    hasPendingCode = false
    errorMessage = nil
    didCompleteAuthentication = false
  }

  func signOut() async {
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.signOut()
      emailAddress = ""
      verificationCode = ""
      step = .email
      hasPendingCode = false
      didCompleteAuthentication = false
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
