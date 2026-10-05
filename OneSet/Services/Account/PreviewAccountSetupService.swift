#if DEBUG
import Foundation

@MainActor
final class PreviewAccountSetupService: AccountSetupService {
  private let completed: Bool
  private let delayed: Bool
  private let invalidProgram: Bool
  private var shouldFail: Bool
  private let alwaysFails: Bool

  init(arguments: [String] = []) {
    completed = arguments.contains("--ui-setup-completed")
    delayed = arguments.contains("--ui-setup-delayed")
    invalidProgram = arguments.contains("--ui-setup-invalid-program")
    shouldFail = arguments.contains("--ui-setup-retry") || arguments.contains("--ui-account-setup-error")
    alwaysFails = arguments.contains("--ui-account-setup-error")
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    if delayed {
      // Intentionally ignore cancellation to exercise late responses from adapters.
      await Task { try? await Task.sleep(for: .seconds(8)) }.value
    }
    if shouldFail {
      shouldFail = alwaysFails
      throw AccountSetupError.unavailable
    }
    guard completed, user.emailAddress != "other@example.com" else { return nil }
    return AccountSetup(
      preferredUnit: .pounds, trainingDays: 5,
      programID: invalidProgram ? "unavailable" : "machine-full-body",
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
  }
}
#endif
