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
    app.launchArguments = ["--ui-auth-test"]
    app.launch()
  }

  func testAppleCancellationStaysOnWelcomeWithoutAnError() {
    relaunch(with: ["--ui-apple-cancel"])
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["welcome.authError"].exists)
  }

  func testAppleNewAccountOpensPreferencesAndSupportsSharedSignOut() {
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
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
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
    app.buttons["continue.apple"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    app.buttons["account.signOut"].tap()
  }

  func testGoogleNewAccountOpensPreferencesAndSupportsSharedSignOut() {
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
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
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["preferences.unit.lb"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.5"].isSelected)
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
    relaunch(with: ["--ui-auth-persist-session-test", "--ui-progress-keep"])
    XCTAssertTrue(app.buttons["continue.google"].waitForExistence(timeout: 3))
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    app.buttons["account.signOut"].tap()
  }

  func testGoogleCancellationStaysOnWelcomeWithoutAnError() {
    relaunch(with: ["--ui-google-cancel"])
    app.buttons["continue.google"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
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

  func testLoginWithUnknownEmailRequiresExplicitAccountCreation() {
    app.buttons["welcome.login"].tap()
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
    app.buttons["welcome.login"].tap()
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
    relaunch(with: ["--ui-auth-restored"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
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
    app.buttons["account.signOut"].tap()
  }

  func testLoginOffersEmailCodeFlowAndReturnsToWelcome() {
    app.buttons["continue.email"].tap()
    XCTAssertEqual(app.staticTexts["login.title"].label, "Continue with email")
    app.buttons["login.backToWelcome"].tap()
    app.buttons["welcome.login"].tap()

    XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["login.title"].label, "Log in")
    XCTAssertTrue(app.textFields["login.email"].exists)
    XCTAssertTrue(app.buttons["login.sendCode"].exists)
    XCTAssertEqual(app.secureTextFields.count, 0)

    app.buttons["login.backToWelcome"].tap()
    XCTAssertTrue(app.buttons["continue.apple"].waitForExistence(timeout: 3))
  }

  func testPreferencesRetainChoicesOnBackAndResetAfterRelaunch() {
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

    app.navigationBars.buttons.firstMatch.tap()
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

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.buttons["preferences.days.5"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("bro-split").waitForExistence(timeout: 3))
    XCTAssertEqual(firstProgramCardID(), "programs.card.bro-split")
    XCTAssertTrue(programCard("bro-split").label.localizedCaseInsensitiveContains("matches your schedule"))
  }

  func testNonMatchingProgramCanBeSelectedAndSelectionSurvivesBackNavigation() {
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
    let previewButton = app.buttons["overview.day.1.preview"]
    XCTAssertTrue(previewButton.waitForExistence(timeout: 3))
    XCTAssertTrue(previewButton.label.contains("Not started"))
    previewButton.tap()
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["workoutPreview.program"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.name"].label, "Hack Squat Machine")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.reps"].label, "6–10 reps")
    XCTAssertTrue(app.staticTexts["workoutPreview.notStarted"].exists)
    XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start workout'")).count, 0)
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
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
    app.buttons["continue.google"].tap()
    app.buttons["preferences.continue"].tap()
    XCTAssertTrue(programCard("full-body").waitForExistence(timeout: 3))
    XCTAssertFalse(programCard("machine-full-body").label.localizedCaseInsensitiveContains("selected"))
  }

  func testTrialBypassOpensSelectedProgramOverviewAndSwitchesRotationWeeks() {
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
    XCTAssertTrue(app.staticTexts["workoutPreview.readOnly"].label.contains("Read-only"))
    XCTAssertTrue(app.staticTexts["workoutPreview.notStarted"].exists)
    XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start workout'")).count, 0)
    let firstMovement = app.staticTexts["workoutPreview.exercise.1.name"]
    let secondMovement = app.staticTexts["workoutPreview.exercise.2.name"]
    XCTAssertTrue(firstMovement.waitForExistence(timeout: 3))
    XCTAssertEqual(firstMovement.label, "Weighted Chin-Up")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.1.reps"].label, "6–10 reps")
    XCTAssertEqual(secondMovement.label, "Incline Smith-Machine Press")
    XCTAssertEqual(app.staticTexts["workoutPreview.exercise.2.reps"].label, "6–10 reps")
    XCTAssertTrue(secondMovement.exists)
    XCTAssertLessThan(firstMovement.frame.minY, secondMovement.frame.minY)

    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["overview.week.4"].isSelected)
    XCTAssertTrue(app.buttons["overview.day.1.preview"].exists)
    XCTAssertTrue(app.staticTexts["overview.selectedWeek"].label.contains("Week 4"))
    XCTAssertTrue(app.buttons["overview.day.1.preview"].label.contains("Not started"))
  }

  func testCompletedAccountRestoresOverviewFromBothEmailEntryPoints() {
    for action in ["continue.email", "welcome.login"] {
      relaunch(with: ["--ui-auth-existing", "--ui-setup-completed"])
      authenticateExistingEmail(using: action)
      XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
      XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
      XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
      XCTAssertFalse(app.staticTexts["preferences.title"].exists)
      app.buttons["account.signOut"].tap()
      XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
    }
  }

  func testFailedLookupRequiresRetryBeforeRestoringTheProgram() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-retry"])
    XCTAssertTrue(app.staticTexts["setup.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
    app.buttons["setup.retry"].tap()
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
  }

  func testUnavailableSavedProgramRequiresRetryInsteadOfResettingSetup() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-invalid-program"])
    XCTAssertTrue(app.staticTexts["setup.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertTrue(app.buttons["setup.retry"].exists)
  }

  func testSignOutDuringLookupPreventsLateAccountSetupFromAffectingAnotherAccount() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-setup-delayed", "--ui-auth-existing"])
    XCTAssertTrue(app.descendants(matching: .any)["setup.loading"].waitForExistence(timeout: 3))
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))
    authenticateExistingEmail(using: "welcome.login", email: "other@example.com")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 12))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    XCTAssertTrue(app.buttons["preferences.days.3"].isSelected)
    XCTAssertFalse(app.staticTexts["overview.title"].exists)
  }

  func testFailedSignOutExplainsFailureAndKeepsTheCurrentProgram() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-auth-signout-error"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.alerts["Couldn’t sign out"].waitForExistence(timeout: 3))
    app.alerts.buttons["OK"].tap()
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
  }

  func testSignedInWelcomeEntryReturnsToResolvedPreferences() {
    relaunch(with: ["--ui-auth-restored"])
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    app.navigationBars.buttons.firstMatch.tap()
    app.buttons["welcome.login"].tap()
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
    app.navigationBars.buttons.firstMatch.tap()
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
    app.buttons["account.signOut"].tap()
    XCTAssertTrue(app.buttons["welcome.login"].waitForExistence(timeout: 3))

    relaunch(with: ["--ui-auth-existing", "--ui-progress-keep"])
    authenticateExistingEmail(using: "welcome.login")
    XCTAssertTrue(app.staticTexts["preferences.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["preferences.unit.kg"].isSelected)
    app.buttons["account.signOut"].tap()
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
    authenticateExistingEmail(using: "welcome.login", email: "other@example.com")
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
    app.terminate()
    app.launchArguments = ["--ui-auth-test"] + additionalArguments
    app.launch()
  }

  private func firstProgramCardID() -> String? {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "programs.card."))
      .firstMatch.identifier
  }

  private func programCard(_ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "programs.card.\(id)").firstMatch
  }
}
