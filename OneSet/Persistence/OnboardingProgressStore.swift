import Foundation

@MainActor
protocol OnboardingProgressStore {
  func load(accountID: String) throws -> UnfinishedOnboarding?
  func save(_ progress: UnfinishedOnboarding, accountID: String) throws
  func remove(accountID: String) throws
}
