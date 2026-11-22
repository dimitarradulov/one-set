import Foundation

/// Outcome of reading the RevenueCat public API key from the app's build configuration.
enum RevenueCatAPIKeyConfiguration: Equatable {
  case configured(apiKey: String)
  /// The key is missing, empty, unexpanded, or still a build placeholder.
  case unconfigured
}

extension AppLaunchConfiguration {
  static let revenueCatAPIKeyInfoKey = "RevenueCatAPIKey"

  /// Reads the RevenueCat public API key without failing. Later tickets treat `.unconfigured`
  /// as "access can't be confirmed".
  static func revenueCatAPIKey(
    infoDictionary: [String: Any]? = Bundle.main.infoDictionary
  ) -> RevenueCatAPIKeyConfiguration {
    guard let value = infoDictionary?[revenueCatAPIKeyInfoKey] as? String else { return .unconfigured }
    let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !key.contains("$("), !key.uppercased().contains("PLACEHOLDER") else {
      return .unconfigured
    }
    return .configured(apiKey: key)
  }
}

#if DEBUG
/// Opens Settings > Subscription with fakes in a fixed state. The restore states run Restore
/// Purchases on launch with a fake outcome.
struct SubscriptionSettingsRoute: Equatable {
  let preset: SubscriptionAccessPreset
  let restore: SubscriptionRestorePreset?
  let restoresOnLaunch: Bool

  static let routes: [String: SubscriptionSettingsRoute] = [
    "--ui-settings-subscription": .init(preset: .active, restore: nil, restoresOnLaunch: false),
    "--ui-settings-subscription-inactive": .init(preset: .inactive, restore: nil, restoresOnLaunch: false),
    "--ui-settings-subscription-checking": .init(preset: .checking, restore: nil, restoresOnLaunch: false),
    "--ui-settings-subscription-failed": .init(preset: .failed, restore: nil, restoresOnLaunch: false),
    "--ui-settings-subscription-pending": .init(preset: .pending, restore: nil, restoresOnLaunch: false),
    "--ui-settings-subscription-restoring": .init(preset: .inactive, restore: .slow, restoresOnLaunch: true),
    "--ui-settings-subscription-restored": .init(preset: .inactive, restore: .restored, restoresOnLaunch: true),
    "--ui-settings-subscription-no-purchase": .init(preset: .inactive, restore: .noPurchase, restoresOnLaunch: true),
    "--ui-settings-subscription-mismatch": .init(preset: .inactive, restore: .mismatch, restoresOnLaunch: true),
    "--ui-settings-subscription-restore-failed": .init(preset: .inactive, restore: .failed, restoresOnLaunch: true)
  ]
}

extension AppLaunchConfiguration {
  static func subscriptionSettingsRoute(arguments: [String]) -> SubscriptionSettingsRoute? {
    arguments.lazy.compactMap { SubscriptionSettingsRoute.routes[$0] }.first
  }
}
#endif
