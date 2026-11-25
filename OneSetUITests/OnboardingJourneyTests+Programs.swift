import XCTest

extension OnboardingJourneyTests {
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
    XCTAssertTrue(app.buttons["trial.seePlans"].waitForExistence(timeout: 3))
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
    XCTAssertTrue(app.buttons["trial.seePlans"].waitForExistence(timeout: 3))
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
    XCTAssertFalse(app.buttons["exerciseDetail.warmupDisclosure"].exists)
    XCTAssertFalse(app.staticTexts["exerciseDetail.warmupGuidance"].exists)
    app.scrollViews.firstMatch.swipeUp()

    assertEmptyExerciseRecordsAndHistory()

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

  func testWorkoutPreviewLabelsSupersetOnceAndKeepsBothExerciseLinks() {
    relaunch(with: ["--ui-workout-preview-superset"])

    let superset = app.staticTexts["Superset"]
    XCTAssertTrue(superset.waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "Superset").count, 1)
    XCTAssertTrue(app.buttons["workoutPreview.exercise.machine-full-body-workout-a-hack-squat-machine.open"].exists)
    XCTAssertTrue(app.buttons["workoutPreview.exercise.machine-full-body-workout-a-machine-chest-press.open"].exists)
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

  /// Checks the Records and History tabs of an exercise with no recorded sets, then returns to Records.
  private func assertEmptyExerciseRecordsAndHistory() {
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
  }
}
