#if DEBUG
import Foundation

@MainActor
final class PreviewOnboardingProgressStore: OnboardingProgressStore {
  private let completionOnly: Bool
  private let store: FileOnboardingProgressStore

  init(store: FileOnboardingProgressStore, completionOnly: Bool = false) {
    self.store = store
    self.completionOnly = completionOnly
  }

  func load(accountID: String) throws -> OnboardingProgress? {
    try store.load(accountID: accountID)
  }

  func save(_ progress: OnboardingProgress, accountID: String) throws {
    if completionOnly ? progress.completed != nil : progress.nextStep != .preferences {
      throw CocoaError(.fileWriteOutOfSpace)
    }
    try store.save(progress, accountID: accountID)
  }

  func remove(accountID: String) throws {
    try store.remove(accountID: accountID)
  }
}
#endif
