import Foundation

enum AccountSetupError: LocalizedError {
  case unavailable
  case invalidSetup
  case authenticationRequired
  case programUnavailable
  case invalidPreferences

  var errorDescription: String? {
    switch self {
    case .unavailable: "We couldn’t load your account setup. Check your connection and try again."
    case .invalidSetup: "Your saved program is unavailable in this version of OneSet. Try again after updating the app."
    case .authenticationRequired: "Your session is unavailable. Try again or sign out and log in."
    case .programUnavailable: "That program is no longer available. Choose an available program to finish setup."
    case .invalidPreferences: "Your account didn’t accept the unit and training frequency change."
    }
  }
}
