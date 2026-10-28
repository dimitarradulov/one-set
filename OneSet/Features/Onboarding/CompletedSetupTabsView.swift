import SwiftUI

struct CompletedSetupTabsView: View {
  @Bindable var model: OnboardingModel
  @Bindable var authentication: AuthenticationModel

  var body: some View {
    TabView(selection: $model.selectedMainTab) {
      programTab
        .tabItem { Label("Program", systemImage: "dumbbell") }
        .tag(MainTab.program)
        .accessibilityIdentifier("tab.program")

      NavigationStack {
        ComingSoonScreen(
          title: "History",
          explanation: "Your completed workouts will appear here.",
          identifier: "history"
        )
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
      }
      .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
      .tag(MainTab.history)
      .accessibilityIdentifier("tab.history")

      SettingsNavigationView(model: model, authentication: authentication)
      .tabItem { Label("Settings", systemImage: "gearshape") }
      .tag(MainTab.settings)
      .accessibilityIdentifier("tab.settings")
    }
    #if DEBUG
    .task {
      if ProcessInfo.processInfo.arguments.contains("--ui-main-workout-recording"),
         model.activeWorkoutSession == nil, let accountID = authentication.signedInUser?.id {
        model.startWorkout(programID: "machine-full-body", workoutID: "machine-full-body-workout-a", accountID: accountID)
      }
    }
    #endif
    .tint(OneSetColors.accent)
    .preferredColorScheme(.dark)
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
            activeSession: model.activeWorkoutSession,
            onResumeWorkout: {
              guard let session = model.activeWorkoutSession else { return }
              model.programPath.append(.workoutRecording(session.id))
            },
            currentWeek: model.currentWorkoutWeek(programID: programID),
            completedWorkoutsForWeek: { model.completedWorkoutIDs(programID: programID, week: $0) },
            onPreviewWorkout: { workout in
              model.previewWorkout(programID: programID, workoutID: workout.id)
            }
          )
          .navigationTitle("Program")
          .navigationBarTitleDisplayMode(.large)
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
          day: workoutIndex + 1,
          onStartWorkout: {
            guard let accountID = authentication.signedInUser?.id else { return }
            model.startWorkout(programID: programID, workoutID: workoutID, accountID: accountID)
          }
        )
        .navigationTitle("Workout preview")
        .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
      }
    case .workoutRecording(let sessionID):
      if let session = model.activeWorkoutSession, session.id == sessionID,
         let accountID = authentication.signedInUser?.id {
        WorkoutRecordingScreen(session: session, previousPerformances: model.previousPerformances(for: session)) {
          model.discardActiveWorkout(accountID: accountID)
        } onSaveDraft: { slotID, weight, reps in
          model.saveWorkoutDraft(slotID: slotID, weightInput: weight, repsInput: reps)
        } onComplete: { slotID in
          model.completeWorkoutSet(slotID: slotID)
        } onUpdate: { slotID, weight, reps in
          model.updateWorkoutSet(slotID: slotID, weightInput: weight, repsInput: reps)
        } onUnmark: { slotID in
          model.unmarkWorkoutSet(slotID: slotID)
        } onAdjustRest: { seconds in
          model.adjustWorkoutRest(by: seconds)
        } onSkipRest: {
          model.skipWorkoutRest()
        } onFinish: { note in
          model.finishActiveWorkout(note: note)
        }
      } else {
        ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
      }
    case .recordingExerciseDetail(let sessionID, let slotID):
      if let session = model.activeWorkoutSession, session.id == sessionID {
        RecordingExerciseDetailRouteView(session: session, slotID: slotID)
      } else {
        ContentUnavailableView("Exercise unavailable", systemImage: "dumbbell")
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
