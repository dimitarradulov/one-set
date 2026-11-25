import XCTest

extension OnboardingJourneyTests {
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
}
