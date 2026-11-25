import Testing
@testable import OneSet

struct ClerkPublishableKeyConfigurationTests {
  @Test
  func readsConfiguredKey() {
    let key = AppLaunchConfiguration.clerkPublishableKey(infoDictionary: ["ClerkPublishableKey": " pk_test_example \n"])
    #expect(key == "pk_test_example")
  }

  @Test(arguments: ["", "   ", "$(CLERK_PUBLISHABLE_KEY)", "CLERK_PRODUCTION_PUBLISHABLE_KEY_PLACEHOLDER"])
  func emptyUnexpandedOrPlaceholderValuesAreUnconfigured(value: String) {
    #expect(AppLaunchConfiguration.clerkPublishableKey(infoDictionary: ["ClerkPublishableKey": value]) == nil)
  }

  @Test
  func missingOrNonStringValuesAreUnconfigured() {
    #expect(AppLaunchConfiguration.clerkPublishableKey(infoDictionary: nil) == nil)
    #expect(AppLaunchConfiguration.clerkPublishableKey(infoDictionary: [:]) == nil)
    #expect(AppLaunchConfiguration.clerkPublishableKey(infoDictionary: ["ClerkPublishableKey": 42]) == nil)
  }
}
