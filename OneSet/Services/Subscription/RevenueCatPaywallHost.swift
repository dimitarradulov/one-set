import RevenueCat
import RevenueCatUI
import SwiftUI

/// Live host: requests the named `default` offering and shows RevenueCatUI's `PaywallView`.
@MainActor
final class RevenueCatPaywallHost: PaywallHost {
  private var offering: Offering?

  func loadOffering() async throws(PaywallOfferingError) -> PaywallOffering {
    guard Purchases.isConfigured else { throw .loadFailed }
    let offerings: Offerings
    do {
      offerings = try await Purchases.shared.offerings()
    } catch {
      throw .loadFailed
    }
    guard let named = offerings.offering(identifier: PaywallCatalog.offeringID) else {
      throw .missingOffering
    }
    offering = named
    return PaywallOffering(
      identifier: named.identifier,
      packageIDs: Set(named.availablePackages.map(\.identifier))
    )
  }

  func makePaywall(for offering: PaywallOffering, events: PaywallEvents) -> AnyView {
    guard let loaded = self.offering, loaded.identifier == offering.identifier else {
      return AnyView(EmptyView())
    }
    return AnyView(
      PaywallView(offering: loaded, displayCloseButton: false)
        .onPurchaseInitiated { package, resume in
          Task { @MainActor in
            let proceed = await events.purchaseInitiated(SubscriptionPackage(id: package.identifier))
            resume(shouldProceed: proceed)
          }
        }
        .onRestoreInitiated { resume in
          Task { @MainActor in
            resume(shouldProceed: await events.restoreInitiated())
          }
        }
        .onPurchaseCompleted { (_: CustomerInfo) in events.purchaseCompleted() }
        .onPurchaseCancelled { events.purchaseCancelled() }
        .onRestoreCompleted { _ in events.restoreCompleted() }
        .onPurchaseFailure { Self.report($0, to: events) }
        .onRestoreFailure { Self.report($0, to: events) }
        .onRequestedDismissal { events.dismissRequested() }
    )
  }

  private static func report(_ error: NSError, to events: PaywallEvents) {
    switch ErrorCode(rawValue: error.code) {
    case .paymentPendingError: events.purchasePending()
    case .purchaseCancelledError: events.purchaseCancelled()
    case .receiptAlreadyInUseError, .receiptInUseByOtherSubscriberError:
      events.failed(.linkedToAnotherAccount)
    default: events.failed(.other)
    }
  }
}
