import Foundation
import Testing
@testable import OneSet

@MainActor
final class FakeNotificationCenter: NotificationCentering {
  var status: NotificationAuthorization
  var grantsRequests: Bool
  private(set) var requestCount = 0
  private(set) var scheduled: [(identifier: String, interval: TimeInterval)] = []
  private(set) var removedIdentifiers: [String] = []

  init(status: NotificationAuthorization = .notDetermined, grantsRequests: Bool = true) {
    self.status = status
    self.grantsRequests = grantsRequests
  }

  func authorizationStatus() async -> NotificationAuthorization { status }

  func requestAuthorization() async throws -> Bool {
    requestCount += 1
    if status == .notDetermined { status = grantsRequests ? .authorized : .denied }
    return status == .authorized
  }

  func addRestAlert(identifier: String, title: String, after interval: TimeInterval) {
    scheduled.append((identifier, interval))
  }

  func removeRestAlert(identifier: String) {
    removedIdentifiers.append(identifier)
    scheduled.removeAll { $0.identifier == identifier }
  }
}

@MainActor
struct RestAlertsModelTests {
  private func makeModel(
    status: NotificationAuthorization = .notDetermined, grants: Bool = true, saved: Bool? = nil
  ) -> (RestAlertsModel, FakeNotificationCenter, InMemoryRestAlertsPreferenceStore) {
    let center = FakeNotificationCenter(status: status, grantsRequests: grants)
    let store = InMemoryRestAlertsPreferenceStore(isEnabled: saved)
    return (RestAlertsModel(center: center, store: store), center, store)
  }

  private func settle() async {
    for _ in 0..<20 { await Task.yield() }
  }

  @Test
  func newInstallStartsOffWithoutAskingForPermission() async {
    let (model, center, store) = makeModel()
    await model.load()
    #expect(!model.isEnabled)
    #expect(store.isEnabled == false)
    #expect(center.requestCount == 0)
  }

  @Test
  func firstLaunchTurnsOnWhenNotificationsWereAlreadyAllowed() async {
    let (model, center, store) = makeModel(status: .authorized)
    await model.load()
    #expect(model.isEnabled)
    #expect(store.isEnabled == true)
    #expect(center.requestCount == 0)
  }

  @Test
  func firstLaunchStaysOffWhenNotificationsWereDenied() async {
    let (model, _, _) = makeModel(status: .denied)
    await model.load()
    #expect(!model.isEnabled)
  }

  @Test
  func savedChoiceWinsOverTheNotificationStatus() async {
    let (model, _, _) = makeModel(status: .authorized, saved: false)
    await model.load()
    #expect(!model.isEnabled)
  }

  @Test
  func turningOnAsksForPermissionAndKeepsTheSettingWhenGranted() async {
    let (model, center, store) = makeModel()
    await model.load()
    await model.setEnabled(true)
    #expect(center.requestCount == 1)
    #expect(model.isEnabled)
    #expect(store.isEnabled == true)
    #expect(!model.permissionWasDenied)
  }

  @Test
  func denyingPermissionReturnsTheSettingToOffAndExplainsWhy() async {
    let (model, _, store) = makeModel(grants: false)
    await model.load()
    await model.setEnabled(true)
    #expect(!model.isEnabled)
    #expect(store.isEnabled == false)
    #expect(model.permissionWasDenied)
    #expect(!model.notificationsAreOff)
  }

  @Test
  func startingARestNeverAsksForPermission() async {
    let (model, center, _) = makeModel()
    await model.load()
    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    #expect(center.requestCount == 0)
    #expect(center.scheduled.isEmpty)
  }

  @Test
  func restSchedulesAnAlertOnlyWhenOnAndAuthorized() async {
    let (model, center, _) = makeModel(status: .authorized)
    await model.load()
    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    #expect(center.scheduled.count == 1)
    #expect(center.scheduled[0].identifier == RestAlertsModel.identifier)

    let (off, offCenter, _) = makeModel(status: .authorized, saved: false)
    await off.load()
    off.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    #expect(offCenter.scheduled.isEmpty)
  }

  @Test
  func turningOffDuringARestCancelsItsAlert() async {
    let (model, center, _) = makeModel(status: .authorized)
    await model.load()
    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    await model.setEnabled(false)
    await settle()
    #expect(center.scheduled.isEmpty)
  }

  @Test
  func turningOnDuringARestSchedulesTheRemainingTime() async {
    let (model, center, _) = makeModel()
    await model.load()
    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await model.setEnabled(true)
    await settle()
    #expect(center.scheduled.count == 1)
    #expect(center.scheduled[0].interval > 0 && center.scheduled[0].interval <= 60)
  }

  @Test
  func finishingTheRestRemovesItsAlert() async {
    let (model, center, _) = makeModel(status: .authorized)
    await model.load()
    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    model.restDeadlineChanged(nil)
    await settle()
    #expect(center.scheduled.isEmpty)
  }

  @Test
  func settingStaysOnAndWarnsWhenNotificationsAreOffInIOSSettings() async {
    let (model, center, store) = makeModel(status: .authorized)
    await model.load()
    center.status = .denied
    await model.refreshAuthorization()
    #expect(model.isEnabled)
    #expect(store.isEnabled == true)
    #expect(model.notificationsAreOff)

    model.restDeadlineChanged(Date.now.addingTimeInterval(60))
    await settle()
    #expect(center.scheduled.isEmpty)
    #expect(center.requestCount == 0)

    center.status = .authorized
    await model.refreshAuthorization()
    #expect(!model.notificationsAreOff)
    await settle()
    #expect(center.scheduled.count == 1)
  }
}
