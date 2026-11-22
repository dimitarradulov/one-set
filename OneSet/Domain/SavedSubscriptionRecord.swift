import Foundation

/// Separates Test Store and Apple sandbox access from production access.
enum BillingEnvironment: String, Codable, Sendable {
  case sandbox
  case production
}

/// The last accepted subscription observation for one account and billing environment.
struct SavedSubscriptionRecord: Codable, Equatable, Sendable {
  enum Status: Codable, Equatable, Sendable {
    case active(expiresAt: Date)
    case inactive
  }

  let checkedAt: Date
  let status: Status
}

/// One result of checking subscription access, before it is accepted for saving.
enum SubscriptionObservation: Equatable, Sendable {
  /// The server verified an active entitlement through `expiresAt`.
  case verifiedActive(expiresAt: Date)
  /// The server verified that no entitlement is active.
  case verifiedInactive
  /// Only the device verified the result. It can never extend saved access.
  case onDeviceOnly
  /// The check failed.
  case failed
}
