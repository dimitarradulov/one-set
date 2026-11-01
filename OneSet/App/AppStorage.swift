import Foundation

/// Keeps every persistent adapter in a UI journey under the same test identity.
struct AppStorage {
  let directory: URL
  let authenticationDefaults: UserDefaults

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    #if DEBUG
    if let value = environment["ONESET_UI_TEST_ID"], let id = UUID(uuidString: value) {
      directory = URL.applicationSupportDirectory.appending(path: "UITests/\(id.uuidString)")
      guard let defaults = UserDefaults(suiteName: "oneset.ui-tests.\(id.uuidString)") else {
        preconditionFailure("Could not open UI test preferences")
      }
      authenticationDefaults = defaults
      return
    }
    #endif
    directory = .applicationSupportDirectory
    authenticationDefaults = .standard
  }
}
