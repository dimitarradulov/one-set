import SwiftUI

struct SettingsNavigationView: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel

  var body: some View {
    NavigationStack(path: $model.settingsPath) {
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
    }
  }

  private func destinationLink(_ destination: SettingsDestination) -> some View {
    NavigationLink(value: destination) {
      Label(destination.title, systemImage: destination.symbol)
    }
    .accessibilityIdentifier(destination.accessibilityIdentifier)
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
