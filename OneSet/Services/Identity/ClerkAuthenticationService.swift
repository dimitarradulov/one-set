import ClerkKit
import Foundation

@MainActor
final class ClerkAuthenticationService: AuthenticationService {
  private var pendingSignIn: SignIn?

  var signedInUser: AuthenticatedUser? {
    guard let user = Clerk.shared.user else { return nil }
    return AuthenticatedUser(
      id: user.id,
      emailAddress: user.primaryEmailAddress?.emailAddress
    )
  }

  func sendEmailCode(to emailAddress: String) async throws {
    pendingSignIn = try await Clerk.shared.auth.signInWithEmailCode(
      emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  func verifyEmailCode(_ code: String) async throws {
    guard let pendingSignIn else {
      throw AuthenticationError.noCodeRequested
    }

    let result = try await pendingSignIn.verifyCode(code)
    guard result.status == .complete, let sessionID = result.createdSessionId else {
      throw AuthenticationError.incompleteSignIn
    }

    try await Clerk.shared.auth.setActive(sessionId: sessionID)
    self.pendingSignIn = nil
  }

  func signOut() async throws {
    try await Clerk.shared.auth.signOut()
    pendingSignIn = nil
  }
}
