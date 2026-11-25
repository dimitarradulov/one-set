import XCTest

@MainActor
final class OnboardingJourneyTests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    // Relaunches in this journey retain storage; the next test gets a fresh identity.
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    if app.state != .notRunning {
      app.terminate()
    }
    // Each test launches once with its initial arguments.
  }

  func testProgramChangeRequiresUpdateAndRestoresRemoteProgram() {
    relaunch(with: ["--ui-program-change"])
    XCTAssertTrue(app.staticTexts["overview.programUpdateMessage"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    app.buttons["overview.updateProgram"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    let title = app.staticTexts["overview.title"]
    let changed = expectation(for: NSPredicate(format: "label == %@", "Machine Full Body"), evaluatedWith: title)
    wait(for: [changed], timeout: 5)
    XCTAssertFalse(app.staticTexts["overview.programUpdateMessage"].exists)
  }

  func testProgramChangeBlocksStartFromOpenPreview() {
    relaunch(with: ["--ui-program-change-preview"])
    let start = app.buttons["workoutPreview.start"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    XCTAssertFalse(start.isEnabled)
  }

  func testProgramChangeWaitsForActiveWorkoutToBeDiscarded() {
    relaunch(with: ["--ui-program-change-active"])
    XCTAssertTrue(app.buttons["recording.discard"].waitForExistence(timeout: 5))
    let leftEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
    let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
    leftEdge.press(forDuration: 0.05, thenDragTo: center)
    let update = app.buttons["overview.updateProgram"]
    XCTAssertTrue(update.waitForExistence(timeout: 5))
    update.tap()
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Finish or discard")).firstMatch.waitForExistence(timeout: 5))
    app.buttons["overview.resumeWorkout"].tap()
    app.buttons["recording.discard"].tap()
    app.alerts.buttons["Discard workout"].tap()
    XCTAssertTrue(update.waitForExistence(timeout: 5))
    update.tap()
    let title = app.staticTexts["overview.title"]
    let changed = expectation(for: NSPredicate(format: "label == %@", "Machine Full Body"), evaluatedWith: title)
    wait(for: [changed], timeout: 5)
  }

  func testPreviewResumesActiveWorkout() {
    relaunch(with: ["--ui-main-workout-recording", "--ui-workouts-reset"])
    XCTAssertTrue(navigationBack().waitForExistence(timeout: 5))
    navigationBack().tap()
    let preview = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    preview.tap()
    let action = app.buttons["workoutPreview.start"]
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    XCTAssertEqual(action.label, "Resume workout")
    action.tap()
    XCTAssertTrue(app.buttons["recording.discard"].waitForExistence(timeout: 5))
  }

  func testSwitchExplainsUnfinishedWorkoutAndReturnsToIt() {
    relaunch(with: ["--ui-main-workout-recording", "--ui-workouts-reset"])
    XCTAssertTrue(navigationBack().waitForExistence(timeout: 5))
    navigationBack().tap()
    XCTAssertTrue(app.buttons["overview.switch"].waitForExistence(timeout: 5))
    app.buttons["overview.switch"].tap()
    XCTAssertTrue(app.alerts["Finish your workout first"].waitForExistence(timeout: 5))
    app.alerts.buttons["Return to workout"].tap()
    XCTAssertTrue(app.staticTexts["Workout A"].waitForExistence(timeout: 5))
  }

  func testProgramSwitchReviewsAndSurvivesOfflineRelaunch() {
    relaunch(with: ["--ui-switch-test", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["overview.switch"].waitForExistence(timeout: 5))
    app.buttons["overview.switch"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 5))
    programCard("bro-split").tap()
    XCTAssertTrue(app.staticTexts["program.detail.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["program.detail.title"].label, "Bro Split")
    navigationBack().tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 5))
    programCard("bro-split").tap()
    XCTAssertTrue(app.buttons["program.detail.select"].waitForExistence(timeout: 5))
    app.buttons["program.detail.select"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    relaunch(with: ["--ui-switch-test", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    app.buttons["overview.switch"].tap()
    XCTAssertTrue(programCard("machine-full-body").waitForExistence(timeout: 5))
    programCard("machine-full-body").tap()
    let resume = app.buttons["program.detail.select"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    XCTAssertEqual(resume.label, "Resume this program")
    resume.tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertNotEqual(app.staticTexts["overview.title"].label, "Bro Split")
  }

  func testOfflineSwitchTrainRelaunchAndReconnectUploadsWorkout() {
    relaunch(with: ["--ui-switch-test", "--ui-progress-keep", "--ui-workouts-reset"])
    XCTAssertTrue(app.buttons["overview.switch"].waitForExistence(timeout: 5))
    app.buttons["overview.switch"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 5))
    programCard("bro-split").tap()
    app.buttons["program.detail.select"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    app.buttons["overview.day.1.preview"].tap()
    XCTAssertTrue(app.buttons["workoutPreview.start"].waitForExistence(timeout: 5))
    app.buttons["workoutPreview.start"].tap()
    let weight = firstRecordingField(suffix: ".weight")
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    weight.typeText("50")
    let reps = firstRecordingField(suffix: ".reps")
    reps.tap()
    reps.typeText("8")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.set.toggle.")).firstMatch.tap()
    app.buttons["recording.finish"].tap()
    app.buttons["finish.confirm"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Completed"))

    relaunch(with: ["--ui-switch-test", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Completed"))
    mainTab("History").tap()
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")).firstMatch.waitForExistence(timeout: 5))

    relaunch(with: ["--ui-switch-test", "--ui-switch-online", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Completed"))
    mainTab("Settings").tap()
    let confirmation = app.alerts["Sign out of OneSet?"]
    let deadline = Date().addingTimeInterval(60)
    repeat {
      app.buttons["account.signOut"].tap()
      XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
      if confirmation.exists { break }
      let pending = app.alerts["Keep workouts on this device?"]
      XCTAssertTrue(pending.exists, app.debugDescription)
      pending.buttons["Cancel"].tap()
    } while Date() < deadline
    XCTAssertTrue(confirmation.exists, app.debugDescription)
    confirmation.buttons["Sign out"].tap()
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 5))
  }

  func testReplacementDeviceResumesRestoredProgramProgress() {
    relaunch(with: ["--ui-replacement-device", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["overview.switch"].waitForExistence(timeout: 5))
    app.buttons["overview.switch"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 5))
    programCard("bro-split").tap()
    let resume = app.buttons["program.detail.select"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    XCTAssertEqual(resume.label, "Resume this program")
    resume.tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Bro Split")
    XCTAssertTrue(app.buttons["overview.week.3"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["overview.week.3"].isSelected)
  }

  func navigationBack() -> XCUIElement {
    let floating = app.buttons["BackButton"]
    return floating.exists ? floating : app.navigationBars.buttons.firstMatch
  }

  func mainTab(_ name: String) -> XCUIElement {
    let phoneTab = app.tabBars.buttons[name]
    if phoneTab.exists { return phoneTab }
    // iPad's floating tab items are exposed as cells on current runtimes.
    return app.descendants(matching: .any).matching(NSPredicate(
      format: "label == %@ AND (elementType == %d OR elementType == %d)",
      name, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.cell.rawValue
    )).firstMatch
  }

  func tapAccountSignOut() {
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    let confirmation = app.alerts["Sign out of OneSet?"]
    if confirmation.exists {
      confirmation.buttons["Sign out"].tap()
    }
  }

  func tapSettingsSignOut() {
    mainTab("Settings").tap()
    tapAccountSignOut()
  }

  func completeSetupFromPreferences(acceptPreview: Bool = false) {
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    if !acceptPreview { app.buttons["trial.continueWithoutTrial"].tap() } // Verified Pro skips this tap.
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
  }

  func authenticateExistingEmail(using action: String, email: String = "existing@example.com") {
    app.buttons[action].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText(email)
    app.buttons["login.sendCode"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()
  }

  func openPreferences(using actionIdentifier: String) {
    let action = app.buttons[actionIdentifier]
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    XCTAssertFalse(action.label.localizedCaseInsensitiveContains("demo only"))
    action.tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.textFields.count, 0)
    XCTAssertEqual(app.secureTextFields.count, 0)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
  }

  func relaunch(with additionalArguments: [String]) {
    if app.state != .notRunning {
      app.terminate()
    }
    app.launchArguments = ["--ui-auth-test"] + additionalArguments
    app.launch()
  }

  func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func renderedBannerArtwork(named name: String) -> Data? {
    let banner = app.descendants(matching: .any).matching(identifier: "workoutPreview.banner").firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 3))
    attachScreenshot(named: name)

    guard let screenshot = app.screenshot().image.cgImage else {
      XCTFail("Expected a rendered simulator screenshot.")
      return nil
    }
    let scale = CGFloat(screenshot.width) / app.frame.width
    let frame = banner.frame
    let photoStripHeight = frame.height * 0.12 * scale
    let artworkCrop = CGRect(
      x: frame.minX * scale,
      y: (frame.minY + frame.height * 0.12) * scale,
      width: frame.width * scale,
      height: photoStripHeight
    ).integral
    guard let crop = screenshot.cropping(to: artworkCrop) else {
      XCTFail("Expected the banner artwork region to be inside the screenshot.")
      return nil
    }
    return UIImage(cgImage: crop).pngData()
  }

  func firstProgramCardID() -> String? {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "programs.card."))
      .firstMatch.identifier
  }

  func programCard(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "programs.card.\(id)").firstMatch
  }
}
