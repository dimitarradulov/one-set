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
  case temporary(retryAfter: Date?)

  static func httpFailure(status: Int, retryAfter: String?, at date: Date) -> Self? {
    return switch status {
    case 401: .authenticationRequired
    case 403: .forbidden
    case 409: .conflict
    case 400, 422: .invalidSession
    case 408, 425, 429, 500...599:
      .temporary(retryAfter: CompletedSessionUploadRetryPolicy.serverRetryDate(
        headerValue: retryAfter, at: date
      ))
    default: nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .authenticationRequired: "Sign in to the account that recorded this workout."
    case .forbidden: "This account can’t save the recorded workout."
    case .conflict: "This workout conflicts with a saved server record."
    case .invalidSession: "This workout contains data the server can’t save."
    case .temporary: "The workout could not be uploaded yet."
    }
  }
}
