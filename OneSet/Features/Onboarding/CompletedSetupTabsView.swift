import SwiftUI

struct CompletedSetupTabsView: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel
  @State private var selectedTab: MainTab = .program
  @State private var didConfigureDevelopmentRoute = false

  var body: some View {
    TabView(selection: $selectedTab) {
      programTab
        .tabItem { Label("Program", systemImage: "dumbbell") }
        .tag(MainTab.program)
        .accessibilityIdentifier("tab.program")

      NavigationStack {
        ComingSoonScreen(
          title: "History",
          explanation: "Chronological session history is coming soon.",
          identifier: "history"
        )
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
      }
      .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
      .tag(MainTab.history)
      .accessibilityIdentifier("tab.history")

      NavigationStack {
        ComingSoonScreen(
          title: "Settings",
          explanation: "Settings are coming soon.",
          identifier: "settings"
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
      }
      .tabItem { Label("Settings", systemImage: "gearshape") }
      .tag(MainTab.settings)
      .accessibilityIdentifier("tab.settings")
    }
    .tint(OneSetColors.accent)
    .preferredColorScheme(.dark)
    .onAppear(perform: configureDevelopmentRoute)
  }

  private func configureDevelopmentRoute() {
    #if DEBUG
    guard !didConfigureDevelopmentRoute else { return }
    didConfigureDevelopmentRoute = true
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-main-history") {
      selectedTab = .history
    } else if arguments.contains("--ui-main-settings") {
      selectedTab = .settings
    }
    if arguments.contains("--ui-main-workout-preview") {
      model.programPath = [.workoutPreview(
        programID: "machine-full-body", workoutID: "machine-full-body-workout-a"
      )]
    } else if arguments.contains("--ui-main-exercise-detail") {
      model.programPath = [
        .workoutPreview(programID: "machine-full-body", workoutID: "machine-full-body-workout-a"),
        .exerciseDetail(
          programID: "machine-full-body",
          workoutID: "machine-full-body-workout-a",
          exerciseID: "machine-full-body-workout-a-hack-squat-machine"
        )
      ]
    }
    #endif
  }

  @ViewBuilder
  private var programTab: some View {
    NavigationStack(path: $model.programPath) {
      Group {
        if let programID = model.selectedProgramID, let program = model.program(id: programID) {
          ProgramOverviewScreen(
            program: program,
            uploadMessage: model.uploadMessage,
            onRetryUpload: { Task { await model.uploadCompletedSetup(using: authentication) } },
            preferencesSummary: "Your preferences: \(model.weightUnit.rawValue) · \(model.trainingDays) training days per week",
            onPreviewWorkout: { workout in
              model.previewWorkout(programID: programID, workoutID: workout.id)
            }
          )
          .navigationTitle("Program")
          .navigationBarTitleDisplayMode(.large)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Sign out") {
                Task { await model.signOut(using: authentication) }
              }
              .disabled(authentication.isWorking)
              .accessibilityIdentifier("account.signOut")
            }
          }
        } else {
          ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
            .navigationTitle("Program")
        }
      }
      .navigationDestination(for: OnboardingRoute.self, destination: programDestination)
    }
  }

  @ViewBuilder
  private func programDestination(for route: OnboardingRoute) -> some View {
    switch route {
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
      } else {
        ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
      }
    case .exerciseDetail(let programID, let workoutID, let exerciseID, let guidanceExpanded, let initiallyShowingHistory):
      if let program = model.program(id: programID),
         let workout = program.workouts.first(where: { $0.id == workoutID }) {
        ExerciseDetailRouteView(
          workout: workout,
          exerciseID: exerciseID,
          initiallyExpanded: guidanceExpanded,
          initiallyShowingHistory: initiallyShowingHistory
        )
      } else {
        ContentUnavailableView("Exercise unavailable", systemImage: "dumbbell")
      }
    default:
      ContentUnavailableView("Page unavailable", systemImage: "dumbbell")
    }
  }
}

private enum MainTab: Hashable {
  case program
  case history
  case settings
}

private struct ComingSoonScreen: View {
  let title: String
  let explanation: String
  let identifier: String

  var body: some View {
    ContentUnavailableView {
      Label("Coming soon", systemImage: title == "History" ? "clock.arrow.circlepath" : "gearshape")
    } description: {
      Text(explanation)
    }
    .accessibilityIdentifier("\(identifier).comingSoon")
  }
}
