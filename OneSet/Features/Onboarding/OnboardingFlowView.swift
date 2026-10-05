import SwiftUI

struct OnboardingFlowView: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel

  var body: some View {
    NavigationStack(path: $model.path) {
      WelcomeScreen(
        onContinue: model.showPreferences,
        onContinueWithEmail: {
          authentication.begin(.continueWithEmail)
          model.showEmailAuthentication()
        },
        onLogIn: {
          authentication.begin(.logIn)
          model.showLogin()
        }
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
        case .trialPreview(let programID):
          if let program = model.program(id: programID) {
            TrialPreviewScreen(program: program, onContinueWithoutTrial: model.continueWithoutTrial)
              .navigationTitle("Trial preview")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                ToolbarItem(placement: .principal) {
                  ProgressPips(currentStep: 3)
                    .accessibilityLabel("Trial preview, step 3 of 4")
                }
              }
          } else {
            ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
          }
        case .programOverview(let programID):
          if let program = model.program(id: programID) {
            ProgramOverviewScreen(
              program: program,
              onPreviewWorkout: { workout in
                model.previewWorkout(programID: programID, workoutID: workout.id)
              }
            )
              .navigationTitle("Program")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                ToolbarItem(placement: .principal) {
                  ProgressPips(currentStep: 4)
                    .accessibilityLabel("Program overview, step 4 of 4")
                }
              }
          } else {
            ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
          }
        case .workoutPreview(let programID, let workoutID):
          if let program = model.program(id: programID),
             let workoutIndex = program.workouts.firstIndex(where: { $0.id == workoutID }) {
            WorkoutTemplatePreviewScreen(
              program: program,
              workout: program.workouts[workoutIndex],
              day: workoutIndex + 1
            )
            .navigationTitle("Workout preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
          } else {
            ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
          }
        case .login:
          LoginScreen(model: authentication)
            .toolbar(.hidden, for: .navigationBar)
        case .emailAuthentication:
          LoginScreen(model: authentication) {
            model.showPreferences()
          }
          .toolbar(.hidden, for: .navigationBar)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

}

#Preview {
  OnboardingFlowView(
    model: OnboardingModel(catalog: .bundled),
    authentication: AuthenticationModel(service: PreviewAuthenticationService())
  )
}
