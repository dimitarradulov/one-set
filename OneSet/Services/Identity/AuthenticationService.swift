import Foundation

@MainActor
protocol AuthenticationService {
  var signedInUser: AuthenticatedUser? { get }
  func signInWithGoogle() async throws
  func signInWithApple() async throws
  func requestSignInCode(to emailAddress: String) async throws -> EmailCodeRequestResult
  func requestSignUpCode(to emailAddress: String) async throws
  func resendEmailCode() async throws
  func verifyEmailCode(_ code: String) async throws
  func cancelPendingEmailFlow()
  func signOut() async throws
}
