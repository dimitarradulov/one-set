import Foundation

enum AuthenticationError: LocalizedError {
  case incompleteGoogleAuthentication
  case incompleteAppleAuthentication
  case noCodeRequested
  case incompleteSignIn
  case incompleteSignUp
  case emailRequired
  case signUpNeedsAdditionalFields(String)
  case invalidVerificationCode

  var errorDescription: String? {
    switch self {
    case .incompleteGoogleAuthentication:
      "Google authentication could not be completed. Please try again."
    case .incompleteAppleAuthentication:
      "Apple authentication could not be completed. Please try again."
    case .noCodeRequested:
      "Request a verification code before entering it."
    case .incompleteSignIn:
      "The code was accepted, but Clerk did not complete the sign-in. Try again."
    case .incompleteSignUp:
      "The code was accepted, but Clerk did not complete account creation. Try again."
    case .emailRequired:
      "Enter your email address."
    case .signUpNeedsAdditionalFields(let fields):
      "Clerk requires additional sign-up information (\(fields)). Update the development sign-up settings and try again."
    case .invalidVerificationCode:
      "That code is invalid or has expired. Check it or request a new code."
    }
  }
}
