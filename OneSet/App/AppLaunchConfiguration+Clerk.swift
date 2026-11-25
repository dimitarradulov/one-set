import Foundation

extension AppLaunchConfiguration {
  static let clerkPublishableKeyInfoKey = "ClerkPublishableKey"

  /// The Clerk publishable key for this build configuration: the development instance's key in
  /// Debug and the production instance's key in Release. Nil while Release still carries the
  /// placeholder, which leaves sign-in unavailable; the Release archive check refuses to ship it.
  static func clerkPublishableKey(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> String? {
    configuredValue(for: clerkPublishableKeyInfoKey, in: infoDictionary)
  }
}
