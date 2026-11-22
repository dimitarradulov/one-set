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
