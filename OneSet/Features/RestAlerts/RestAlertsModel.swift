import Foundation
import OSLog

/// Owns the device-local rest alerts setting, the permission flow and rest alert scheduling.
@MainActor @Observable
final class RestAlertsModel {
  nonisolated static let identifier = "workout.rest.complete"

  private(set) var isEnabled = false
  private(set) var authorization: NotificationAuthorization = .notDetermined
  /// True after turning the setting on was refused, until the lifter tries again or leaves.
  private(set) var permissionWasDenied = false

  /// The setting is on but iOS will not deliver alerts.
  var notificationsAreOff: Bool { isEnabled && authorization == .denied }

  @ObservationIgnored private let center: any NotificationCentering
  @ObservationIgnored private let store: any RestAlertsPreferenceStore
  @ObservationIgnored private let logger = Logger(subsystem: "OneSet", category: "RestAlerts")
  @ObservationIgnored private var restDeadline: Date?
  @ObservationIgnored private var scheduling: Task<Void, Never>?

  init(center: any NotificationCentering, store: any RestAlertsPreferenceStore) {
    self.center = center
    self.store = store
    isEnabled = store.isEnabled ?? false
  }

  /// Reads the saved choice. The first launch with this setting turns it on only for lifters who
  /// already allowed notifications, so they keep their alerts.
  func load() async {
    authorization = await center.authorizationStatus()
    if let saved = store.isEnabled {
      isEnabled = saved
    } else {
      isEnabled = authorization == .authorized
      store.isEnabled = isEnabled
    }
    reschedule()
  }

  /// Re-reads the iOS permission, for example after the lifter returns from iOS Settings.
  func refreshAuthorization() async {
    authorization = await center.authorizationStatus()
    reschedule()
  }

  func setEnabled(_ enabled: Bool) async {
    permissionWasDenied = false
    guard enabled else {
      disable()
      reschedule()
      return
    }
    do {
      let granted = try await center.requestAuthorization()
      authorization = await center.authorizationStatus()
      if granted {
        isEnabled = true
        store.isEnabled = true
      } else {
        disable()
        permissionWasDenied = true
      }
    } catch {
      logger.error("Could not request rest alert permission: \(error.localizedDescription)")
      disable()
      permissionWasDenied = true
    }
    reschedule()
  }

  private func disable() {
    isEnabled = false
    store.isEnabled = false
  }

  /// Called when the active rest changes. Never asks for permission.
  func restDeadlineChanged(_ deadline: Date?) {
    restDeadline = deadline
    reschedule()
  }

  private func reschedule() {
    scheduling?.cancel()
    center.removeRestAlert(identifier: Self.identifier)
    guard isEnabled, let deadline = restDeadline, deadline > .now else { return }

    scheduling = Task {
      guard await center.authorizationStatus() == .authorized else { return }
      let remaining = deadline.timeIntervalSinceNow
      guard !Task.isCancelled, remaining > 0 else { return }
      // Submit before yielding so a later change can remove this request.
      center.addRestAlert(identifier: Self.identifier, title: "Rest complete", after: remaining)
    }
  }
}
