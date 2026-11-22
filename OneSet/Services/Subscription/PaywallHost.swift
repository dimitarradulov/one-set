import SwiftUI

/// The named offering and package identifiers OneSet sells.
enum PaywallCatalog {
  static let offeringID = "default"
  static let monthlyPackageID = "$rc_monthly"
  static let annualPackageID = "$rc_annual"
  static let requiredPackageIDs: Set<String> = [monthlyPackageID, annualPackageID]
}

/// The offering a host loaded, reduced to what the parent screen checks.
struct PaywallOffering: Equatable, Sendable {
  let identifier: String
  let packageIDs: Set<String>

  var missingPackageIDs: Set<String> {
    PaywallCatalog.requiredPackageIDs.subtracting(packageIDs)
  }
}

enum PaywallOfferingError: Error, Equatable, Sendable {
  /// The SDK is not configured or the request failed.
  case loadFailed
  /// The named `default` offering does not exist.
  case missingOffering
}

enum PaywallFailure: Equatable, Sendable {
  case linkedToAnotherAccount
  case other
}

/// What the embedded paywall reports back to the parent screen.
struct PaywallEvents {
  /// Return `false` to stop checkout before Apple's sheet appears.
  var purchaseInitiated: @MainActor (SubscriptionPackage) async -> Bool
  var restoreInitiated: @MainActor () async -> Bool
  var purchaseCompleted: @MainActor () -> Void
  var purchaseCancelled: @MainActor () -> Void
  var purchasePending: @MainActor () -> Void
  var restoreCompleted: @MainActor () -> Void
  var failed: @MainActor (PaywallFailure) -> Void
  var dismissRequested: @MainActor () -> Void
}

/// Loads the checkout offering and builds the embedded paywall. The live host wraps
/// RevenueCatUI; previews and tests use a fake that makes no network calls.
@MainActor
protocol PaywallHost {
  func loadOffering() async throws(PaywallOfferingError) -> PaywallOffering
  func makePaywall(for offering: PaywallOffering, events: PaywallEvents) -> AnyView
}
