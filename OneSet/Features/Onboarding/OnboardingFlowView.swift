import SwiftUI

struct OnboardingFlowView: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    NavigationStack(path: $model.path) {
      WelcomeScreen(
        onContinue: model.showPreferences,
        onLogIn: model.showLogin
      )
      .navigationTitle("Welcome")
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: OnboardingRoute.self) { route in
        switch route {
        case .preferences:
          TrainingPreferencesScreen(
            weightUnit: $model.weightUnit,
            trainingDays: $model.trainingDays,
            onContinue: model.showPrograms
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
            programs: model.programs,
            trainingDays: model.trainingDays,
            selectedProgramID: model.selectedProgramID
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
          if let program = model.program(id: programID) {
            ProgramDetailScreen(
              program: program,
              isSelected: model.selectedProgramID == program.id,
              onSelect: { model.selectProgram(program.id) }
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

}

#Preview {
  OnboardingFlowView(model: OnboardingModel(catalog: .bundled))
}
