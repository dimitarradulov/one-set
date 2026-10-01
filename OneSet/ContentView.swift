import SwiftUI

struct ContentView: View {
  @State private var path: [OnboardingRoute] = []
  @State private var weightUnit: WeightUnit = .kilograms
  @State private var trainingDays = 3
  @State private var selectedProgram: TrainingProgram?

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-welcome") {
      _path = State(initialValue: [])
    } else if arguments.contains("--ui-preferences") {
      _path = State(initialValue: [.preferences])
    } else if arguments.contains("--ui-login") {
      _path = State(initialValue: [.login])
    } else if arguments.contains("--ui-programs") {
      _path = State(initialValue: [.preferences, .programs])
    } else if arguments.contains("--ui-program-detail") {
      _path = State(initialValue: [.preferences, .programs, .programDetail("machine-full-body")])
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
            onContinue: showPrograms
          )
          .toolbar {
            ToolbarItem(placement: .principal) {
              ProgressPips()
                .accessibilityLabel("Training preferences, step 1 of 4")
            }
          }
          .toolbarTitleDisplayMode(.inline)
          .toolbar(.visible, for: .navigationBar)
        case .programs:
          ProgramSelectionScreen(
            trainingDays: $trainingDays,
            selectedProgram: $selectedProgram,
            onSelect: selectProgram
          )
          .navigationTitle("Programs")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar(.visible, for: .navigationBar)
          .toolbar {
            ToolbarItem(placement: .principal) {
              ProgressPips(currentStep: 2)
                .accessibilityLabel("Program selection, step 2 of 4")
            }
          }
        case .programDetail(let programID):
          if let program = TrainingProgram.all.first(where: { $0.id == programID }) {
            ProgramDetailScreen(
              program: program,
              isSelected: selectedProgram == program,
              onSelect: { selectProgram(program) }
            )
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
              ToolbarItem(placement: .principal) {
                ProgressPips(currentStep: 2)
                  .accessibilityLabel("Program selection, step 2 of 4")
              }
            }
          } else {
            ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
          }
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

  private func showPrograms() {
    path.append(.programs)
  }

  private func selectProgram(_ program: TrainingProgram) {
    selectedProgram = program
    if path.last == .programDetail(program.id) {
      path.removeLast()
    }
  }

}

#Preview {
  ContentView()
}
