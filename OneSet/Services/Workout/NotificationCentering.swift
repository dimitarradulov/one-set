import Foundation
import OSLog
import UserNotifications

enum NotificationAuthorization: Equatable, Sendable {
  case notDetermined
  case denied
  case authorized
}

/// The notification center operations rest alerts use.
@MainActor
protocol NotificationCentering: AnyObject {
  func authorizationStatus() async -> NotificationAuthorization
  /// Asks iOS for permission. Returns whether alerts are now allowed.
  func requestAuthorization() async throws -> Bool
  /// Submits a one-shot request synchronously so a later removal can find it.
  func addRestAlert(identifier: String, title: String, after interval: TimeInterval)
  func removeRestAlert(identifier: String)
}

/// The system notification center. Presents rest alerts as a sound while OneSet is in the foreground.
@MainActor
final class SystemNotificationCenter: NSObject, NotificationCentering, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let logger = Logger(subsystem: "OneSet", category: "NotificationCenter")

  override init() {
    super.init()
    center.delegate = self
  }

  func authorizationStatus() async -> NotificationAuthorization {
    switch await center.notificationSettings().authorizationStatus {
    case .authorized: .authorized
    case .notDetermined: .notDetermined
    default: .denied
    }
  }

  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }

  func addRestAlert(identifier: String, title: String, after interval: TimeInterval) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    center.add(request) { [logger] error in
      if let error {
        logger.error("Could not schedule rest alert: \(error.localizedDescription)")
      }
    }
  }

  func removeRestAlert(identifier: String) {
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    notification.request.identifier == RestAlertsModel.identifier ? [.sound] : []
  }
}

/// Stands in for the system center in UI tests, which must never show system prompts.
@MainActor
final class InertNotificationCenter: NotificationCentering {
  private var granted = false
  func authorizationStatus() async -> NotificationAuthorization { granted ? .authorized : .notDetermined }
  func requestAuthorization() async throws -> Bool {
    granted = true
    return true
  }
  func addRestAlert(identifier: String, title: String, after interval: TimeInterval) {}
  func removeRestAlert(identifier: String) {}
}
