import XCTest

/// The trial screen's states, driven by the preset subscription service. Each state keeps a screenshot.
@MainActor
final class TrialAccessTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
  }

  func testInactiveOffersPlansAndSkip() {
    openTrial(preset: "inactive")
    XCTAssertTrue(app.buttons["trial.seePlans"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["trial.continueWithoutTrial"].exists)
    attach("trial-inactive")
    app.buttons["trial.seePlans"].tap()
    XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    attach("trial-paywall")
    app.buttons["paywall.close"].tap()
    XCTAssertTrue(app.buttons["trial.seePlans"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
  }

  func testCheckingShowsProgressAndSkip() {
    openTrial(preset: "checking")
    XCTAssertTrue(app.staticTexts["trial.status"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["trial.status"].label.contains("Checking subscription access"))
    XCTAssertFalse(app.buttons["trial.seePlans"].exists)
    XCTAssertTrue(app.buttons["trial.continueWithoutTrial"].exists)
    attach("trial-checking")
  }

  func testFailedOffersTryAgainAndSkip() {
    openTrial(preset: "failed")
    XCTAssertTrue(app.buttons["trial.tryAgain"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["trial.seePlans"].exists)
    XCTAssertTrue(app.buttons["trial.continueWithoutTrial"].exists)
    attach("trial-failed")
  }

  func testPendingOffersStatusCheckAndSkip() {
    openTrial(preset: "pending")
    XCTAssertTrue(app.buttons["trial.checkStatus"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["trial.status"].label.contains("Waiting for purchase approval"))
    XCTAssertTrue(app.buttons["trial.continueWithoutTrial"].exists)
    attach("trial-pending")
  }

  func testActiveProSavesSetupAndOpensProgram() {
    openTrial(preset: "active")
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Full Body")
    XCTAssertFalse(app.staticTexts["trial.title"].exists)
  }

  func testSaveFailureAfterVerifiedProShowsRetryWithoutSkip() {
    openTrial(preset: "active", extra: ["--ui-completion-save-error"])
    XCTAssertTrue(app.buttons["trial.retrySave"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["trial.continueWithoutTrial"].exists)
    XCTAssertFalse(app.buttons["trial.seePlans"].exists)
    XCTAssertFalse(app.alerts["Couldn’t save progress"].exists)
    attach("trial-save-failed")
  }

  private func openTrial(preset: String, extra: [String] = []) {
    app.launchArguments = ["--ui-auth-test", "--ui-auth-restored", "--ui-progress-reset",
                           "--ui-subscription-\(preset)"] + extra
    app.launch()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 5))
    app.buttons["preferences.continue"].tap()
    let card = app.descendants(matching: .any).matching(identifier: "programs.card.full-body").firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()
    app.buttons["program.detail.select"].tap()
  }

  private func attach(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
