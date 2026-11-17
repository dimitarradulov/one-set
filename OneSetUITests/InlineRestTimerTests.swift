import XCTest

@MainActor
final class InlineRestTimerTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    app.launchArguments = ["--ui-auth-test", "--ui-main-workout-recording", "--ui-workouts-reset"]
    app.launch()
  }

  func testTimerFollowsCompletedExerciseOutOfOrderAndSurvivesRelaunch() {
    let headings = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recording.exercise.'"))
    XCTAssertTrue(headings.firstMatch.waitForExistence(timeout: 5))
    let slotIDs = headings.allElementsBoundByIndex.map {
      String($0.identifier.dropFirst("recording.exercise.".count).dropLast(".open".count))
    }
    XCTAssertGreaterThan(slotIDs.count, 2)
    let timer = app.otherElements["recording.rest.countdown"]
    XCTAssertFalse(timer.exists)

    complete(slotIDs[0])
    assertTimer(after: slotIDs[0], before: slotIDs[1])
    screenshot("inline-rest-first")
    app.buttons["recording.rest.add"].tap()
    assertTimer(after: slotIDs[0], before: slotIDs[1])

    app.terminate()
    app.launchArguments.removeAll { $0 == "--ui-workouts-reset" }
    app.launch()
    XCTAssertTrue(timer.waitForExistence(timeout: 5))
    assertTimer(after: slotIDs[0], before: slotIDs[1])
    app.buttons["recording.rest.skip"].tap()
    XCTAssertFalse(timer.exists)

    complete(slotIDs.last!, expectsRest: false)
    screenshot("inline-rest-last-no-timer")

    complete(slotIDs[1])
    assertTimer(after: slotIDs[1], before: slotIDs[2])
    screenshot("inline-rest-middle")
    // The second exercise prescribes 180 seconds. Leave 15 seconds to test expiry.
    for _ in 0..<11 { app.buttons["recording.rest.reduce"].tap() }
    XCTAssertTrue(app.staticTexts["Rest complete"].waitForExistence(timeout: 20))
    XCTAssertTrue(timer.exists)
    XCTAssertFalse(app.buttons["recording.rest.add"].exists)
    screenshot("inline-rest-complete")

    // Finish the remaining exercises out of order; the last completion is not the final row.
    for index in 2..<(slotIDs.count - 1) {
      complete(slotIDs[index], expectsRest: index < slotIDs.count - 2)
    }
    XCTAssertFalse(timer.exists)
    screenshot("inline-rest-all-complete-no-timer")
    reveal(app.buttons["recording.finish"])
    app.buttons["recording.finish"].tap()
    XCTAssertTrue(app.buttons["finish.confirm"].waitForExistence(timeout: 3))
  }

  func testSupersetLogsLowerFirstAndAnchorsOneSharedRest() {
    launchPairedWorkout()
    let label = app.staticTexts["Superset"]
    XCTAssertTrue(label.waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "Superset").count, 1)
    let upper = "machine-full-body-workout-a-hack-squat-machine"
    let lower = "machine-full-body-workout-a-machine-chest-press"
    let next = "machine-full-body-workout-a-neutral-grip-lat-pulldown"
    let timer = app.otherElements["recording.rest.countdown"]
    complete(lower, expectsRest: false)
    app.terminate()
    app.launchArguments.removeAll { $0 == "--ui-workouts-reset" }
    app.launch()
    XCTAssertTrue(label.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["recording.set.toggle.\(lower)"].label.hasPrefix("Undo"))
    XCTAssertFalse(timer.exists)

    complete(upper)
    assertTimer(after: lower, before: next)
    XCTAssertTrue(timer.staticTexts.matching(NSPredicate(format: "label MATCHES '3:00|2:5[0-9]'")).firstMatch.exists)
    app.buttons["recording.rest.add"].tap()
    assertTimer(after: lower, before: next)
    screenshot("inline-rest-superset")
    app.terminate()
    app.launch()
    XCTAssertTrue(timer.waitForExistence(timeout: 5))
    reveal(app.buttons["recording.rest.skip"])
    assertTimer(after: lower, before: next)

    let undo = app.buttons["recording.set.toggle.\(lower)"]
    reveal(undo)
    undo.tap()
    XCTAssertFalse(timer.exists)
    undo.tap()
    XCTAssertTrue(timer.waitForExistence(timeout: 3))
    assertTimer(after: lower, before: next)
    app.buttons["recording.rest.skip"].tap()
    XCTAssertFalse(timer.exists)
  }

  func testReplacementClearsInputsAndKeepsSuperset() {
    launchPairedWorkout()
    let slotID = "machine-full-body-workout-a-hack-squat-machine"
    let heading = app.buttons["recording.exercise.\(slotID).open"]
    XCTAssertTrue(heading.waitForExistence(timeout: 5))
    let weight = app.textFields["recording.input.\(slotID).weight"]
    weight.tap()
    weight.typeText("80")
    app.swipeDown()
    let actions = app.buttons["recording.actions.\(slotID)"]
    reveal(actions)
    actions.tap()
    app.buttons["Replace exercise"].tap()
    let search = app.searchFields["Search exercises"]
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("Dumbbell Wrist Curl")
    app.buttons["replacement.exercise.dumbbell-wrist-curl"].tap()
    XCTAssertTrue(heading.waitForExistence(timeout: 5))
    XCTAssertTrue(heading.label.contains("Dumbbell Wrist Curl"))
    XCTAssertEqual(weight.value as? String, "-")
    XCTAssertTrue(app.staticTexts["Superset"].exists)
    XCTAssertTrue(app.staticTexts["recording.previous.empty.\(slotID)"].exists)
  }

  private func launchPairedWorkout() {
    app.terminate()
    app.launchArguments.append("--ui-main-workout-superset")
    app.launch()
  }

  func testSessionDurationAdvancesStaysVisibleAndSurvivesRestAndRelaunch() {
    let duration = app.staticTexts["recording.duration"]
    XCTAssertTrue(duration.waitForExistence(timeout: 5))
    let initial = duration.label
    let changed = expectation(for: NSPredicate(format: "label != %@", initial), evaluatedWith: duration)
    wait(for: [changed], timeout: 5)

    app.swipeUp()
    XCTAssertTrue(duration.isHittable)
    let headings = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recording.exercise.'"))
    let first = headings.element(boundBy: 0).identifier
    let slotID = String(first.dropFirst("recording.exercise.".count).dropLast(".open".count))
    complete(slotID)
    let beforeRestAdjustment = seconds(duration.label)
    app.buttons["recording.rest.add"].tap()
    app.buttons["recording.rest.skip"].tap()
    XCTAssertTrue(duration.isHittable)
    XCTAssertGreaterThanOrEqual(seconds(duration.label), beforeRestAdjustment)

    let beforeBackground = seconds(duration.label)
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(duration.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(seconds(duration.label), beforeBackground)
    XCTAssertLessThan(seconds(duration.label) - beforeBackground, 60)

    let beforeRelaunch = seconds(duration.label)
    app.terminate()
    app.launchArguments.removeAll { $0 == "--ui-workouts-reset" }
    app.launch()
    XCTAssertTrue(duration.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(seconds(duration.label), beforeRelaunch)
    XCTAssertLessThan(seconds(duration.label) - beforeRelaunch, 60)
  }

  private func seconds(_ label: String) -> Int {
    let parts = label.replacingOccurrences(of: "Duration · ", with: "").split(separator: ":")
    guard parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]) else {
      XCTFail("Unexpected duration: \(label)")
      return 0
    }
    return minutes * 60 + seconds
  }

  private func complete(_ slotID: String, expectsRest: Bool = true) {
    let weight = app.textFields["recording.input.\(slotID).weight"]
    reveal(weight)
    weight.tap()
    weight.typeText("100")
    let reps = app.textFields["recording.input.\(slotID).reps"]
    reps.tap()
    reps.typeText("10")
    app.buttons["recording.set.toggle.\(slotID)"].tap()
    if expectsRest {
      XCTAssertTrue(app.otherElements["recording.rest.countdown"].waitForExistence(timeout: 3))
    } else {
      XCTAssertTrue(app.buttons["recording.set.toggle.\(slotID)"].label.hasPrefix("Undo"))
      XCTAssertFalse(app.otherElements["recording.rest.countdown"].exists)
    }
  }

  private func assertTimer(after slotID: String, before nextSlotID: String?) {
    let timer = app.otherElements["recording.rest.countdown"]
    let toggle = app.buttons["recording.set.toggle.\(slotID)"]
    XCTAssertTrue(app.buttons["recording.rest.skip"].isHittable)
    XCTAssertGreaterThan(timer.frame.minY, toggle.frame.maxY)
    if let nextSlotID {
      let next = app.buttons["recording.exercise.\(nextSlotID).open"]
      XCTAssertLessThan(timer.frame.maxY, next.frame.minY)
    } else {
      XCTAssertLessThan(timer.frame.maxY, app.buttons["recording.finish"].frame.minY)
    }
  }

  private func reveal(_ element: XCUIElement) {
    let duration = app.staticTexts["recording.duration"]
    let headerBottom = duration.exists ? duration.frame.maxY + 10 : app.navigationBars.firstMatch.frame.maxY
    let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36))
    let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52))
    for _ in 0..<12 {
      if element.isHittable {
        if element.frame.midY > headerBottom { return }
        // XCTest can report a field under the pinned duration header as hittable.
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)
      } else if element.frame.minY < app.frame.midY {
        app.swipeDown()
      } else {
        app.swipeUp()
      }
    }
    XCTAssertTrue(element.isHittable)
    XCTAssertGreaterThan(element.frame.midY, headerBottom)
  }

  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
