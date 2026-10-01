import XCTest

@MainActor
final class OnboardingJourneyTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
  }

  func testAppleDemoActionOpensPreferencesWithoutAuthentication() {
    openPreferences(using: "continue.apple")
  }

  func testGoogleDemoActionOpensPreferencesWithoutAuthentication() {
    openPreferences(using: "continue.google")
  }

  func testEmailDemoActionOpensPreferencesWithoutAuthentication() {
    openPreferences(using: "continue.email")
  }

  func testLoginIsInformationalAndReturnsToWelcome() {
    app.buttons["welcome.login"].tap()

    XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Informational demo screen"].exists)
    XCTAssertEqual(app.textFields.count, 0)
    XCTAssertEqual(app.secureTextFields.count, 0)

    app.buttons["login.backToWelcome"].tap()
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
  }

  func testPreferencesRetainChoicesOnBackAndResetAfterRelaunch() {
    openPreferences(using: "continue.email")

    for dayCount in 2...5 {
      let option = app.buttons["preferences.days.\(dayCount)"]
      option.tap()
      XCTAssertTrue(option.isSelected)
    }

    let poundOption = app.buttons["preferences.unit.lb"]
    XCTAssertTrue(poundOption.waitForExistence(timeout: 3))
    poundOption.tap()
    XCTAssertTrue(poundOption.isSelected)
    let kilogramOption = app.buttons["preferences.unit.kg"]
    kilogramOption.tap()
    XCTAssertTrue(kilogramOption.isSelected)
    poundOption.tap()
    XCTAssertTrue(poundOption.isSelected)

    app.navigationBars.buttons.firstMatch.tap()
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)

    app.terminate()
    app.launch()
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
  }

  private func openPreferences(using actionIdentifier: String) {
    let action = app.buttons[actionIdentifier]
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    XCTAssertTrue(action.label.localizedCaseInsensitiveContains("demo only"))
    action.tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.textFields.count, 0)
    XCTAssertEqual(app.secureTextFields.count, 0)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
  }
}
