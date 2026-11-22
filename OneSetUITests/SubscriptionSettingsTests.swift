import XCTest

/// Settings > Subscription with the subscription fakes. Nothing here touches RevenueCat.
@MainActor
final class SubscriptionSettingsTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
  }

  func testSettingsRowOpensSubscriptionScreen() {
    launch("--ui-main-settings", "--ui-subscription-active")
    XCTAssertTrue(app.buttons["settings.row.subscription"].waitForExistence(timeout: 5))
    app.buttons["settings.row.subscription"].tap()
    XCTAssertTrue(app.navigationBars["Subscription"].waitForExistence(timeout: 3))
    XCTAssertTrue(status(contains: "OneSet Pro is active"))
    XCTAssertTrue(app.buttons["subscription.restore"].isEnabled)
    XCTAssertTrue(app.buttons["subscription.manage"].exists)
    XCTAssertFalse(app.buttons["subscription.primaryAction"].exists)
  }

  func testProActive() {
    openSubscription("--ui-settings-subscription")
    XCTAssertTrue(status(contains: "OneSet Pro is active"))
    XCTAssertFalse(app.buttons["subscription.primaryAction"].exists)
    attachScreenshot(named: "subscription-active")
  }

  func testInactiveOffersPlansAfterAFreshCheck() {
    openSubscription("--ui-settings-subscription-inactive")
    XCTAssertTrue(status(contains: "No active subscription"))
    let plans = app.buttons["subscription.primaryAction"]
    XCTAssertEqual(plans.label, "See plans")
    attachScreenshot(named: "subscription-inactive")
    plans.tap()
    XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    app.buttons["paywall.close"].tap()
    XCTAssertTrue(app.buttons["subscription.primaryAction"].waitForExistence(timeout: 5))
  }

  func testCheckingDisablesRestoreAndOffersNoAction() {
    openSubscription("--ui-settings-subscription-checking")
    XCTAssertTrue(status(contains: "Checking subscription access"))
    XCTAssertFalse(app.buttons["subscription.restore"].isEnabled)
    XCTAssertFalse(app.buttons["subscription.primaryAction"].exists)
    XCTAssertTrue(app.buttons["subscription.manage"].isEnabled)
    attachScreenshot(named: "subscription-checking")
  }

  func testFailedCheckOffersTryAgain() {
    openSubscription("--ui-settings-subscription-failed")
    XCTAssertTrue(status(contains: "Couldn’t verify subscription"))
    XCTAssertEqual(app.buttons["subscription.primaryAction"].label, "Try Again")
    XCTAssertTrue(app.buttons["subscription.manage"].exists)
    attachScreenshot(named: "subscription-failed")
    app.buttons["subscription.primaryAction"].tap()
    XCTAssertTrue(status(contains: "Couldn’t verify subscription"))
  }

  func testPendingApprovalOffersStatusCheck() {
    openSubscription("--ui-settings-subscription-pending")
    XCTAssertTrue(status(contains: "Waiting for purchase approval"))
    XCTAssertEqual(app.buttons["subscription.primaryAction"].label, "Check status")
    attachScreenshot(named: "subscription-pending")
  }

  func testRestoreInProgress() {
    openSubscription("--ui-settings-subscription-restoring")
    XCTAssertTrue(status(contains: "Restoring purchases"))
    XCTAssertFalse(app.buttons["subscription.restore"].isEnabled)
    attachScreenshot(named: "subscription-restoring")
  }

  func testRestoreRestoresPro() {
    openSubscription("--ui-settings-subscription-restored")
    XCTAssertTrue(status(contains: "Purchases restored"))
    attachScreenshot(named: "subscription-restored")
  }

  func testRestoreWithoutPurchase() {
    openSubscription("--ui-settings-subscription-no-purchase")
    XCTAssertTrue(status(contains: "No active purchases found"))
    XCTAssertEqual(app.buttons["subscription.primaryAction"].label, "See plans")
    attachScreenshot(named: "subscription-no-purchase")
  }

  func testRestoreLinkedToAnotherAccount() {
    openSubscription("--ui-settings-subscription-mismatch")
    XCTAssertTrue(status(contains: "This subscription is linked to another OneSet account"))
    attachScreenshot(named: "subscription-mismatch")
  }

  func testFailedRestore() {
    openSubscription("--ui-settings-subscription-restore-failed")
    XCTAssertTrue(status(contains: "Restore did not complete"))
    attachScreenshot(named: "subscription-restore-failed")
  }

  func testRestoreButtonRunsRestore() {
    launch("--ui-main-settings", "--ui-subscription-inactive", "--ui-subscription-restore-restored")
    app.buttons["settings.row.subscription"].tap()
    XCTAssertTrue(status(contains: "No active subscription"))
    app.buttons["subscription.restore"].tap()
    XCTAssertTrue(status(contains: "Purchases restored"))
  }

  // MARK: Helpers

  private func openSubscription(_ route: String) {
    launch(route)
    XCTAssertTrue(app.navigationBars["Subscription"].waitForExistence(timeout: 8))
  }

  private func launch(_ arguments: String...) {
    app.launchArguments = ["--ui-auth-test"] + arguments
    app.launch()
  }

  private func status(contains text: String) -> Bool {
    let element = app.descendants(matching: .any)["subscription.status"]
    guard element.waitForExistence(timeout: 5) else { return false }
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
