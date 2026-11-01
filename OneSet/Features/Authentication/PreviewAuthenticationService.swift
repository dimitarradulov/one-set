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
  private let defaults: UserDefaults
  private let persistsSession: Bool
  private let signOutFails: Bool
  private let googleIncomplete: Bool
  private var googleFails: Bool
  private let googleCancels: Bool
  private let appleCancels: Bool
  private var appleFails: Bool
  private var pendingFlow: PendingFlow?
  private var pendingEmailAddress: String?

  init(
    defaults: UserDefaults = .standard,
    emailIsRegistered: Bool = false,
    startsSignedIn: Bool = false,
    persistsSession: Bool = false,
    resetPersistedSession: Bool = false,
    signOutFails: Bool = false,
    googleIncomplete: Bool = false,
    googleFails: Bool = false,
    googleCancels: Bool = false,
    appleCancels: Bool = false,
    appleFails: Bool = false
  ) {
    self.defaults = defaults
    self.emailIsRegistered = emailIsRegistered || startsSignedIn
    self.persistsSession = persistsSession
    self.signOutFails = signOutFails
    self.googleIncomplete = googleIncomplete
    self.googleFails = googleFails
    self.googleCancels = googleCancels
    self.appleCancels = appleCancels
    self.appleFails = appleFails
    if resetPersistedSession {
      clearPersistedSession()
    }
    if startsSignedIn {
      signedInUser = AuthenticatedUser(id: "preview-user", emailAddress: "restored@example.com")
    } else if persistsSession,
              let userID = defaults.string(forKey: Self.persistedUserIDKey),
              let emailAddress = defaults.string(forKey: Self.persistedEmailAddressKey) {
      signedInUser = AuthenticatedUser(id: userID, emailAddress: emailAddress)
    }
  }

  func signInWithApple() async throws {
    if appleCancels { throw CancellationError() }
    if appleFails {
      appleFails = false
      throw AuthenticationError.incompleteAppleAuthentication
    }
    completeAuthentication(as: AuthenticatedUser(id: "preview-apple", emailAddress: "apple@example.com"))
  }

  func signInWithGoogle() async throws {
    if googleCancels { throw CancellationError() }
    if googleFails {
      googleFails = false
      throw AuthenticationError.incompleteGoogleAuthentication
    }
    if googleIncomplete { return }
    completeAuthentication(as: AuthenticatedUser(id: "preview-google", emailAddress: "google@example.com"))
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
    completeAuthentication(as: AuthenticatedUser(
      id: "preview-\(pendingEmailAddress)", emailAddress: pendingEmailAddress
    ))
    pendingFlow = nil
  }

  func cancelPendingEmailFlow() {
    pendingFlow = nil
    pendingEmailAddress = nil
  }

  func signOut() async throws {
    if signOutFails { throw URLError(.notConnectedToInternet) }
    signedInUser = nil
    cancelPendingEmailFlow()
    if persistsSession {
      clearPersistedSession()
    }
  }

  private func completeAuthentication(as user: AuthenticatedUser) {
    signedInUser = user
    if persistsSession {
      defaults.set(user.id, forKey: Self.persistedUserIDKey)
      defaults.set(user.emailAddress, forKey: Self.persistedEmailAddressKey)
    }
  }

  private func clearPersistedSession() {
    defaults.removeObject(forKey: Self.persistedUserIDKey)
    defaults.removeObject(forKey: Self.persistedEmailAddressKey)
  }
}
