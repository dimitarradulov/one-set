import Foundation

/// Durable storage for the last verified subscription record per account and billing environment.
@MainActor
protocol SavedSubscriptionAccessStore {
  func load(accountID: String, environment: BillingEnvironment) throws -> SavedSubscriptionRecord?
  func save(_ record: SavedSubscriptionRecord, accountID: String, environment: BillingEnvironment) throws
  /// Removes every environment's record for the account.
  func removeAll(accountID: String) throws
}
