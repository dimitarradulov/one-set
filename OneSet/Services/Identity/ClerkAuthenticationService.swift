import ClerkKit
import Foundation

@MainActor
final class ClerkAuthenticationService: AuthenticationService {
  private enum PendingVerification {
    case signIn(SignIn)
    case signUp(SignUp)
  }

  private var pendingVerification: PendingVerification?

  var signedInUser: AuthenticatedUser? {
    guard let user = Clerk.shared.user else { return nil }
    return AuthenticatedUser(
      id: user.id,
      emailAddress: user.primaryEmailAddress?.emailAddress
    )
  }

  func requestSignInCode(to emailAddress: String) async throws -> EmailCodeRequestResult {
    let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      pendingVerification = .signIn(try await Clerk.shared.auth.signInWithEmailCode(emailAddress: email))
      return .codeSent
    } catch let error as ClerkAPIError where error.code == "form_identifier_not_found" {
      pendingVerification = nil
      return .accountNotFound
    }
  }

  func requestSignUpCode(to emailAddress: String) async throws {
    let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let signUp = try await Clerk.shared.auth.signUp(emailAddress: email)
    guard signUp.missingFields.isEmpty else {
      let fields = signUp.missingFields.map(\.rawValue).joined(separator: ", ")
      throw AuthenticationError.signUpNeedsAdditionalFields(fields)
    }
    pendingVerification = .signUp(try await signUp.sendEmailCode())
  }

  func resendEmailCode() async throws {
    switch pendingVerification {
    case .signIn(let signIn):
      pendingVerification = .signIn(try await signIn.sendEmailCode())
    case .signUp(let signUp):
      pendingVerification = .signUp(try await signUp.sendEmailCode())
    case nil:
      throw AuthenticationError.noCodeRequested
    }
  }

  func verifyEmailCode(_ code: String) async throws {
    guard let pendingVerification else {
      throw AuthenticationError.noCodeRequested
    }

    switch pendingVerification {
    case .signIn(let signIn):
      let result = try await signIn.verifyCode(code)
      guard result.status == .complete, let sessionID = result.createdSessionId else {
        throw AuthenticationError.incompleteSignIn
      }
      try await Clerk.shared.auth.setActive(sessionId: sessionID)
    case .signUp(let signUp):
      let result = try await signUp.verifyEmailCode(code)
      guard result.status == .complete, let sessionID = result.createdSessionId else {
        throw AuthenticationError.incompleteSignUp
      }
      try await Clerk.shared.auth.setActive(sessionId: sessionID)
    }

    self.pendingVerification = nil
  }

  func cancelPendingEmailFlow() {
    pendingVerification = nil
  }

  func sessionToken(for user: AuthenticatedUser) async throws -> String {
    guard signedInUser?.id == user.id, let session = Clerk.shared.session,
          let token = try await session.getToken(), signedInUser?.id == user.id else {
      throw AccountSetupError.authenticationRequired
    }
    return token
  }

  func signOut() async throws {
    try await Clerk.shared.auth.signOut()
    pendingVerification = nil
  }
}
