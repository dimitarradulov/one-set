import Foundation
import RevenueCat

/// The RevenueCat-backed client. Trusted Entitlements run in informational mode so each
/// result reports its verification, and only server-verified results count as authoritative.
@MainActor
struct LivePurchasesClient: PurchasesClient {
  static let entitlementID = "oneset_pro"

  /// Used when the result has no entitlement to read the environment from.
  let fallbackEnvironment: BillingEnvironment

  init(fallbackEnvironment: BillingEnvironment) {
    self.fallbackEnvironment = fallbackEnvironment
  }

  var isConfigured: Bool { Purchases.isConfigured }
  var currentAppUserID: String? { Purchases.isConfigured ? Purchases.shared.appUserID : nil }

  func configure(apiKey: String, appUserID: String) {
    Purchases.configure(
      with: Configuration.Builder(withAPIKey: apiKey)
        .with(appUserID: appUserID)
        .with(entitlementVerificationMode: .informational)
        .build()
    )
  }

  func logIn(appUserID: String) async throws {
    _ = try await Purchases.shared.logIn(appUserID)
  }

  func fetchAccessSnapshot() async throws -> CustomerAccessSnapshot {
    let info = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
    return Self.snapshot(from: info, fallbackEnvironment: fallbackEnvironment)
  }

  static func snapshot(from info: CustomerInfo, fallbackEnvironment: BillingEnvironment) -> CustomerAccessSnapshot {
    let verification: CustomerAccessSnapshot.Verification
    switch info.entitlements.verification {
    case .verified: verification = .serverVerified
    case .verifiedOnDevice: verification = .onDeviceOnly
    default: verification = .unverified
    }
    guard let entitlement = info.entitlements[entitlementID] else {
      return CustomerAccessSnapshot(
        isActive: false, expiresAt: nil, verification: verification, environment: fallbackEnvironment
      )
    }
    let environment: BillingEnvironment = entitlement.isSandbox || entitlement.store == .testStore
      ? .sandbox : .production
    return CustomerAccessSnapshot(
      isActive: entitlement.isActive, expiresAt: entitlement.expirationDate,
      verification: verification, environment: environment
    )
  }
}
