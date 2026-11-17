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
        .listRowBackground(OneSetColors.surface)

        Section {
          destinationLink(.downloadedVideos)
        } header: {
          Text("Downloads")
            .accessibilityIdentifier("settings.section.downloads")
        }
        .listRowBackground(OneSetColors.surface)

        Section {
          if let emailAddress = authentication.signedInUser?.emailAddress {
            VStack(alignment: .leading, spacing: 4) {
              Text("Signed in as")
                .font(OneSetTypography.label)
                .foregroundStyle(OneSetColors.textSecondary)
              Text(emailAddress)
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.account.email")
            }
          }
          Text("Missing history? Check the address above. Sign out and use the account you used to record those workouts.")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)
            .accessibilityIdentifier("settings.account.historyHelp")
          Button {
            Task { await model.signOut(using: authentication) }
          } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
          }
          .disabled(authentication.isWorking)
          .accessibilityIdentifier("account.signOut")
          destinationLink(.subscription)
          destinationLink(.accountDeletion)
        } header: {
          Text("Account")
            .accessibilityIdentifier("settings.section.account")
        }
        .listRowBackground(OneSetColors.surface)
      }
      .scrollContentBackground(.hidden)
      .background(OneSetColors.background)
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OneSetColors.background)
    .accessibilityIdentifier("settings.destination.comingSoon")
    .navigationTitle(destination.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .tabBar)
  }
}
