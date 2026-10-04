import Foundation

enum AuthenticationError: LocalizedError {
  case noCodeRequested
  case incompleteSignIn

  var errorDescription: String? {
    switch self {
    case .noCodeRequested:
      "Request a verification code before entering it."
    case .incompleteSignIn:
      "The code was accepted, but Clerk did not complete the sign-in. Try again."
    }
  }
}
