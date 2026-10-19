#if DEBUG
import Foundation

@MainActor
final class PreviewAccountSetupService: AccountSetupService {
  private var uploadFailsOnce: Bool
  private let uploadDelayed: Bool
  private let uploadOffline: Bool
  private let backendURL: URL?
  private let completed: Bool
  private let delayed: Bool
  private let invalidProgram: Bool
  private let removedProgramUpload: Bool
  private var shouldFail: Bool
  private let alwaysFails: Bool

  init(arguments: [String] = []) {
    uploadFailsOnce = arguments.contains("--ui-upload-retry")
    uploadDelayed = arguments.contains("--ui-upload-delayed")
    uploadOffline = arguments.contains("--ui-setup-upload-pending") || arguments.contains("--ui-setup-upload-discard")
      || arguments.contains("--ui-upload-offline") || arguments.contains("--ui-setup-offline")
    backendURL = arguments.contains("--ui-shared-backend")
      ? URL.applicationSupportDirectory.appending(path: "preview-backend.json") : nil
    if arguments.contains("--ui-backend-reset"), let backendURL {
      try? FileManager.default.removeItem(at: backendURL)
    }
    completed = arguments.contains("--ui-setup-completed") || arguments.contains("--ui-setup-removed-follower")
      || arguments.contains("--ui-main-tabs") || arguments.contains("--ui-main-history")
      || arguments.contains("--ui-main-settings") || arguments.contains("--ui-main-workout-preview")
      || arguments.contains("--ui-main-exercise-detail")
    delayed = arguments.contains("--ui-setup-delayed")
    invalidProgram = arguments.contains("--ui-setup-invalid-program")
    removedProgramUpload = arguments.contains("--ui-setup-upload-removed")
    shouldFail = arguments.contains("--ui-setup-retry") || (arguments.contains("--ui-account-setup-error") || arguments.contains("--ui-setup-offline"))
    alwaysFails = (arguments.contains("--ui-account-setup-error") || arguments.contains("--ui-setup-offline"))
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
    if let backendURL, let data = try? Data(contentsOf: backendURL) {
      let accounts = try JSONDecoder().decode([String: AccountSetup].self, from: data)
      if let setup = accounts[user.id] { return setup }
    }
    guard completed, user.emailAddress != "other@example.com" else { return nil }
    return AccountSetup(
      preferredUnit: .pounds, trainingDays: 5,
      programID: invalidProgram ? "unavailable" : "machine-full-body",
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
  }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    if uploadDelayed {
      await Task { try? await Task.sleep(for: .seconds(8)) }.value
    }
    if uploadFailsOnce {
      uploadFailsOnce = false
      throw AccountSetupError.unavailable
    }
    if removedProgramUpload { throw AccountSetupError.programUnavailable }
    guard !uploadOffline else { throw AccountSetupError.unavailable }
    guard let backendURL else { return setup }
    var accounts = (try? Data(contentsOf: backendURL)).flatMap {
      try? JSONDecoder().decode([String: AccountSetup].self, from: $0)
    } ?? [:]
    if let established = accounts[user.id] { return established }
    accounts[user.id] = setup
    try JSONEncoder().encode(accounts).write(to: backendURL, options: .atomic)
    return setup
  }

}
#endif
