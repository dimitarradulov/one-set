import Foundation
import Observation

@MainActor
@Observable
final class PreviewAuthenticationService: AuthenticationService {
  private static let persistedUserIDKey = "oneset.preview-auth.user-id"
  private static let persistedEmailAddressKey = "oneset.preview-auth.email-address"

  private enum PendingFlow {
    case signIn
    case signUp
  }

  private(set) var signedInUser: AuthenticatedUser?

  private let emailIsRegistered: Bool
  private let persistsSession: Bool
  private var pendingFlow: PendingFlow?
  private var pendingEmailAddress: String?

  init(
    emailIsRegistered: Bool = false,
    startsSignedIn: Bool = false,
    persistsSession: Bool = false,
    resetPersistedSession: Bool = false
  ) {
    self.emailIsRegistered = emailIsRegistered || startsSignedIn
    self.persistsSession = persistsSession
    if resetPersistedSession {
      Self.clearPersistedSession()
    }
    if startsSignedIn {
      signedInUser = AuthenticatedUser(id: "preview-user", emailAddress: "restored@example.com")
    } else if persistsSession,
              let userID = UserDefaults.standard.string(forKey: Self.persistedUserIDKey),
              let emailAddress = UserDefaults.standard.string(forKey: Self.persistedEmailAddressKey) {
      signedInUser = AuthenticatedUser(id: userID, emailAddress: emailAddress)
    }
  }

  func requestSignInCode(to emailAddress: String) async throws -> EmailCodeRequestResult {
    guard emailIsRegistered else { return .accountNotFound }
    pendingEmailAddress = emailAddress
    pendingFlow = .signIn
    return .codeSent
  }

  func requestSignUpCode(to emailAddress: String) async throws {
    pendingEmailAddress = emailAddress
    pendingFlow = .signUp
  }

  func resendEmailCode() async throws {
    guard pendingFlow != nil else { throw AuthenticationError.noCodeRequested }
  }

  func verifyEmailCode(_ code: String) async throws {
    guard pendingFlow != nil, let pendingEmailAddress else {
      throw AuthenticationError.noCodeRequested
    }
    guard code == "123456" else { throw AuthenticationError.invalidVerificationCode }
    let user = AuthenticatedUser(id: "preview-user", emailAddress: pendingEmailAddress)
    signedInUser = user
    if persistsSession {
      UserDefaults.standard.set(user.id, forKey: Self.persistedUserIDKey)
      if let emailAddress = user.emailAddress {
        UserDefaults.standard.set(emailAddress, forKey: Self.persistedEmailAddressKey)
      }
    }
    pendingFlow = nil
  }

  func cancelPendingEmailFlow() {
    pendingFlow = nil
    pendingEmailAddress = nil
  }

  func signOut() async throws {
    signedInUser = nil
    cancelPendingEmailFlow()
    if persistsSession {
      Self.clearPersistedSession()
    }
  }

  private static func clearPersistedSession() {
    UserDefaults.standard.removeObject(forKey: persistedUserIDKey)
    UserDefaults.standard.removeObject(forKey: persistedEmailAddressKey)
  }
}
