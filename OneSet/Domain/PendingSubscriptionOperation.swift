import Foundation

/// A payment that OneSet cannot yet call settled for one account. While it exists, checkout
/// stays unavailable for that account and the app shows "Waiting for purchase approval".
struct PendingSubscriptionOperation: Codable, Equatable, Sendable {
  enum Kind: String, Codable, Sendable {
    /// Apple is waiting for someone to approve the purchase (Ask to Buy and similar).
    case approval
    /// Apple confirmed the charge, but OneSet has not yet verified Pro.
    case unresolvedCharge
  }

  let kind: Kind
  let startedAt: Date
}
