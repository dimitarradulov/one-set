import XCTest

@MainActor
final class WarmupSheetTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
  }

  func testPreviewWarmupIsSeparateFromExerciseDetailsAndDoesNotStartWorkout() {
    relaunch(with: ["--ui-auth-restored", "--ui-setup-completed", "--ui-workouts-reset"])
    XCTAssertTrue(app.buttons["overview.day.1.preview"].waitForExistence(timeout: 5))
    app.buttons["overview.day.1.preview"].tap()
    let warmup = app.buttons["workoutPreview.warmup.machine-full-body-workout-a-hack-squat-machine"]
    XCTAssertTrue(warmup.waitForExistence(timeout: 3))
    warmup.tap()
    XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50%"))
    let planned = app.textFields["warmup.plannedWeight"]
    planned.tap()
    planned.typeText("100")
    XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50 lb"))
    app.buttons["warmup.close"].tap()
    app.buttons["workoutPreview.exercise.machine-full-body-workout-a-hack-squat-machine.open"].tap()
    XCTAssertTrue(app.staticTexts["exerciseDetail.title"].waitForExistence(timeout: 3))
    navigationBack().tap()
    app.buttons["workoutPreview.start"].tap()
    XCTAssertTrue(firstRecordingField(suffix: ".weight").waitForExistence(timeout: 3))
    XCTAssertEqual(firstRecordingField(suffix: ".weight").value as? String, "-")
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
        app.buttons["recording.warmup.machine-full-body-workout-a-hack-squat-machine"].tap()
        XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50%"))
        let planned = app.textFields["warmup.plannedWeight"]
        planned.tap()
        planned.typeText("100")
        XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50 lb"))
        planned.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "0")
        XCTAssertTrue(app.staticTexts["Enter a weight greater than zero, or leave this empty."].exists)
        XCTAssertFalse(app.staticTexts["warmup.range.0"].label.contains(" lb"))
        planned.typeText(XCUIKeyboardKey.delete.rawValue + "200")
        XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("80–100 lb"))
        app.buttons["warmup.close"].tap()
        XCTAssertEqual(weight.value as? String, "-")
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
    app.buttons["workoutPreview.warmup.machine-full-body-workout-a-hack-squat-machine"].tap()
    XCTAssertTrue(app.staticTexts["warmup.estimate"].label.contains("100 lb"))
    XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50 lb"))
    app.buttons["warmup.close"].tap()
    app.buttons["workoutPreview.start"].tap()
    let previous = app.descendants(matching: .any)["recording.previous.machine-full-body-workout-a-hack-squat-machine"]
    XCTAssertTrue(previous.waitForExistence(timeout: 3))
    XCTAssertTrue(previous.label.contains("100 lb × 10 reps"))
    XCTAssertTrue(previous.label.contains("Previous in this workout"))
    XCTAssertTrue(firstRecordingField(suffix: ".weight").value as? String == "-")
    app.buttons["recording.warmup.machine-full-body-workout-a-hack-squat-machine"].tap()
    XCTAssertTrue(app.staticTexts["warmup.estimate"].label.contains("100 lb"))
    XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("40–50 lb"))
    let planned = app.textFields["warmup.plannedWeight"]
    planned.tap()
    planned.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "200")
    XCTAssertTrue(app.staticTexts["warmup.range.0"].label.contains("80–100 lb"))
    app.buttons["warmup.close"].tap()
    XCTAssertEqual(firstRecordingField(suffix: ".weight").value as? String, "-")
    attachScreenshot(named: "recording-previous-performance")
  }

  private func relaunch(with arguments: [String]) {
    app.launchArguments = ["--ui-auth-test"] + arguments
    app.launch()
  }

  private func firstRecordingField(suffix: String) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'recording.input.' AND identifier ENDSWITH %@", suffix)).firstMatch
  }

  private func navigationBack() -> XCUIElement {
    let floating = app.buttons["BackButton"]
    return floating.exists ? floating : app.navigationBars.buttons.firstMatch
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
