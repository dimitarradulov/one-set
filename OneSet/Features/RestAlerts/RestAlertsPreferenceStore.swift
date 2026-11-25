import Foundation

/// Stores the device-local rest alerts choice. `nil` means the lifter has not chosen yet.
@MainActor
protocol RestAlertsPreferenceStore: AnyObject {
  var isEnabled: Bool? { get set }
}

final class UserDefaultsRestAlertsPreferenceStore: RestAlertsPreferenceStore {
  private static let key = "restAlerts.enabled"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var isEnabled: Bool? {
    get { defaults.object(forKey: Self.key) as? Bool }
    set {
      if let newValue { defaults.set(newValue, forKey: Self.key) } else { defaults.removeObject(forKey: Self.key) }
    }
  }
}

final class InMemoryRestAlertsPreferenceStore: RestAlertsPreferenceStore {
  var isEnabled: Bool?
  init(isEnabled: Bool? = nil) { self.isEnabled = isEnabled }
}
