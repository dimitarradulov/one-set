import Testing
@testable import OneSet

struct RevenueCatAPIKeyConfigurationTests {
  @Test
  func readsConfiguredKey() {
    let result = AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: ["RevenueCatAPIKey": "appl_example"])
    #expect(result == .configured(apiKey: "appl_example"))
  }

  @Test
  func trimsSurroundingWhitespace() {
    let result = AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: ["RevenueCatAPIKey": " test_example \n"])
    #expect(result == .configured(apiKey: "test_example"))
  }

  @Test(arguments: [
    "",
    "   ",
    "$(REVENUECAT_API_KEY)",
    "REVENUECAT_DEBUG_PUBLIC_KEY_PLACEHOLDER",
    "REVENUECAT_RELEASE_PUBLIC_KEY_PLACEHOLDER"
  ])
  func emptyUnexpandedOrPlaceholderValuesAreUnconfigured(value: String) {
    #expect(AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: ["RevenueCatAPIKey": value]) == .unconfigured)
  }

  @Test
  func missingOrNonStringValuesAreUnconfigured() {
    #expect(AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: nil) == .unconfigured)
    #expect(AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: [:]) == .unconfigured)
    #expect(AppLaunchConfiguration.revenueCatAPIKey(infoDictionary: ["RevenueCatAPIKey": 42]) == .unconfigured)
  }
}
