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

  func purchase(packageID: String) async throws -> PurchaseOutcome {
    do {
      let offerings = try await Purchases.shared.offerings()
      let packages = ([offerings.current].compactMap { $0 } + offerings.all.values).flatMap(\.availablePackages)
      guard let package = packages.first(where: { $0.identifier == packageID }) else {
        throw SubscriptionOperationError.failed
      }
      let result = try await Purchases.shared.purchase(package: package)
      if result.userCancelled { throw SubscriptionOperationError.cancelled }
      return .purchased
    } catch {
      if case .pendingApproval = Self.paywallResult(for: error) { return .pendingApproval }
      throw Self.operationError(from: error)
    }
  }

  func restorePurchases() async throws {
    do {
      _ = try await Purchases.shared.restorePurchases()
    } catch {
      throw Self.operationError(from: error)
    }
  }

  /// Maps an SDK error to the owner's vocabulary.
  nonisolated static func operationError(from error: any Error) -> SubscriptionOperationError {
    if let error = error as? SubscriptionOperationError { return error }
    let nsError = error as NSError
    guard nsError.domain == ErrorCode.errorDomain, let code = ErrorCode(rawValue: nsError.code) else { return .failed }
    switch code {
    case .purchaseCancelledError: return .cancelled
    case .receiptAlreadyInUseError, .receiptInUseByOtherSubscriberError: return .linkedToAnotherAccount
    default: return .failed
    }
  }

  /// Maps an error from RevenueCatUI's purchase or restore failure callbacks.
  nonisolated static func paywallResult(for error: any Error) -> PaywallOperationResult {
    let nsError = error as NSError
    if nsError.domain == ErrorCode.errorDomain, ErrorCode(rawValue: nsError.code) == .paymentPendingError {
      return .pendingApproval
    }
    let mapped = operationError(from: error)
    return mapped == .cancelled ? .cancelled : .failed(mapped)
  }
}
