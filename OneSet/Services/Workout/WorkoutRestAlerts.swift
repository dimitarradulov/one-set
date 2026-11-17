import OSLog
import UserNotifications

@MainActor
final class WorkoutRestAlerts: NSObject, UNUserNotificationCenterDelegate {
  nonisolated private static let identifier = "workout.rest.complete"
  private let center = UNUserNotificationCenter.current()
  private let logger = Logger(subsystem: "OneSet", category: "WorkoutRestAlerts")
  private var scheduling: Task<Void, Never>?

  override init() {
    super.init()
    center.delegate = self
  }

  func update(deadline: Date?, canRequestPermission: Bool) {
    scheduling?.cancel()
    center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    guard let deadline, deadline > .now else { return }

    scheduling = Task {
      do {
        if canRequestPermission {
          guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
        } else {
          guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        }

        let remaining = deadline.timeIntervalSinceNow
        guard !Task.isCancelled, remaining > 0 else { return }
        schedule(after: remaining)
      } catch {
        logger.error("Could not request rest alert permission: \(error.localizedDescription)")
      }
    }
  }

  private func schedule(after remaining: TimeInterval) {
    let content = UNMutableNotificationContent()
    content.title = "Rest complete"
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
    let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
    // Submit before yielding so a later timer change can remove this request.
    center.add(request) { [logger] error in
      if let error {
        logger.error("Could not schedule rest alert: \(error.localizedDescription)")
      }
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    notification.request.identifier == Self.identifier ? [.sound] : []
  }
}
