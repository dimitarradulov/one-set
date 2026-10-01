import XCTest

@MainActor
final class OnboardingJourneyTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    if app.state != .notRunning {
      app.terminate()
    }
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

  func testProgramMatchesAreFirstForTwoAndFiveDayPreferencesAndAllProgramsStayAvailable() {
    openPreferences(using: "continue.email")
    app.buttons["preferences.days.2"].tap()
    app.buttons["preferences.continue"].tap()

    let minimalist = programCard("minimalist-full-body")
    XCTAssertTrue(minimalist.waitForExistence(timeout: 3))
    XCTAssertEqual(firstProgramCardID(), "programs.card.minimalist-full-body")
    XCTAssertTrue(minimalist.label.localizedCaseInsensitiveContains("matches your schedule"))
    XCTAssertTrue(programCard("full-body").exists)
    XCTAssertTrue(programCard("upper-lower").exists)
    XCTAssertTrue(programCard("push-pull-legs").exists)
    XCTAssertTrue(programCard("bro-split").exists)
    XCTAssertTrue(programCard("v-taper").exists)
    XCTAssertTrue(programCard("powerhouse").exists)
    XCTAssertTrue(programCard("classic-physique").exists)
    XCTAssertTrue(programCard("free-weight-full-body").exists)
    XCTAssertTrue(programCard("machine-full-body").exists)
    XCTAssertTrue(app.staticTexts["programs.format.machine-full-body"].exists)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    XCTAssertEqual(firstProgramCardID(), "programs.card.bro-split")
    XCTAssertTrue(programCard("bro-split").label.localizedCaseInsensitiveContains("matches your schedule"))
  }

  func testNonMatchingProgramCanBeSelectedAndSelectionSurvivesBackNavigation() {
    openPreferences(using: "continue.apple")
    app.buttons["preferences.days.2"].tap()
    app.buttons["preferences.continue"].tap()

    let machineProgram = programCard("machine-full-body")
    XCTAssertTrue(machineProgram.waitForExistence(timeout: 3))
    XCTAssertFalse(machineProgram.label.localizedCaseInsensitiveContains("matches your schedule"))
    for _ in 0..<5 where !machineProgram.isHittable {
      app.scrollViews.firstMatch.swipeUp()
    }
    machineProgram.tap()

    XCTAssertTrue(app.staticTexts["program.detail.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["program.detail.format"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["program.detail.emphasis"].exists)
    XCTAssertTrue(app.staticTexts["Workout templates"].exists)
    app.buttons["program.detail.select"].tap()

    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["trial.preview.notice"].exists)
    app.buttons["trial.continueWithoutTrial"].tap()

    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    app.navigationBars.buttons.firstMatch.tap()
    app.navigationBars.buttons.firstMatch.tap()

    let selectedMachineProgram = programCard("machine-full-body")
    XCTAssertTrue(selectedMachineProgram.waitForExistence(timeout: 3))
    XCTAssertTrue(selectedMachineProgram.label.localizedCaseInsensitiveContains("selected"))

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("machine-full-body").waitForExistence(timeout: 3))
    XCTAssertTrue(programCard("machine-full-body").label.localizedCaseInsensitiveContains("selected"))

    app.terminate()
    app.launch()
    app.buttons["continue.apple"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("full-body").waitForExistence(timeout: 3))
    XCTAssertFalse(programCard("machine-full-body").label.localizedCaseInsensitiveContains("selected"))
  }

  func testTrialBypassOpensSelectedProgramOverviewAndSwitchesRotationWeeks() {
    openPreferences(using: "continue.apple")
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()

    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["trial.preview.notice"].label.localizedCaseInsensitiveContains("preview"))
    XCTAssertFalse(app.staticTexts["Trial started"].exists)
    XCTAssertFalse(app.staticTexts["Purchase complete"].exists)

    app.buttons["trial.continueWithoutTrial"].tap()

    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Full Body")
    XCTAssertTrue(app.staticTexts["overview.frequency"].label.contains("3 days per week"))
    XCTAssertTrue(app.staticTexts["Recommended training weeks"].exists)
    XCTAssertTrue(app.buttons["overview.week.1"].exists)
    XCTAssertTrue(app.buttons["overview.week.8"].exists)
    XCTAssertGreaterThanOrEqual(app.buttons["overview.week.1"].frame.height, 44)
    let firstDay = app.descendants(matching: .any).matching(identifier: "overview.day.1").firstMatch
    XCTAssertTrue(firstDay.exists)
    XCTAssertTrue(app.staticTexts["overview.day.1.status"].label.contains("Not started"))
    for day in 1...3 {
      XCTAssertTrue(app.staticTexts["overview.day.\(day).status"].label.contains("Not started"))
    }
    XCTAssertFalse(app.staticTexts["Completed"].exists)

    let firstDayPreview = app.descendants(matching: .any)
      .matching(identifier: "overview.day.1.preview")
      .firstMatch
    XCTAssertTrue(firstDayPreview.exists)
    firstDayPreview.tap()
    let firstMovement = app.staticTexts["Weighted Chin-Up"]
    let secondMovement = app.staticTexts["Incline Smith-Machine Press"]
    XCTAssertTrue(firstMovement.waitForExistence(timeout: 3))
    XCTAssertTrue(secondMovement.exists)
    XCTAssertLessThan(firstMovement.frame.minY, secondMovement.frame.minY)

    app.buttons["overview.week.4"].tap()
    XCTAssertTrue(app.buttons["overview.week.4"].isSelected)
    XCTAssertTrue(app.staticTexts["overview.selectedWeek"].label.contains("Week 4"))
    XCTAssertTrue(app.staticTexts["overview.day.1.status"].label.contains("Not started"))
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

  private func firstProgramCardID() -> String? {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "programs.card."))
      .firstMatch.identifier
  }

  private func programCard(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "programs.card.\(id)").firstMatch
  }
}
