import Foundation

@MainActor
protocol AuthenticationService {
  var signedInUser: AuthenticatedUser? { get }
  func sendEmailCode(to emailAddress: String) async throws
  func verifyEmailCode(_ code: String) async throws
  func signOut() async throws
}
