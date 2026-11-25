import XCTest

extension OnboardingJourneyTests {
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
        XCTAssertFalse(app.buttons["exerciseDetail.warmupDisclosure"].exists)
        XCTAssertFalse(app.staticTexts["exerciseDetail.warmupLoads"].exists)
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
    app.buttons["recording.exercise.machine-full-body-workout-a-hack-squat-machine.open"].tap()
    let heaviest = app.staticTexts["exerciseDetail.heaviestWeightValue"]
    XCTAssertTrue(heaviest.waitForExistence(timeout: 5))
    XCTAssertTrue(heaviest.label.contains("100 lb"), heaviest.label)
    app.buttons["exerciseDetail.historyTab"].tap()
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "100 lb × 10 reps")).firstMatch.waitForExistence(timeout: 5))
    attachScreenshot(named: "exercise-performance-recorded-history")
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
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset", "--ui-elapsed-session"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    XCTAssertFalse(app.staticTexts["recording.duration"].exists)
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

    XCTAssertGreaterThanOrEqual(durationSeconds(app.staticTexts["recording.duration"].label), 120)
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
    mainTab("History").tap()
    XCTAssertTrue(app.staticTexts["No completed workouts yet"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.session.")).firstMatch.exists)
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-main-tabs"])
    XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    app.buttons["workoutPreview.start"].tap()
    XCTAssertLessThan(durationSeconds(app.staticTexts["recording.duration"].label), 60)
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
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset", "--ui-main-tabs", "--ui-elapsed-session"])
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
    let reviewDuration = app.staticTexts["finish.duration"]
    XCTAssertTrue(reviewDuration.waitForExistence(timeout: 3))
    let initialDuration = reviewDuration.label
    XCTAssertGreaterThanOrEqual(durationSeconds(initialDuration), 120)
    let advances = expectation(for: NSPredicate(format: "label != %@", initialDuration), evaluatedWith: reviewDuration)
    wait(for: [advances], timeout: 5)
    attachScreenshot(named: "finish-review-duration")
    app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
    XCTAssertTrue(reviewDuration.waitForNonExistence(timeout: 3))
    XCTAssertGreaterThanOrEqual(durationSeconds(app.staticTexts["recording.duration"].label), durationSeconds(initialDuration))
    app.buttons["recording.finish"].tap()
    XCTAssertTrue(app.staticTexts["finish.duration"].waitForExistence(timeout: 3))
    app.buttons["finish.confirm"].tap()
    let confirmedAt = Date()

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
    let historyDuration = app.descendants(matching: .any)["history.duration"]
    XCTAssertTrue(historyDuration.waitForExistence(timeout: 3))
    let savedDuration = historyDuration.label
    XCTAssertTrue(savedDuration.contains("2m") || savedDuration.contains("3m"), savedDuration)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "50 lb")).firstMatch.exists)
    XCTAssertTrue(app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Not performed")
    ).firstMatch.exists)
    // Reopen after a full minute so a duration still counting from the start
    // would cross the history display's minute boundary.
    let minutePassed = expectation(for: NSPredicate { _, _ in
      Date().timeIntervalSince(confirmedAt) >= 65
    }, evaluatedWith: app)
    wait(for: [minutePassed], timeout: 75)
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-main-history", "--ui-progress-keep"])
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.list").firstMatch.exists)
    XCTAssertTrue(historyRow.waitForExistence(timeout: 3))
    historyRow.tap()
    XCTAssertTrue(historyDuration.waitForExistence(timeout: 3))
    XCTAssertEqual(historyDuration.label, savedDuration)
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

  func durationSeconds(_ label: String) -> Int {
    let parts = label.replacingOccurrences(of: "Duration · ", with: "").split(separator: ":")
    guard parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]) else {
      XCTFail("Unexpected duration: \(label)")
      return -1
    }
    return minutes * 60 + seconds
  }

  func firstRecordingField(suffix: String) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'recording.input.' AND identifier ENDSWITH %@", suffix)).firstMatch
  }
}
