import StoreKit
import SwiftUI

/// Opens Apple's Manage Subscriptions sheet, or the App Store subscriptions page when the sheet
/// cannot be shown. Settings and the paywall share it so Manage Subscription behaves the same.
@MainActor
enum ManageSubscriptions {
  static func open(fallback openURL: OpenURLAction) async {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    if let scene {
      do {
        try await AppStore.showManageSubscriptions(in: scene)
        return
      } catch {}
    }
    if let url = PaywallModel.manageSubscriptionURL { openURL(url) }
  }
}
