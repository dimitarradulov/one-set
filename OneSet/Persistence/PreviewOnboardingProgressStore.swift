#if DEBUG
import Foundation

@MainActor
final class PreviewOnboardingProgressStore: OnboardingProgressStore {
  private let store: FileOnboardingProgressStore

  init(store: FileOnboardingProgressStore) {
    self.store = store
  }

  func load(accountID: String) throws -> UnfinishedOnboarding? {
    try store.load(accountID: accountID)
  }

  func save(_ progress: UnfinishedOnboarding, accountID: String) throws {
    guard progress.nextStep == .preferences else { throw CocoaError(.fileWriteOutOfSpace) }
    try store.save(progress, accountID: accountID)
  }

  func remove(accountID: String) throws {
    try store.remove(accountID: accountID)
  }
}
#endif
