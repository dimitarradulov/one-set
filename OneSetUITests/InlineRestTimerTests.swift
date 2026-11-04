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
    for _ in 0..<12 {
      if element.isHittable { return }
      if element.frame.minY < app.frame.midY { app.swipeDown() }
      else { app.swipeUp() }
    }
    XCTAssertTrue(element.isHittable)
  }

  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
