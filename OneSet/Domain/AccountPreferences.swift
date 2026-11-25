import Foundation

/// The preferred unit and training frequency stored on the account. Latest saved values win.
struct AccountPreferences: Codable, Sendable, Equatable {
  let preferredUnit: WeightUnit
  let trainingDays: Int

  enum CodingKeys: String, CodingKey {
    case preferredUnit = "preferred_unit"
    case trainingDays = "training_days"
  }
}

/// A preference change recorded on this device for an account whose setup was already acknowledged.
/// Only the latest values are kept, and a newer change replaces an unsent older one.
struct PendingPreferenceUpdate: Codable, Sendable, Equatable {
  var preferences: AccountPreferences
  /// Identifies this change so a late response cannot clear a newer one with the same values.
  var sequence: Int
  /// Set when the server answered `400`. The local value is kept and this change is not retried.
  var rejected: Bool = false

  /// Whether this change still waits to reach the account.
  var isUnsent: Bool { !rejected }
}
