@MainActor
struct PreviewAuthenticationService: AuthenticationService {
  var signedInUser: AuthenticatedUser? { nil }
  func sendEmailCode(to emailAddress: String) async throws {}
  func verifyEmailCode(_ code: String) async throws {}
  func signOut() async throws {}
}
