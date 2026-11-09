import XCTest

@MainActor
final class OnboardingJourneyTests: XCTestCase {
  private var app: XCUIApplication!

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

  func testDevelopmentSignInBypassesProvidersAndSignOutRestoresNormalFlow() {
    relaunch(with: [])
    let shortcut = app.buttons["continue.development"]
    XCTAssertTrue(shortcut.waitForExistence(timeout: 3))
    shortcut.tap()
    XCTAssertTrue(app.buttons["account.signOut"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["login.email"].exists)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.development"].waitForExistence(timeout: 5))
    // Returning to the original injected service must preserve its provider behavior.
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 5))
    tapAccountSignOut()
  }

  func testDevelopmentSignInKeepsLocalProgressAcrossRelaunch() {
    relaunch(with: [])
    app.buttons["continue.development"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 5))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    relaunch(with: [])
    app.buttons["continue.development"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 5))
    navigationBack().tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.development"].waitForExistence(timeout: 5))
  }

  func testDevelopmentSignInShowsEmptyHistoryBeforeFirstWorkout() {
    relaunch(with: [])
    app.buttons["continue.development"].tap()
    completeSetupFromPreferences()
    mainTab("History").tap()

    XCTAssertTrue(app.staticTexts["No completed workouts yet"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Complete your first workout to see it here."].exists)
    XCTAssertFalse(app.staticTexts["History couldn’t be loaded"].exists)
    XCTAssertFalse(app.buttons["history.retry"].exists)
    attachScreenshot(named: "development-history-empty")
  }

  func testAppleCancellationStaysOnWelcomeWithoutAnError() {
    relaunch(with: ["--ui-apple-cancel"])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["welcome.authError"].exists)
  }

  func testAppleNewAccountOpensPreferencesAndSupportsSharedSignOut() {
    relaunch(with: [])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
  }

  func testAppleExistingAccountRestoresSetupAfterLookupRetry() {
    relaunch(with: ["--ui-setup-completed", "--ui-setup-retry"])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.buttons["setup.retry"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    app.buttons["setup.retry"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
  }

  func testAppleRecoverableErrorAllowsAnotherAttempt() {
    relaunch(with: ["--ui-apple-error"])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["welcome.authError"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["continue.apple"].isEnabled)
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
  }

  func testAppleSessionResumesLocalChoicesOfflineAfterRestartAndClearsOnSignOut() {
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-auth-reset", "--ui-progress-reset"])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep", "--ui-setup-offline"])
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    navigationBack().tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    tapAccountSignOut()
  }

  func testGoogleNewAccountOpensPreferencesAndSupportsSharedSignOut() {
    relaunch(with: [])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
  }

  func testGoogleExistingAccountRestoresSetupAfterLookupRetry() {
    relaunch(with: ["--ui-setup-completed", "--ui-setup-retry"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.buttons["setup.retry"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    app.buttons["setup.retry"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
  }

  func testGoogleSessionResumesLocalChoicesOfflineAfterRestartAndClearsOnSignOut() {
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-auth-reset", "--ui-progress-reset"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep", "--ui-setup-offline"])
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    navigationBack().tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["continue.google"].waitForExistence(timeout: 3))
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    tapAccountSignOut()
  }

  func testGoogleCancellationStaysOnWelcomeWithoutAnError() {
    relaunch(with: ["--ui-google-cancel"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["welcome.authError"].exists)
  }

  func testGoogleRecoverableErrorAllowsAnotherAttempt() {
    relaunch(with: ["--ui-google-error"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["welcome.authError"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["continue.google"].isEnabled)
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
  }

  func testGoogleDoesNotEnterSetupWithoutAnAuthenticatedUser() {
    relaunch(with: ["--ui-google-incomplete"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["welcome.authError"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["continue.google"].isEnabled)
  }

  func testContinueWithEmailAsksBeforeCreatingAnAccountThenOpensPreferences() {
    relaunch(with: [])
    app.buttons["continue.email"].tap()
    XCTAssertEqual(app.staticTexts["login.title"].label, "Continue with email")
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText("new@example.com")
    app.buttons["login.sendCode"].tap()

    XCTAssertTrue(app.buttons["login.createAccount"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["login.code"].exists)

    app.buttons["login.createAccount"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.secureTextFields.count, 0)
  }

  func testContinueWithEmailSignsInAnExistingAccount() {
    relaunch(with: ["--ui-auth-existing"])
    app.buttons["continue.email"].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText("existing@example.com")
    app.buttons["login.sendCode"].tap()

    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.secureTextFields.count, 0)
  }

  func testEmailWithUnknownAccountRequiresExplicitAccountCreation() {
    relaunch(with: [])
    app.buttons["continue.email"].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText("new@example.com")
    app.buttons["login.sendCode"].tap()

    XCTAssertTrue(app.buttons["login.createAccount"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.textFields["login.code"].exists)
    XCTAssertTrue(app.staticTexts["login.accountNotFound"].exists)

    app.buttons["login.createAccount"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["login.signedInTitle"].exists)
  }

  func testIncorrectCodeShowsErrorAndResendKeepsVerificationAvailable() {
    relaunch(with: ["--ui-auth-existing"])
    app.buttons["continue.email"].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText("existing@example.com")
    app.buttons["login.sendCode"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))

    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("000000")
    app.buttons["login.verifyCode"].tap()
    XCTAssertTrue(app.staticTexts["login.error"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.textFields["login.code"].exists)

    app.buttons["login.resendCode"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.buttons["login.changeEmail"].tap()
    XCTAssertTrue(app.textFields["login.email"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.textFields["login.email"].value as? String, "existing@example.com")
    XCTAssertFalse(app.textFields["login.code"].exists)
  }

  func testRestoredSessionResolvesSetupAndCanSignOut() {
    relaunch(with: ["--ui-auth-restored", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
  }

  func testAuthenticatedSessionRestoresAfterRelaunchWithoutCompletingOnboarding() {
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-auth-reset"])
    app.buttons["continue.email"].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText("new@example.com")
    app.buttons["login.sendCode"].tap()
    app.buttons["login.createAccount"].tap()
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-persist-session-test"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    tapAccountSignOut()
  }

  func testLoginOffersEmailCodeFlowAndReturnsToWelcome() {
    relaunch(with: [])
    XCTAssertFalse(app.buttons["welcome.login"].exists)
    XCTAssertFalse(app.staticTexts["Already have an account?"].exists)
    app.buttons["continue.email"].tap()
    XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["login.title"].label, "Continue with email")
    XCTAssertTrue(app.textFields["login.email"].exists)
    XCTAssertTrue(app.buttons["login.sendCode"].exists)
    XCTAssertEqual(app.secureTextFields.count, 0)

    navigationBack().tap()
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["continue.google"].exists)
    XCTAssertTrue(app.buttons["continue.email"].exists)
  }

  func testPreferencesRetainChoicesOnBackAndResetAfterRelaunch() {
    relaunch(with: [])
    openPreferences(using: "continue.google")

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

    navigationBack().tap()
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)

    app.terminate()
    app.launch()
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
  }

  func testProgramMatchesAreFirstForTwoAndFiveDayPreferencesAndAllProgramsStayAvailable() {
    relaunch(with: [])
    openPreferences(using: "continue.google")
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

    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    XCTAssertEqual(firstProgramCardID(), "programs.card.bro-split")
    XCTAssertTrue(programCard("bro-split").label.localizedCaseInsensitiveContains("matches your schedule"))
  }

  func testBackendAddedProgramSurvivesAnOfflineRelaunch() {
    relaunch(with: ["--ui-catalog-seed", "--ui-programs"])
    let publishedProgram = programCard("founder-authored-plan")
    XCTAssertTrue(publishedProgram.waitForExistence(timeout: 5))
    XCTAssertTrue(publishedProgram.label.contains("Founder Authored Plan"))

    relaunch(with: ["--ui-catalog-offline", "--ui-programs"])
    let restoredProgram = programCard("founder-authored-plan")
    XCTAssertTrue(restoredProgram.waitForExistence(timeout: 5))
    XCTAssertTrue(restoredProgram.label.contains("Founder Authored Plan"))
  }

  func testRefreshUpdatesSelectedProgramContentWithoutLosingSelectionOrRoute() {
    relaunch(with: ["--ui-catalog-seed-edited", "--ui-programs-selected"])
    let selectedProgram = programCard("push-pull-legs")
    XCTAssertTrue(selectedProgram.waitForExistence(timeout: 5))
    XCTAssertTrue(selectedProgram.label.contains("Push Pull Legs Updated"))
    XCTAssertTrue(selectedProgram.label.localizedCaseInsensitiveContains("selected"))
    XCTAssertTrue(app.staticTexts["programs.title"].exists)
  }

  func testRemovedProgramIsFilteredFromNewChoicesAndRestoredForAnExistingFollower() {
    relaunch(with: ["--ui-programs-removed"])
    XCTAssertTrue(programCard("full-body").waitForExistence(timeout: 3))
    XCTAssertFalse(programCard("machine-full-body").exists)

    relaunch(with: ["--ui-setup-removed-follower", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
  }

  func testPendingSetupForRemovedProgramReturnsToAvailableProgramSelection() {
    relaunch(with: ["--ui-setup-upload-removed"])

    let recoveryMessage = app.descendants(matching: .any).matching(identifier: "programs.recoveryMessage").firstMatch
    XCTAssertTrue(recoveryMessage.waitForExistence(timeout: 5))
    XCTAssertTrue(recoveryMessage.label.contains("no longer available"))
    XCTAssertFalse(programCard("machine-full-body").exists)
    XCTAssertTrue(programCard("full-body").exists)
  }

  func testNonMatchingProgramCanBeSelectedAndSelectionSurvivesBackNavigation() {
    relaunch(with: [])
    openPreferences(using: "continue.google")
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
    XCTAssertTrue(navigationBack().waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["program.detail.format"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["program.detail.emphasis"].exists)
    XCTAssertTrue(app.staticTexts["Workout split"].exists)
    app.buttons["program.detail.select"].tap()

    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["trial.preview.notice"].exists)
    app.buttons["trial.continueWithoutTrial"].tap()

    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    let previewButton = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(previewButton.waitForExistence(timeout: 3))
    XCTAssertTrue(previewButton.label.contains("Not started"))
    previewButton.tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["workoutPreview.program"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.name"].label, "Hack Squat Machine")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.reps"].label, "6–10 reps")
    XCTAssertFalse(app.staticTexts["workoutPreview.notStarted"].exists)
    XCTAssertTrue(app.buttons["workoutPreview.start"].exists)
    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    app.terminate()
    app.launch()
    app.buttons["continue.google"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("full-body").waitForExistence(timeout: 3))
    XCTAssertFalse(programCard("machine-full-body").label.localizedCaseInsensitiveContains("selected"))
  }

  func testTrialBypassOpensSelectedProgramOverviewAndSwitchesRotationWeeks() {
    relaunch(with: [])
    openPreferences(using: "continue.google")
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
    XCTAssertTrue(mainTab("Program").isSelected)
    XCTAssertTrue(mainTab("History").exists)
    XCTAssertTrue(mainTab("Settings").exists)
    XCTAssertTrue(app.staticTexts["overview.frequency"].label.contains("3 days per week"))
    XCTAssertTrue(app.staticTexts["Recommended training weeks"].exists)
    XCTAssertTrue(app.buttons["overview.week.1"].exists)
    XCTAssertTrue(app.buttons["overview.week.8"].exists)
    XCTAssertGreaterThanOrEqual(app.buttons["overview.week.1"].frame.height, 44)
    let firstDay = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(firstDay.exists)
    app.buttons["overview.week.4"].tap()
    XCTAssertTrue(app.staticTexts["overview.selectedWeek"].label.contains("Week 4"))
    for day in 1...3 {
      XCTAssertTrue(app.buttons["overview.day.\(day).preview"].label.contains("Not started"))
    }
    XCTAssertFalse(app.staticTexts["Completed"].exists)

    let firstDayPreview = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(firstDayPreview.exists)
    firstDayPreview.tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["workoutPreview.program"].label.contains("Full Body"))
    XCTAssertFalse(app.staticTexts["workoutPreview.readOnly"].exists)
    XCTAssertEqual(app.staticTexts["workoutPreview.summary"].label, "7 exercises · 1 working set each")
    XCTAssertEqual(app.staticTexts["workoutPreview.exerciseOrderHeading"].label, "Exercise order")
    XCTAssertEqual(app.staticTexts["workoutPreview.repTargetsHeading"].label, "Rep targets")
    XCTAssertFalse(app.staticTexts["workoutPreview.notStarted"].exists)
    XCTAssertTrue(app.buttons["workoutPreview.start"].exists)
    let firstMovement = app.staticTexts["workoutPreview.exercise.1.name"]
    let secondMovement = app.staticTexts["workoutPreview.exercise.2.name"]
    XCTAssertTrue(firstMovement.waitForExistence(timeout: 3))
    XCTAssertEqual(firstMovement.label, "Weighted Chin-Up")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.reps"].label, "6–10 reps")
    XCTAssertEqual(secondMovement.label, "Incline Smith-Machine Press")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.2.reps"].label, "6–10 reps")
    XCTAssertTrue(secondMovement.exists)
    XCTAssertLessThan(firstMovement.frame.minY, secondMovement.frame.minY)

    let firstExercise = app.buttons["workoutPreview.exercise.full-body-workout-a-vertical-pull-upper-chest-weighted-chin-up.open"]
    for _ in 0..<5 where !firstExercise.isHittable {
      app.scrollViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(firstExercise.isHittable)
    let previewRowPosition = firstExercise.frame.minY
    firstExercise.tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["exerciseDetail.title"].label, "Weighted Chin-Up")
    XCTAssertTrue(app.staticTexts["exerciseDetail.videoPlaceholder"].label.contains("No exercise video yet"))
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch.exists)
    XCTAssertFalse(app.staticTexts["Workout A"].exists)
    XCTAssertFalse(app.staticTexts["6–10 reps"].exists)

    let techniqueDisclosure = app.buttons["exerciseDetail.techniqueDisclosure"]
    XCTAssertTrue(techniqueDisclosure.waitForExistence(timeout: 3))
    techniqueDisclosure.tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.techniqueGuidance"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["exerciseDetail.techniqueGuidance"].label.contains("Lower the weight under control"))
    app.buttons["exerciseDetail.warmupDisclosure"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.warmupGuidance"].waitForExistence(timeout: 3))
    app.scrollViews.firstMatch.swipeUp()

    let recordsTab = app.buttons["exerciseDetail.recordsTab"]
    let historyTab = app.buttons["exerciseDetail.historyTab"]
    XCTAssertTrue(recordsTab.waitForExistence(timeout: 3))
    XCTAssertTrue(recordsTab.isSelected)
    XCTAssertFalse(historyTab.isSelected)
    XCTAssertTrue(app.staticTexts["exerciseDetail.performanceScope"].label.contains("Across programs"))
    XCTAssertTrue(app.staticTexts["exerciseDetail.heaviestWeight"].exists)
    XCTAssertTrue(app.staticTexts["exerciseDetail.estimatedOneRepMax"].exists)
    XCTAssertTrue(app.staticTexts["exerciseDetail.mostRecentResult"].exists)
    XCTAssertTrue(app.staticTexts["exerciseDetail.noRecords"].label.contains("No recorded sets yet"))
    XCTAssertTrue(app.staticTexts["exerciseDetail.noRecordsExplanation"].label.contains("Record this exercise to see your results here."))
    XCTAssertEqual(app.staticTexts["exerciseDetail.heaviestWeightValue"].label, "-")
    XCTAssertEqual(app.staticTexts["exerciseDetail.estimatedOneRepMaxValue"].label, "-")
    XCTAssertEqual(app.staticTexts["exerciseDetail.mostRecentResultValue"].label, "-")
    attachScreenshot(named: "exercise-records-performance")

    historyTab.tap()
    XCTAssertTrue(historyTab.isSelected)
    XCTAssertFalse(recordsTab.isSelected)
    XCTAssertTrue(app.staticTexts["exerciseDetail.emptyHistory"].label.contains("No recorded sets yet"))
    XCTAssertTrue(app.staticTexts["exerciseDetail.emptyHistoryExplanation"].label.contains("Record this exercise to see your results here."))
    app.scrollViews.firstMatch.swipeUp()
    XCTAssertFalse(app.staticTexts["101.3 kg"].exists)
    attachScreenshot(named: "exercise-history-empty")

    recordsTab.tap()
    XCTAssertTrue(recordsTab.isSelected)
    XCTAssertTrue(app.staticTexts["exerciseDetail.heaviestWeightValue"].exists)

    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(firstExercise.frame.minY, previewRowPosition, accuracy: 2)
    XCTAssertFalse(app.staticTexts["workoutPreview.notStarted"].exists)

    XCTAssertTrue(app.buttons["workoutPreview.start"].exists)

    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["overview.week.4"].isSelected)
    XCTAssertTrue(app.buttons["overview.day.1.preview"].exists)
    XCTAssertTrue(app.staticTexts["overview.selectedWeek"].label.contains("Week 4"))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Not started"))
  }

  func testExerciseDetailPerformanceSupportsAccessibilityDynamicType() {
    app.terminate()
    app.launchArguments = [
      "--ui-exercise-detail",
      "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    ]
    app.launch()

    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    app.scrollViews.firstMatch.swipeUp()
    let recordsTab = app.buttons["exerciseDetail.recordsTab"]
    XCTAssertTrue(recordsTab.waitForExistence(timeout: 3))
    recordsTab.tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.estimatedOneRepMaxValue"].waitForExistence(timeout: 3))
    attachScreenshot(named: "exercise-records-performance-accessibility")

    app.buttons["exerciseDetail.historyTab"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.emptyHistory"].waitForExistence(timeout: 3))
    for _ in 0..<3 {
      app.scrollViews.firstMatch.swipeUp()
    }
    attachScreenshot(named: "exercise-history-empty-accessibility")
  }

  func testWorkoutPreviewOpensDifferentExerciseGuidanceWithoutStartingWorkout() {
    relaunch(with: ["--ui-workout-preview"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["workoutPreview.summary"].label, "7 exercises · 1 working set each")
    XCTAssertEqual(app.staticTexts["workoutPreview.exerciseOrderHeading"].label, "Exercise order")
    XCTAssertEqual(app.staticTexts["workoutPreview.repTargetsHeading"].label, "Rep targets")
    let chestPress = app.buttons["workoutPreview.exercise.machine-full-body-workout-a-machine-chest-press.open"]
    XCTAssertTrue(chestPress.waitForExistence(timeout: 3))
    chestPress.tap()

    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["exerciseDetail.title"].label, "Machine Chest Press")
    XCTAssertTrue(app.staticTexts["exerciseDetail.videoPlaceholder"].label.contains("No exercise video yet"))
    app.buttons["exerciseDetail.techniqueDisclosure"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.techniqueGuidance"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["exerciseDetail.techniqueGuidance"].label.contains("handles start around mid-chest"))

    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["workoutPreview.notStarted"].exists)
    XCTAssertTrue(app.buttons["workoutPreview.start"].exists)
  }

  func testWorkoutPreviewSummaryReflectsDifferentExerciseCount() {
    relaunch(with: ["--ui-workout-preview-minimalist"])

    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["workoutPreview.summary"].label, "6 exercises · 1 working set each")
  }

  func testWorkoutBannerScreenshotsShowSharedAndDifferentFocusArtwork() {
    relaunch(with: ["--ui-workout-banner-lower-body"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    let lowerA = renderedBannerArtwork(named: "banner-lower-a")

    relaunch(with: ["--ui-workout-banner-lower-body-shared"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    let lowerB = renderedBannerArtwork(named: "banner-lower-b")
    XCTAssertEqual(lowerA, lowerB, "Related lower-body templates should render the same banner artwork.")

    relaunch(with: ["--ui-workout-banner-upper-body"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    let upper = renderedBannerArtwork(named: "banner-upper-body")
    XCTAssertNotEqual(lowerA, upper, "A different focus should render different banner pixels.")
  }

  func testWorkoutBannerMissingAndUnknownAssignmentsRenderGeneralGymFallback() {
    relaunch(with: ["--ui-workout-banner-fallback"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    let unknown = renderedBannerArtwork(named: "banner-unknown-assignment")

    relaunch(with: ["--ui-workout-banner-legacy"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    let missing = renderedBannerArtwork(named: "banner-missing-assignment")
    XCTAssertEqual(unknown, missing, "Unknown and omitted assignments should render identical fallback pixels.")
  }

  func testPublishedWorkoutBannerIsAvailableAfterOfflineRelaunch() {
    relaunch(with: ["--ui-catalog-seed", "--ui-workout-banner-offline"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 5))
    let published = renderedBannerArtwork(named: "banner-published-before-offline-relaunch")

    relaunch(with: ["--ui-catalog-offline", "--ui-workout-banner-offline"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 5))
    let restored = renderedBannerArtwork(named: "banner-published-after-offline-relaunch")
    XCTAssertEqual(published, restored, "The published banner should render from the persisted offline catalog.")
    XCTAssertFalse(app.staticTexts["workoutPreview.notStarted"].exists)
  }

  func testRecordingShowsEmptyAndPreviousPerformanceWithCapturedGuidance() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))

    // First use shows an honest empty result and instructions from the captured template.
    for day in 1...3 {
      app.buttons["overview.day.\(day).preview"].tap()
      XCTAssertTrue(app.buttons["workoutPreview.start"].waitForExistence(timeout: 3))
      app.buttons["workoutPreview.start"].tap()
      let weight = firstRecordingField(suffix: ".weight")
      XCTAssertTrue(weight.waitForExistence(timeout: 3))
      if day == 1 {
        let empty = app.staticTexts["recording.previous.empty.machine-full-body-workout-a-hack-squat-machine"]
        XCTAssertTrue(empty.waitForExistence(timeout: 3))
        weight.tap()
        weight.typeText("100")
        let reps = firstRecordingField(suffix: ".reps")
        reps.tap()
        reps.typeText("10")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.set.toggle.")).firstMatch.tap()
        XCTAssertFalse(app.buttons["recording.guidance.machine-full-body-workout-a-hack-squat-machine"].exists)
        let exercise = app.buttons["recording.exercise.machine-full-body-workout-a-hack-squat-machine.open"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 3))
        exercise.tap()
        XCTAssertEqual(app.staticTexts["exerciseDetail.title"].label, "Hack Squat Machine")
        XCTAssertTrue(app.staticTexts["exerciseDetail.techniqueGuidance"].label.contains("Set the machine so your back remains supported"))
        XCTAssertTrue(app.staticTexts["exerciseDetail.videoPlaceholder"].exists)
        attachScreenshot(named: "recording-exercise-instructions")
        app.buttons["exerciseDetail.warmupDisclosure"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Approximate warm-up loads'")).firstMatch.exists)
        attachScreenshot(named: "recording-exercise-detail")
        navigationBack().tap()
        XCTAssertEqual(firstRecordingField(suffix: ".weight").value as? String, "100")
        XCTAssertEqual(firstRecordingField(suffix: ".reps").value as? String, "10")
        XCTAssertTrue(app.buttons["recording.set.toggle.machine-full-body-workout-a-hack-squat-machine"].label.contains("Undo"))
      } else {
        let weightField = firstRecordingField(suffix: ".weight")
        weightField.tap()
        weightField.typeText("50")
        let reps = firstRecordingField(suffix: ".reps")
        reps.tap()
        reps.typeText("8")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.set.toggle.")).firstMatch.tap()
      }
      app.swipeUp()
      if day == 1 {
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(named: "recording-bottom-spacing")
      }
      app.buttons["recording.finish"].tap()
      XCTAssertTrue(app.buttons["finish.confirm"].waitForExistence(timeout: 3))
      app.buttons["finish.confirm"].tap()
      XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    }

    // Completing the three required days opens Week 2, where Day 1 has a useful prior set.
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.start"].tap()
    let previous = app.descendants(matching: .any)["recording.previous.machine-full-body-workout-a-hack-squat-machine"]
    XCTAssertTrue(previous.waitForExistence(timeout: 3))
    XCTAssertTrue(previous.label.contains("100 lb × 10 reps"))
    XCTAssertTrue(previous.label.contains("Previous in this workout"))
    XCTAssertTrue(firstRecordingField(suffix: ".weight").value as? String == "-")
    attachScreenshot(named: "recording-previous-performance")
  }

  func testWorkoutStorageOpenFailureExplainsRecoveryAndOffersRetry() {
    relaunch(with: ["--ui-workout-storage-error"])
    let alert = app.alerts["Workout unavailable"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'saved workouts are still on this device'")).firstMatch.exists)
    XCTAssertTrue(alert.buttons["Retry storage"].exists)
    alert.buttons["Retry storage"].tap()
    XCTAssertFalse(alert.waitForExistence(timeout: 1))
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
  }

  func testRecordingDiscardZeroSetFinishSignOutGuardAndRestRecovery() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.start"].tap()
    XCTAssertTrue(app.buttons["recording.discard"].waitForExistence(timeout: 3))

    mainTab("Settings").tap()
    tapAccountSignOut()
    XCTAssertTrue(app.alerts["Couldn’t sign out"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.alerts["Couldn’t sign out"].staticTexts.containing(
      NSPredicate(format: "label CONTAINS[c] 'finish or discard'")
    ).firstMatch.exists)
    app.alerts["Couldn’t sign out"].buttons["OK"].tap()
    mainTab("Program").tap()
    XCTAssertTrue(app.buttons["recording.discard"].waitForExistence(timeout: 3))

    app.buttons["recording.discard"].tap()
    let keepWorkout = app.alerts.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'Keep'")
    ).firstMatch
    XCTAssertTrue(keepWorkout.waitForExistence(timeout: 3), app.debugDescription)
    keepWorkout.tap()
    XCTAssertTrue(app.buttons["recording.finish"].exists)
    app.buttons["recording.finish"].tap()
    app.buttons["finish.confirm"].tap()
    XCTAssertTrue(app.alerts.buttons["Keep recording"].waitForExistence(timeout: 3))
    attachScreenshot(named: "recording-finish-empty-discard")
    app.alerts.buttons["Keep recording"].tap()
    app.buttons["recording.discard"].tap()
    app.alerts.buttons["Discard workout"].tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    app.buttons["workoutPreview.start"].tap()
    let weight = firstRecordingField(suffix: ".weight")
    XCTAssertTrue(weight.waitForExistence(timeout: 3))
    weight.tap()
    weight.typeText("100")
    let reps = firstRecordingField(suffix: ".reps")
    reps.tap()
    reps.typeText("10")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.set.toggle.")).firstMatch.tap()
    XCTAssertTrue(app.otherElements["recording.rest.countdown"].waitForExistence(timeout: 3))
    attachScreenshot(named: "recording-rest-active")

    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed"])
    XCTAssertTrue(app.otherElements["recording.rest.countdown"].waitForExistence(timeout: 5))
    app.buttons["recording.discard"].tap()
    app.alerts.buttons["Discard workout"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].waitForExistence(timeout: 3))
  }

  func testFinishedOfflineWorkoutSurvivesRelaunchWithoutSyncStatus() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset", "--ui-main-tabs"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.start"].tap()

    let weight = firstRecordingField(suffix: ".weight")
    XCTAssertTrue(weight.waitForExistence(timeout: 3))
    weight.tap()
    weight.typeText("50")
    let reps = firstRecordingField(suffix: ".reps")
    reps.tap()
    reps.typeText("8")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording.set.toggle.")).firstMatch.tap()
    app.buttons["recording.finish"].tap()
    app.buttons["finish.confirm"].tap()

    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Completed"))
    app.buttons["History"].tap()
    let historyRow = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).firstMatch
    XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
    XCTAssertTrue(historyRow.label.contains("1 of"))
    historyRow.tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.detail").firstMatch.waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "50 lb")).firstMatch.exists)
    XCTAssertTrue(app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Not performed")
    ).firstMatch.exists)
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-main-history", "--ui-progress-keep"])
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.list").firstMatch.exists)
    // The setup service remains suspended for 20 seconds on this launch; saved
    // progress must open before the remote request completes.
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-main-tabs", "--ui-progress-keep", "--ui-setup-timeout"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Completed"))
    XCTAssertTrue(app.buttons["overview.day.2.preview"].label.contains("Not started"))
    XCTAssertFalse(app.staticTexts["setup.uploadStatus"].exists)
    XCTAssertFalse(app.buttons["setup.retryUpload"].exists)
    app.buttons["History"].tap()
    XCTAssertTrue(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).firstMatch.waitForExistence(timeout: 3))
  }

  func testWorkoutStorageSurvivesRelaunchButIsIsolatedFromAnotherJourney() {
    let arguments = ["--ui-auth-restored", "--ui-setup-completed"]
    relaunch(with: arguments)
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.start"].tap()
    XCTAssertTrue(app.buttons["recording.finish"].waitForExistence(timeout: 3))

    relaunch(with: arguments)
    XCTAssertTrue(app.buttons["recording.finish"].waitForExistence(timeout: 5))
    let originalID = app.launchEnvironment["ONESET_UI_TEST_ID"]
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    relaunch(with: arguments)
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["recording.finish"].exists)

    app.launchEnvironment["ONESET_UI_TEST_ID"] = originalID
    relaunch(with: arguments)
    XCTAssertTrue(app.buttons["recording.finish"].waitForExistence(timeout: 5))
  }

  private func firstRecordingField(suffix: String) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'recording.input.' AND identifier ENDSWITH %@", suffix)).firstMatch
  }

  func testCompletedAccountRestoresOverviewFromEmail() {
    relaunch(with: ["--ui-auth-existing", "--ui-setup-completed", "--ui-workouts-reset"])
    authenticateExistingEmail(using: "continue.email")
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(mainTab("Program").isSelected)
    XCTAssertFalse(app.buttons["account.signOut"].exists)
    XCTAssertTrue(mainTab("History").exists)
    XCTAssertTrue(mainTab("Settings").exists)
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'step 4 of 4'")).firstMatch.exists)

    mainTab("History").tap()
    XCTAssertTrue(app.navigationBars["History"].exists)

    mainTab("Settings").tap()
    XCTAssertTrue(app.navigationBars["Settings"].exists)
    XCTAssertTrue(app.staticTexts["settings.section.training"].exists)
    XCTAssertTrue(app.staticTexts["settings.section.downloads"].exists)
    XCTAssertTrue(app.staticTexts["settings.section.account"].exists)
    let expectedRowOrder = [
      "settings.row.units", "settings.row.trainingFrequency", "settings.row.restAlerts",
      "settings.row.downloadedVideos", "settings.row.subscription", "settings.row.accountDeletion",
      "account.signOut",
    ]
    XCTAssertEqual(
      app.buttons.allElementsBoundByIndex
        .filter { $0.identifier.hasPrefix("settings.row.") || $0.identifier == "account.signOut" }
        .map(\.identifier),
      expectedRowOrder
    )
    XCTAssertGreaterThanOrEqual(app.buttons["account.signOut"].frame.height, 44)

    let destinations: [(String, String, String)] = [
      ("settings.row.units", "Units", "Change between kilograms and pounds here."),
      ("settings.row.trainingFrequency", "Training frequency", "Change how many days you plan to train each week."),
      ("settings.row.restAlerts", "Rest alerts", "Choose whether to get a notification when rest ends."),
      ("settings.row.downloadedVideos", "Downloaded videos", "Manage exercise videos saved on this device."),
      ("settings.row.subscription", "Subscription", "Manage your subscription and restore purchases."),
      ("settings.row.accountDeletion", "Account deletion", "Delete your OneSet account and its data."),
    ]
    for (row, title, explanation) in destinations {
      XCTAssertTrue(app.buttons[row].label.contains(title))
      XCTAssertGreaterThanOrEqual(app.buttons[row].frame.height, 44)
      app.buttons[row].tap()
      XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
      XCTAssertTrue(app.staticTexts["settings.destination.comingSoon"].exists)
      XCTAssertTrue(app.staticTexts.matching(
        NSPredicate(format: "label == %@", explanation)
      ).firstMatch.exists)
      navigationBack().tap()
      XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    app.buttons["settings.row.units"].tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))
    mainTab("Program").tap()
    XCTAssertTrue(app.staticTexts["overview.title"].exists)
    mainTab("History").tap()
    XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    mainTab("Settings").tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))
    navigationBack().tap()
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
  }

  func testCompletedSetupDevelopmentRoutesSelectTabsAndDestinations() {
    relaunch(with: ["--ui-main-history"])
    XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    XCTAssertTrue(mainTab("History").isSelected)

    relaunch(with: ["--ui-main-settings-units"])
    XCTAssertTrue(app.staticTexts["settings.destination.comingSoon"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.navigationBars["Units"].exists)
    XCTAssertTrue(mainTab("Settings").isSelected)

    relaunch(with: ["--ui-main-workout-preview"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(mainTab("Program").isSelected)
  }

  func testHistoryPreviewRoutesShowPopulatedPartialEmptyAndRetryStates() {
    relaunch(with: ["--ui-history-populated"])
    XCTAssertTrue(app.staticTexts["October 2026"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).count, 2)

    relaunch(with: ["--ui-history-partial-detail"])
    XCTAssertTrue(app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Not performed")
    ).firstMatch.exists)
    XCTAssertFalse(app.staticTexts["999"].exists)
    XCTAssertFalse(app.staticTexts["draft"].exists)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "0 lb")).firstMatch.exists)
    app.buttons["Program"].tap()
    app.buttons["History"].tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.detail").firstMatch.exists)
    let detailList = app.collectionViews["history.detail"]
    for _ in 0..<5 {
      if app.staticTexts["Recorded as a partial workout."].exists { break }
      detailList.swipeUp()
    }
    XCTAssertTrue(app.staticTexts["Recorded as a partial workout."].waitForExistence(timeout: 5))

    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    relaunch(with: ["--ui-history-empty"])
    XCTAssertTrue(app.staticTexts["No completed workouts yet"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Complete your first workout to see it here."].exists)

    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    relaunch(with: ["--ui-history-error"])
    XCTAssertTrue(app.staticTexts["History couldn’t be loaded"].waitForExistence(timeout: 5))
    app.buttons["history.retry"].tap()
    XCTAssertTrue(app.staticTexts["History couldn’t be loaded"].exists)

    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    relaunch(with: ["--ui-history-refresh-error"])
    XCTAssertEqual(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).count, 2)
    XCTAssertTrue(app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Saved workouts are still here")
    ).firstMatch.waitForExistence(timeout: 5))
    app.buttons["history.retry"].tap()
    XCTAssertEqual(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).count, 2)
  }

  func testHistoryPaginationAndOfflineBoundaryKeepDownloadedRows() {
    relaunch(with: ["--ui-history-pagination"])
    let rows = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    )
    XCTAssertTrue(rows.firstMatch.label.contains("Workout B"))
    XCTAssertTrue(rows.firstMatch.label.contains("1 of 7 exercises completed"))
    XCTAssertGreaterThanOrEqual(rows.firstMatch.frame.height, 44)
    XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5),
      "Reaching the visible history boundary loads the next page")
    attachScreenshot(named: "history-pagination-boundary")
    XCTAssertTrue(app.staticTexts["End of history"].waitForExistence(timeout: 5))

    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    relaunch(with: ["--ui-history-offline-boundary"])
    let offlineBoundary = app.buttons["history.older.offline"]
    XCTAssertTrue(offlineBoundary.waitForExistence(timeout: 5))
    attachScreenshot(named: "history-offline-boundary")
    offlineBoundary.tap()
    XCTAssertTrue(app.buttons["history.older.offline"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).count, 1)
  }

  func testEstablishedCycleConflictExplainsThatWorkoutRemainsOnDevice() {
    relaunch(with: ["--ui-setup-cycle-conflict"])

    let alert = app.alerts["Workout wasn’t uploaded"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    let retainedWorkMessage = alert.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "still saved on this device")
    ).firstMatch
    XCTAssertTrue(retainedWorkMessage.exists)
    XCTAssertTrue(retainedWorkMessage.label.contains("different cycle"))
    XCTAssertTrue(retainedWorkMessage.label.contains("wasn’t uploaded or moved"))
    alert.buttons["OK"].tap()

    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["setup.uploadStatus"].exists)
    XCTAssertFalse(app.buttons["setup.retryUpload"].exists)
  }

  func testProgramBrowsingStackAndSelectedWeekSurviveTabSwitching() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))

    app.buttons["overview.week.4"].tap()
    let preview = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 3))
    preview.tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))

    app.scrollViews.firstMatch.swipeUp()
    app.buttons["workoutPreview.exercise.machine-full-body-workout-a-machine-chest-press.open"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    app.scrollViews.firstMatch.swipeUp()
    let exerciseHistoryTab = app.buttons["exerciseDetail.historyTab"]
    XCTAssertTrue(exerciseHistoryTab.waitForExistence(timeout: 3))
    exerciseHistoryTab.tap()
    XCTAssertTrue(exerciseHistoryTab.isSelected)
    let performancePanelPosition = exerciseHistoryTab.frame.minY

    mainTab("Settings").tap()
    app.buttons["settings.row.units"].tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))
    mainTab("History").tap()
    XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    mainTab("Program").tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["exerciseDetail.historyTab"].isSelected)
    XCTAssertEqual(app.buttons["exerciseDetail.historyTab"].frame.minY, performancePanelPosition, accuracy: 2)
    mainTab("Settings").tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))

    mainTab("Program").tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].exists)
    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))

    navigationBack().tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.selectedWeek"].label, "Week 4")
  }

  func testAccountChangeResetsBothTabStacksAndSelectsProgram() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))

    app.buttons["overview.week.4"].tap()
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.exercise.machine-full-body-workout-a-machine-chest-press.open"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))

    mainTab("Settings").tap()
    app.buttons["settings.row.units"].tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))
    navigationBack().tap()
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))

    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(mainTab("Program").isSelected)
    XCTAssertFalse(app.staticTexts["exerciseDetail.title"].exists)

    mainTab("Settings").tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.navigationBars["Units"].exists)
    XCTAssertFalse(app.staticTexts["Change between kilograms and pounds here."].exists)
  }

  func testFailedLookupRequiresRetryBeforeRestoringTheProgram() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-retry", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["setup.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
    app.buttons["setup.retry"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
  }

  func testUnavailableSavedProgramRequiresRetryInsteadOfResettingSetup() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-invalid-program", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["setup.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["setup.retry"].exists)
  }

  func testSignOutDuringLookupPreventsLateAccountSetupFromAffectingAnotherAccount() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-timeout", "--ui-auth-existing", "--ui-workouts-reset"])
    XCTAssertTrue(app.descendants(matching: .any)["setup.loading"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["account.signOut"].exists)
    XCTAssertTrue(app.buttons["account.signOut"].waitForExistence(timeout: 17))
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    authenticateExistingEmail(using: "continue.email", email: "other@example.com")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 12))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
  }

  func testSignOutRequiresConfirmationAndCancelKeepsAccountAndPreferences() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    mainTab("Settings").tap()
    app.buttons["account.signOut"].tap()
    let confirmation = app.alerts["Sign out of OneSet?"]
    XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["continue.email"].exists)
    attachScreenshot(named: "sign-out-confirmation")
    confirmation.buttons["Cancel"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].exists)
    mainTab("Program").tap()
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
    mainTab("Settings").tap()
    tapAccountSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
  }

  func testFailedSignOutExplainsFailureAndKeepsTheCurrentProgram() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-auth-signout-error", "--ui-workouts-reset"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    mainTab("Settings").tap()
    tapAccountSignOut()
    XCTAssertTrue(app.alerts["Couldn’t sign out"].waitForExistence(timeout: 3))
    app.alerts.buttons["OK"].tap()
    mainTab("Program").tap()
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
  }

  func testPendingSessionSignOutExplainsRetentionAndCanBeCancelled() {
    relaunch(with: ["--ui-session-signout-confirmation"])
    let alert = app.alerts["Keep workouts on this device?"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts.containing(
      NSPredicate(format: "label CONTAINS %@", "setup they depend on")
    ).firstMatch.exists)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "pending-session-signout-confirmation"
    attachment.lifetime = .keepAlways
    add(attachment)

    alert.buttons["Cancel"].tap()

    XCTAssertFalse(alert.exists)
    XCTAssertTrue(app.navigationBars["Settings"].exists)
    XCTAssertTrue(app.buttons["account.signOut"].exists)
  }

  func testFailedPendingSessionSignOutExplainsWorkRemainsOnDevice() {
    relaunch(with: ["--ui-session-signout-error"])
    let alert = app.alerts["Couldn’t sign out"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts.containing(
      NSPredicate(format: "label CONTAINS %@", "workouts are still saved on this device")
    ).firstMatch.exists)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "pending-session-signout-error"
    attachment.lifetime = .keepAlways
    add(attachment)

    alert.buttons["OK"].tap()

    XCTAssertTrue(app.navigationBars["Settings"].exists)
    XCTAssertTrue(app.buttons["account.signOut"].exists)
  }

  func testSignedInWelcomeEntryReturnsToResolvedPreferences() {
    relaunch(with: ["--ui-auth-restored"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    navigationBack().tap()
    app.buttons["continue.email"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["login.signedInTitle"].exists)
  }

  func testSavedPreferencesResumeProgramSelectionAfterOfflineRelaunch() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-restored", "--ui-setup-offline", "--ui-progress-keep"])
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    XCTAssertEqual(firstProgramCardID(), "programs.card.bro-split")
    navigationBack().tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    app.buttons["preferences.days.2"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("minimalist-full-body").waitForExistence(timeout: 3))
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-restored", "--ui-setup-offline", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    app.buttons["trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 2 training days per week")
  }

  func testUnsavedPreferenceChoicesAreNotCheckpoints() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep", "--ui-setup-offline"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
  }

  func testSelectedProgramResumesTrialOfflineAndSignOutClearsProgress() {
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-auth-reset", "--ui-auth-existing", "--ui-progress-reset"])
    authenticateExistingEmail(using: "continue.email")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep", "--ui-setup-offline"])
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
    app.buttons["trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Full Body")
    tapSettingsSignOut()
    XCTAssertTrue(app.alerts["Discard setup awaiting upload?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Sign out and discard"].tap()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-existing", "--ui-progress-keep"])
    authenticateExistingEmail(using: "continue.email")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    tapAccountSignOut()
  }

  func testLocalSaveFailureKeepsChoicesAndDoesNotAdvanceOrPersist() {
    relaunch(with: ["--ui-progress-save-error", "--ui-progress-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(app.alerts["Couldn’t save progress"].waitForExistence(timeout: 3))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "onboarding-save-error"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.alerts.buttons["OK"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
  }

  func testAnotherAccountCannotResumeSavedChoicesDuringOfflineLookup() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-existing", "--ui-progress-keep", "--ui-setup-offline"])
    authenticateExistingEmail(using: "continue.email", email: "other@example.com")
    XCTAssertTrue(app.staticTexts["setup.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(programCard("bro-split").exists)
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
  }

  func testBackendCompletedSetupTakesPriorityOverUnfinishedLocalChoices() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("full-body").waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep", "--ui-setup-completed"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
  }

  func testCompletedOfflineSetupSurvivesRestartAndRequiresCancelOrDiscard() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-upload-offline"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    app.buttons["trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep", "--ui-setup-offline", "--ui-upload-offline"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["overview.preferences"].label.contains("lb"))
    tapSettingsSignOut()
    XCTAssertTrue(app.alerts["Discard setup awaiting upload?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].exists)
    mainTab("Program").tap()
    XCTAssertTrue(app.staticTexts["overview.title"].exists)
    mainTab("Settings").tap()
    tapSettingsSignOut()
    app.alerts.buttons["Sign out and discard"].tap()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
  }

  func testReconnectUploadsSetupAndAnotherDeviceRestoresIt() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-shared-backend", "--ui-backend-reset", "--ui-upload-offline"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    app.buttons["trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.staticTexts["setup.uploadStatus"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep", "--ui-shared-backend"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    let uploaded = NSPredicate(format: "exists == false")
    expectation(for: uploaded, evaluatedWith: app.staticTexts["setup.uploadStatus"])
    waitForExpectations(timeout: 5)
    // Clear device-local state while retaining the shared account backend.
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-shared-backend"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Full Body")
    XCTAssertTrue(app.staticTexts["overview.preferences"].label.contains("lb"))
    tapSettingsSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.alerts["Discard setup awaiting upload?"].exists)
  }

  func testMockedTrialAcceptanceRetriesUploadWithoutGrantingEntitlement() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-upload-retry"])
    completeSetupFromPreferences(acceptPreview: true)
    XCTAssertTrue(app.staticTexts["setup.uploadStatus"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["Trial started"].exists)
    XCTAssertFalse(app.staticTexts["Purchase complete"].exists)
    app.buttons["setup.retryUpload"].tap()
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["setup.uploadStatus"])
    waitForExpectations(timeout: 5)
    tapSettingsSignOut()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.alerts["Discard setup awaiting upload?"].exists)
  }

  func testAutomaticUploadRetryRecoversInTheRunningApp() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-upload-retry", "--ui-workouts-reset"])
    completeSetupFromPreferences()
    XCTAssertTrue(app.staticTexts["setup.uploadStatus"].waitForExistence(timeout: 3))
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["setup.uploadStatus"])
    waitForExpectations(timeout: 20)
    XCTAssertTrue(app.staticTexts["overview.title"].exists)
  }

  func testLateUploadAfterDiscardCannotApplyToAnotherAccount() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-upload-delayed", "--ui-auth-existing"])
    completeSetupFromPreferences()
    XCTAssertTrue(app.staticTexts["setup.uploadStatus"].waitForExistence(timeout: 3))
    tapSettingsSignOut()
    XCTAssertTrue(app.alerts["Discard setup awaiting upload?"].waitForExistence(timeout: 3))
    app.alerts.buttons["Sign out and discard"].tap()
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 3))
    authenticateExistingEmail(using: "continue.email", email: "other@example.com")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    let changedAccount = expectation(for: NSPredicate(format: "exists == false"),
                                    evaluatedWith: app.staticTexts["preferences.title"])
    changedAccount.isInverted = true
    waitForExpectations(timeout: 9)
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
    tapAccountSignOut()
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
  }

  private func navigationBack() -> XCUIElement {
    let floating = app.buttons["BackButton"]
    return floating.exists ? floating : app.navigationBars.buttons.firstMatch
  }

  private func mainTab(_ name: String) -> XCUIElement {
    let phoneTab = app.tabBars.buttons[name]
    if phoneTab.exists { return phoneTab }
    // iPad's floating tab items are exposed as cells on current runtimes.
    return app.descendants(matching: .any).matching(NSPredicate(
      format: "label == %@ AND (elementType == %d OR elementType == %d)",
      name, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.cell.rawValue
    )).firstMatch
  }

  private func tapAccountSignOut() {
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    let confirmation = app.alerts["Sign out of OneSet?"]
    if confirmation.exists {
      confirmation.buttons["Sign out"].tap()
    }
  }

  private func tapSettingsSignOut() {
    mainTab("Settings").tap()
    tapAccountSignOut()
  }

  func testFailedCompletionSaveKeepsTrialAndDoesNotPersistOverview() {
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-completion-save-error"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    app.buttons["trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.alerts["Couldn’t save progress"].waitForExistence(timeout: 3))
    app.alerts.buttons["OK"].tap()
    XCTAssertTrue(app.staticTexts["trial.title"].exists)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
    relaunch(with: ["--ui-auth-restored", "--ui-progress-keep", "--ui-setup-offline"])
    XCTAssertTrue(app.staticTexts["trial.title"].waitForExistence(timeout: 3))
  }

  private func completeSetupFromPreferences(acceptPreview: Bool = false) {
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.unit.lb"].tap()
    app.buttons["preferences.continue"].tap()
    programCard("full-body").tap()
    app.buttons["program.detail.select"].tap()
    app.buttons[acceptPreview ? "trial.continuePreview" : "trial.continueWithoutTrial"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
  }

  private func authenticateExistingEmail(using action: String, email: String = "existing@example.com") {
    app.buttons[action].tap()
    app.textFields["login.email"].tap()
    app.textFields["login.email"].typeText(email)
    app.buttons["login.sendCode"].tap()
    XCTAssertTrue(app.textFields["login.code"].waitForExistence(timeout: 3))
    app.textFields["login.code"].tap()
    app.textFields["login.code"].typeText("123456")
    app.buttons["login.verifyCode"].tap()
  }

  private func openPreferences(using actionIdentifier: String) {
    let action = app.buttons[actionIdentifier]
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    XCTAssertFalse(action.label.localizedCaseInsensitiveContains("demo only"))
    action.tap()

    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.textFields.count, 0)
    XCTAssertEqual(app.secureTextFields.count, 0)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
  }

  private func relaunch(with additionalArguments: [String]) {
    if app.state != .notRunning {
      app.terminate()
    }
    app.launchArguments = ["--ui-auth-test"] + additionalArguments
    app.launch()
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func renderedBannerArtwork(named name: String) -> Data? {
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

  private func firstProgramCardID() -> String? {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "programs.card."))
      .firstMatch.identifier
  }

  private func programCard(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "programs.card.\(id)").firstMatch
  }
}
