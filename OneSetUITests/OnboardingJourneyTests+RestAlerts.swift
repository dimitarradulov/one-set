import XCTest

extension OnboardingJourneyTests {
  func testRestAlertsRowOpensSwitchInsteadOfPlaceholder() {
    relaunch(with: ["--ui-main-settings"])
    XCTAssertTrue(app.buttons["settings.row.restAlerts"].waitForExistence(timeout: 3))
    app.buttons["settings.row.restAlerts"].tap()

    XCTAssertTrue(app.navigationBars["Rest alerts"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["settings.destination.comingSoon"].exists)
    let toggle = app.switches["restAlerts.toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 3))
    XCTAssertEqual(toggle.value as? String, "0")
    XCTAssertTrue(app.staticTexts["restAlerts.explanation"].exists)

    // The row spans the full width; tap the switch at its trailing edge.
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    let isOn = NSPredicate(format: "value == '1'")
    XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: isOn, evaluatedWith: toggle)], timeout: 3), .completed)
    XCTAssertFalse(app.staticTexts["restAlerts.notificationsOff"].exists)
  }
}
