import Foundation

/// What the owner needs from one `CustomerInfo` for the `oneset_pro` entitlement.
struct CustomerAccessSnapshot: Equatable, Sendable {
  enum Verification: Equatable, Sendable {
    /// RevenueCat's server signed the result. The only authoritative kind.
    case serverVerified
    /// Verified on device only. Never extends saved access.
    case onDeviceOnly
    /// Verification was off or failed.
    case unverified
  }

  let isActive: Bool
  /// Nil for an active entitlement with no expiry.
  let expiresAt: Date?
  let verification: Verification
  let environment: BillingEnvironment
}

/// Seam around the RevenueCat SDK so the owner can be tested without it.
@MainActor
protocol PurchasesClient {
  var isConfigured: Bool { get }
  /// The SDK's current App User ID, or nil before configuration.
  var currentAppUserID: String? { get }
  func configure(apiKey: String, appUserID: String)
  /// Identified login. Throws when the SDK cannot switch accounts.
  func logIn(appUserID: String) async throws
  /// Fetches current customer info from the server and maps `oneset_pro`.
  func fetchAccessSnapshot() async throws -> CustomerAccessSnapshot
}
