import SwiftUI
import UIKit

struct RestAlertsScreen: View {
  @Bindable var model: RestAlertsModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL

  var body: some View {
    Form {
      Section {
        Toggle("Rest alerts", isOn: toggleBinding)
          .accessibilityHint("Notifies you on this device when your rest ends. The explanation below has details.")
          .accessibilityIdentifier("restAlerts.toggle")
      } footer: {
        Text("Get a notification on this device when your rest ends. This setting applies to this device only.")
          .accessibilityIdentifier("restAlerts.explanation")
      }
      .listRowBackground(OneSetColors.surface)

      if model.notificationsAreOff {
        Section {
          Text("Notifications are off for OneSet")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityIdentifier("restAlerts.notificationsOff")
          Text("Rest alerts stay on. Allow notifications for OneSet in iOS Settings to receive them.")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)
          Button("Open Settings", action: openSystemSettings)
            .accessibilityIdentifier("restAlerts.openSettings")
        }
        .listRowBackground(OneSetColors.surface)
      } else if model.permissionWasDenied {
        Section {
          Text("Rest alerts need notification permission. Allow notifications for OneSet in iOS Settings, then turn this on again.")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)
            .accessibilityIdentifier("restAlerts.denied")
          Button("Open Settings", action: openSystemSettings)
            .accessibilityIdentifier("restAlerts.openSettings")
        }
        .listRowBackground(OneSetColors.surface)
      }
    }
    .scrollContentBackground(.hidden)
    .background(OneSetColors.background)
    .navigationTitle("Rest alerts")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .tabBar)
    .accessibilityIdentifier("restAlerts.screen")
    .task(id: scenePhase) {
      if scenePhase == .active { await model.refreshAuthorization() }
    }
    .onChange(of: model.permissionWasDenied) { _, denied in
      if denied {
        AccessibilityNotification.Announcement(
          "Rest alerts stay off. Allow notifications for OneSet in iOS Settings, then turn this on again."
        ).post()
      }
    }
    .onChange(of: model.notificationsAreOff) { _, areOff in
      if areOff {
        AccessibilityNotification.Announcement(
          "Notifications are off for OneSet. Rest alerts stay on. Allow notifications in iOS Settings to receive them."
        ).post()
      }
    }
  }

  private var toggleBinding: Binding<Bool> {
    Binding(
      get: { model.isEnabled },
      set: { newValue in Task { await model.setEnabled(newValue) } }
    )
  }

  private func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
  }
}
