import Foundation

@MainActor
protocol OnboardingProgressStore {
  func load(accountID: String) throws -> OnboardingProgress?
  func save(_ progress: OnboardingProgress, accountID: String) throws
  func remove(accountID: String) throws
}
