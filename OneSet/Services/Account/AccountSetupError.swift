import Foundation

enum AccountSetupError: LocalizedError {
  case unavailable
  case invalidSetup
  case authenticationRequired

  var errorDescription: String? {
    switch self {
    case .unavailable: "We couldn’t load your account setup. Check your connection and try again."
    case .invalidSetup: "Your saved program is unavailable in this version of OneSet. Try again after updating the app."
    case .authenticationRequired: "Your session is unavailable. Try again or sign out and log in."
    }
  }
}
