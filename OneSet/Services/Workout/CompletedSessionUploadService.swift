import Foundation

@MainActor
protocol CompletedSessionUploadService {
  func upload(_ pending: PendingSessionUpload, for user: AuthenticatedUser) async throws
}

enum CompletedSessionUploadError: Error, LocalizedError {
  case authenticationRequired
  case forbidden
  case conflict
  case invalidSession

  var errorDescription: String? {
    switch self {
    case .authenticationRequired: "Sign in to the account that recorded this workout."
    case .forbidden: "This account can’t save the recorded workout."
    case .conflict: "This workout conflicts with a saved server record."
    case .invalidSession: "This workout contains data the server can’t save."
    }
  }
}
