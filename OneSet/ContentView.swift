import SwiftUI

struct ContentView: View {
  @State private var path: [OnboardingRoute] = []
  @State private var weightUnit: WeightUnit = .kilograms
  @State private var trainingDays = 3
  @State private var preferenceMessage: String?

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-welcome") {
      _path = State(initialValue: [])
    } else if arguments.contains("--ui-preferences") {
      _path = State(initialValue: [.preferences])
    } else if arguments.contains("--ui-login") {
      _path = State(initialValue: [.login])
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      WelcomeScreen(
        onContinue: showPreferences,
        onLogIn: showMockLogin
      )
      .navigationTitle("Welcome")
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: OnboardingRoute.self) { route in
        switch route {
        case .preferences:
          TrainingPreferencesScreen(
            weightUnit: $weightUnit,
            trainingDays: $trainingDays,
            message: $preferenceMessage,
            onUnitChanged: clearPreferenceMessage,
            onDaysChanged: clearPreferenceMessage
          )
          .toolbar {
            ToolbarItem(placement: .principal) {
              ProgressPips()
                .accessibilityLabel("Training preferences, step 1 of 4")
            }
          }
          .toolbarTitleDisplayMode(.inline)
          .toolbar(.visible, for: .navigationBar)
        case .login:
          MockLoginScreen()
            .toolbar(.hidden, for: .navigationBar)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func showPreferences() {
    path.append(.preferences)
  }

  private func showMockLogin() {
    path.append(.login)
  }

  private func clearPreferenceMessage() {
    preferenceMessage = nil
  }
}

#Preview {
  ContentView()
}
