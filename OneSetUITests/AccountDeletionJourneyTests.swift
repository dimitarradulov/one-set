import XCTest

@MainActor
final class AccountDeletionJourneyTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    // Relaunches in this journey retain storage; the next test gets a fresh identity.
    app.launchEnvironment["ONESET_UI_TEST_ID"] = UUID().uuidString
    if app.state != .notRunning {
      app.terminate()
    }
  }

  func testConfirmedDeletionReturnsToWelcomeWithMessageOnce() {
    relaunch(with: ["--ui-account-deletion"])
    let delete = app.buttons["accountDeletion.delete"]
    XCTAssertTrue(delete.waitForExistence(timeout: 5))
    delete.tap()
    let dialog = app.alerts["Delete your account?"]
    XCTAssertTrue(dialog.waitForExistence(timeout: 3))
    dialog.buttons["Delete account"].tap()

    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 8))
    let notice = app.descendants(matching: .any)["welcome.accountDeletedNotice"]
    XCTAssertTrue(notice.waitForExistence(timeout: 3))
    XCTAssertEqual(notice.label, "Your account was deleted.")

    relaunch(with: ["--ui-welcome"])
    XCTAssertTrue(app.buttons["continue.email"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.descendants(matching: .any)["welcome.accountDeletedNotice"].exists)
  }

  func testCancellingConfirmationKeepsTheAccount() {
    relaunch(with: ["--ui-account-deletion"])
    XCTAssertTrue(app.navigationBars["Delete account"].waitForExistence(timeout: 5))
    let delete = app.buttons["accountDeletion.delete"]
    XCTAssertTrue(delete.waitForExistence(timeout: 3))
    XCTAssertTrue(delete.isEnabled)
    XCTAssertTrue(app.buttons["accountDeletion.manageSubscription"].exists)
    delete.tap()
    let dialog = app.alerts["Delete your account?"]
    XCTAssertTrue(dialog.waitForExistence(timeout: 3))
    dialog.buttons["Cancel"].tap()
    XCTAssertTrue(delete.waitForExistence(timeout: 3))
    XCTAssertTrue(delete.isEnabled)
    XCTAssertFalse(app.buttons["continue.email"].exists)
    XCTAssertFalse(app.descendants(matching: .any)["welcome.accountDeletedNotice"].exists)
  }

  func testBlockingStatesDisableDelete() {
    relaunch(with: ["--ui-account-deletion-offline"])
    XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.blocker.offline"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["accountDeletion.delete"].isEnabled)

    relaunch(with: ["--ui-account-deletion-active-workout"])
    XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.blocker.activeWorkout"].waitForExistence(timeout: 8))
    XCTAssertFalse(app.buttons["accountDeletion.delete"].isEnabled)
    XCTAssertTrue(app.buttons["accountDeletion.goToWorkout"].exists)
  }

  func testFailedDeletionShowsErrorAndRetry() {
    relaunch(with: ["--ui-account-deletion-failure"])
    XCTAssertTrue(app.buttons["accountDeletion.delete"].waitForExistence(timeout: 5))
    app.buttons["accountDeletion.delete"].tap()
    app.alerts["Delete your account?"].buttons["Delete account"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.failure"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["accountDeletion.retry"].exists)
    XCTAssertEqual(app.buttons["accountDeletion.retry"].label, "Retry")
    XCTAssertFalse(app.buttons["continue.email"].exists)
  }

  private func relaunch(with additionalArguments: [String]) {
    if app.state != .notRunning {
      app.terminate()
    }
    app.launchArguments = ["--ui-auth-test"] + additionalArguments
    app.launch()
  }
}
