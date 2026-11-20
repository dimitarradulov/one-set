import XCTest

@MainActor
final class AlternatingProgramJourneyTests: XCTestCase {
  func testWeekTwoShowsItsOwnDaysAndAdvancedLegSuperset() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    app.launchArguments = ["--ui-program-rotation"]
    app.launch()

    let dayOne = app.buttons["overview.day.1.preview"]
    let dayTwo = app.buttons["overview.day.2.preview"]
    XCTAssertTrue(dayOne.waitForExistence(timeout: 5))
    XCTAssertTrue(dayOne.label.contains("Chest & Back"))
    XCTAssertTrue(dayTwo.label.contains("Legs,"))
    XCTAssertFalse(app.buttons["overview.day.3.preview"].exists)

    app.buttons["overview.week.2"].tap()
    XCTAssertTrue(dayOne.label.contains("Delts & Arms"))
    XCTAssertTrue(dayTwo.label.contains("Legs (Advanced Emphasis)"))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Rotation week two"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    dayTwo.tap()
    XCTAssertTrue(app.staticTexts["Superset"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Leg Extension Hold (10–25 sec)"].exists)
    XCTAssertTrue(app.staticTexts["Smith-Machine Squat"].exists)
    XCTAssertFalse(app.buttons["workoutPreview.start"].exists)
    let preview = XCTAttachment(screenshot: app.screenshot())
    preview.name = "Advanced legs superset"
    preview.lifetime = .keepAlways
    add(preview)
  }
}
