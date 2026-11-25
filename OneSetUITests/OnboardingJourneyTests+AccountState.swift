import XCTest

extension OnboardingJourneyTests {
  func testCompletedAccountRestoresOverviewFromEmail() {
    relaunch(with: ["--ui-auth-existing", "--ui-setup-completed", "--ui-workouts-reset"])
    authenticateExistingEmail(using: "continue.email")
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["overview.title"].label, "Machine Full Body")
    XCTAssertEqual(app.staticTexts["overview.preferences"].label, "Your preferences: lb · 5 training days per week")
    XCTAssertFalse(app.staticTexts["preferences.title"].exists)
    XCTAssertFalse(app.staticTexts["trial.title"].exists)
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
      "settings.row.downloadedVideos", "account.signOut", "settings.row.subscription",
      "settings.row.accountDeletion"
    ]
    XCTAssertEqual(
      app.buttons.allElementsBoundByIndex
        .filter { $0.identifier.hasPrefix("settings.row.") || $0.identifier == "account.signOut" }
        .map(\.identifier),
      expectedRowOrder
    )
    XCTAssertGreaterThanOrEqual(app.buttons["account.signOut"].frame.height, 44)

    let destinations: [(String, String, String)] = [
      ("settings.row.downloadedVideos", "Downloaded videos", "Manage exercise videos saved on this device."),
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

    XCTAssertTrue(app.buttons["settings.row.accountDeletion"].label.contains("Account deletion"))
    app.buttons["settings.row.accountDeletion"].tap()
    XCTAssertTrue(app.navigationBars["Delete account"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.whatGetsDeleted"].exists)
    navigationBack().tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))

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
    XCTAssertTrue(app.buttons["settings.units.kg"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.navigationBars["Units"].exists)
    XCTAssertTrue(mainTab("Settings").isSelected)

    relaunch(with: ["--ui-main-workout-preview"])
    XCTAssertTrue(app.staticTexts["workoutPreview.title"].waitForExistence(timeout: 3))
    XCTAssertTrue(mainTab("Program").isSelected)
  }

  func testUnitsAndTrainingFrequencyScreensSaveTheSelection() {
    relaunch(with: ["--ui-main-tabs", "--ui-workouts-reset"])
    XCTAssertTrue(mainTab("Settings").waitForExistence(timeout: 5))
    mainTab("Settings").tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    app.buttons["settings.row.units"].tap()
    XCTAssertTrue(app.navigationBars["Units"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["settings.destination.comingSoon"].exists)
    XCTAssertTrue(app.buttons["settings.units.lb"].isSelected)
    XCTAssertFalse(app.buttons["settings.units.kg"].isSelected)
    app.buttons["settings.units.kg"].tap()
    XCTAssertTrue(app.buttons["settings.units.kg"].isSelected)
    XCTAssertFalse(app.buttons["settings.units.lb"].isSelected)
    navigationBack().tap()
    app.buttons["settings.row.trainingFrequency"].tap()
    XCTAssertTrue(app.navigationBars["Training frequency"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["settings.destination.comingSoon"].exists)
    XCTAssertTrue(app.buttons["settings.frequency.5"].isSelected)
    app.buttons["settings.frequency.2"].tap()
    XCTAssertTrue(app.buttons["settings.frequency.2"].isSelected)
    XCTAssertFalse(app.buttons["settings.frequency.5"].isSelected)
    navigationBack().tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
  }

  func testUnitsRowIsDisabledWithNoteDuringActiveWorkout() {
    relaunch(with: ["--ui-main-workout-recording", "--ui-workouts-reset", "--ui-main-settings"])
    mainTab("Settings").tap()
    XCTAssertTrue(app.buttons["settings.row.units"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["settings.row.units"].isEnabled)
    XCTAssertTrue(app.buttons["settings.row.trainingFrequency"].isEnabled)
    XCTAssertTrue(app.staticTexts["Finish or discard your workout to change units."].exists)
  }

  func testHistoryPreviewRoutesShowPopulatedPartialEmptyAndRetryStates() {
    relaunch(with: ["--ui-history-populated"])
    XCTAssertTrue(app.staticTexts["October 2026"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")
    ).count, 2)

    relaunch(with: ["--ui-history-partial-detail"])
    XCTAssertEqual(app.staticTexts.matching(identifier: "Superset").count, 1)
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
    XCTAssertFalse(app.buttons["settings.units.kg"].exists)
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
    relaunch(with: ["--ui-auth-restored", "--ui-progress-reset", "--ui-upload-retry", "--ui-subscription-active"])
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
}
