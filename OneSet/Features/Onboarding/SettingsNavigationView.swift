import SwiftUI

struct SettingsNavigationView: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel
  @State private var path: [SettingsDestination] = []

  var body: some View {
    NavigationStack(path: $path) {
      Form {
        Section {
          destinationLink(.units)
          destinationLink(.trainingFrequency)
          destinationLink(.restAlerts)
        } header: {
          Text("Training")
            .accessibilityIdentifier("settings.section.training")
        }

        Section {
          destinationLink(.downloadedVideos)
        } header: {
          Text("Downloads")
            .accessibilityIdentifier("settings.section.downloads")
        }

        Section {
          destinationLink(.subscription)
          destinationLink(.accountDeletion)
          Button {
            Task { await model.signOut(using: authentication) }
          } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
          }
          .disabled(authentication.isWorking)
          .accessibilityIdentifier("account.signOut")
        } header: {
          Text("Account")
            .accessibilityIdentifier("settings.section.account")
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .navigationDestination(for: SettingsDestination.self) { destination in
        SettingsDestinationScreen(destination: destination)
      }
      .onAppear(perform: configureDevelopmentRoute)
    }
  }

  private func destinationLink(_ destination: SettingsDestination) -> some View {
    NavigationLink(value: destination) {
      Label(destination.title, systemImage: destination.symbol)
    }
    .accessibilityIdentifier(destination.accessibilityIdentifier)
  }

  private func configureDevelopmentRoute() {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--ui-main-settings-units") {
      path = [.units]
    }
    #endif
  }
}

private enum SettingsDestination: String, Hashable {
  case units
  case trainingFrequency
  case restAlerts
  case downloadedVideos
  case subscription
  case accountDeletion

  var title: String {
    switch self {
    case .units: "Units"
    case .trainingFrequency: "Training frequency"
    case .restAlerts: "Rest alerts"
    case .downloadedVideos: "Downloaded videos"
    case .subscription: "Subscription"
    case .accountDeletion: "Account deletion"
    }
  }

  var explanation: String {
    switch self {
    case .units: "Unit preferences are coming soon."
    case .trainingFrequency: "Training frequency settings are coming soon."
    case .restAlerts: "Rest alert settings are coming soon."
    case .downloadedVideos: "Video downloads are coming soon."
    case .subscription: "Subscription management is coming soon."
    case .accountDeletion: "Account deletion is coming soon."
    }
  }

  var symbol: String {
    switch self {
    case .units: "scalemass"
    case .trainingFrequency: "calendar"
    case .restAlerts: "timer"
    case .downloadedVideos: "arrow.down.circle"
    case .subscription: "creditcard"
    case .accountDeletion: "person.crop.circle.badge.xmark"
    }
  }

  var accessibilityIdentifier: String {
    "settings.row.\(rawValue)"
  }
}

private struct SettingsDestinationScreen: View {
  let destination: SettingsDestination

  var body: some View {
    ContentUnavailableView {
      Label("Coming soon", systemImage: destination.symbol)
    } description: {
      Text(destination.explanation)
        .accessibilityIdentifier("settings.destination.explanation")
    }
    .accessibilityIdentifier("settings.destination.comingSoon")
    .navigationTitle(destination.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .tabBar)
  }
}
