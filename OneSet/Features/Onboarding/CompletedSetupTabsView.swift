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

      Group {
        if let accountID = authentication.signedInUser?.id {
          let arguments = ProcessInfo.processInfo.arguments
          let initialSessionID = arguments.contains("--ui-history-partial-detail")
            ? UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb") : nil
          HistoryScreen(
            accountID: accountID,
            displayUnit: model.weightUnit,
            isActive: model.selectedMainTab == .history,
            initialSessionID: initialSessionID,
            loadSessions: {
              if arguments.contains("--ui-history-error") { throw HistoryDataError.storageUnavailable }
              return try model.completedHistorySessions(accountID: $0)
            },
            resolveProgramName: { model.programName(id: $0) },
            loadCoverage: { try model.completedHistoryCoverage(accountID: $0) },
            savePage: { try model.saveCompletedHistoryPage($0, accountID: $1) },
            fetchPage: model.canRefreshAccountHistory ? { cursor in
              try await model.fetchHistoryPage(accountID: accountID, cursor: cursor, using: authentication)
            } : nil,
            isAccountCurrent: { authentication.signedInUser?.id == accountID }
          )
          .id(accountID)
        } else {
          ContentUnavailableView("History unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
            .background(OneSetColors.background)
        }
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
            updateMessage: model.requiresProgramUpdate
              ? (model.programUpdateMessage ?? "Your program changed on another device. Update to start new workouts.") : nil,
            onUpdate: { Task { await model.updateRemoteProgram(using: authentication) } },
            uploadMessage: model.cycleConflictMessage ?? model.cycleMessage ?? model.uploadMessage,
            onRetryUpload: model.cycleConflictMessage == nil ? { Task {
              await model.uploadCompletedSetup(using: authentication)
              await model.uploadPendingCycles(using: authentication)
            } } : nil,
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
          .id(programID)
          .navigationTitle("Program")
          .navigationBarTitleDisplayMode(.large)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Switch") {
                model.showProgramSwitcher()
                Task { await model.refreshCycleKnowledge(using: authentication) }
              }
                .accessibilityIdentifier("overview.switch")
            }
          }
        } else {
          ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
            .background(OneSetColors.background)
            .navigationTitle("Program")
        }
      }
      .navigationDestination(for: OnboardingRoute.self, destination: programDestination)
    }
    .alert("Finish your workout first", isPresented: $model.switchBlockedPresented) {
      Button("Return to workout", action: model.returnToActiveWorkout)
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Finish or discard your current workout before switching programs.")
    }
  }

  private func hasFollowedProgram(_ programID: String) -> Bool {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--ui-switch-resume-detail") { return true }
    #endif
    return model.hasFollowedProgram(programID)
  }

  @ViewBuilder
  private func programDestination(for route: OnboardingRoute) -> some View {
    switch route {
    case .programs:
      ProgramSelectionScreen(programs: model.programs, trainingDays: model.trainingDays,
        selectedProgramID: model.selectedProgramID, switching: true)
        .navigationTitle("Programs")
        .navigationBarTitleDisplayMode(.inline)
    case .programDetail(let programID):
      if let program = model.program(id: programID), program.isOffered {
        ProgramDetailScreen(program: program, isSelected: model.selectedProgramID == programID,
          onSelect: { model.switchToProgram(programID, using: authentication) }, switching: true, previouslyFollowed: hasFollowedProgram(programID), onPreviewWorkout: { workout in
            model.programPath.append(.switchingWorkoutPreview(programID: programID, workoutID: workout.id))
          })
          .navigationTitle(program.name)
          .navigationBarTitleDisplayMode(.inline)
          .alert("Program switch", isPresented: Binding(
            get: { model.cycleMessage != nil },
            set: { if !$0 { model.clearCycleMessage() } }
          )) {
            Button("Retry") { Task {
              await model.refreshCycleKnowledge(using: authentication)
              model.switchToProgram(programID, using: authentication)
            } }
            Button("OK", role: .cancel) { model.clearCycleMessage() }
          } message: { Text(model.cycleMessage ?? "") }
      } else {
        ContentUnavailableView("Program unavailable", systemImage: "dumbbell")
      }
    case .switchingWorkoutPreview(let programID, let workoutID):
      if let program = model.program(id: programID),
         let workoutIndex = program.workouts.firstIndex(where: { $0.id == workoutID }) {
        WorkoutTemplatePreviewScreen(program: program, workout: program.workouts[workoutIndex],
          day: workoutIndex + 1, onStartWorkout: {}, isBrowsingProgram: true)
          .navigationTitle("Workout preview")
          .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
      }
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
          },
          requiresProgramUpdate: model.requiresProgramUpdate
        )
        .navigationTitle("Workout preview")
        .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView("Workout unavailable", systemImage: "dumbbell")
      }
    case .workoutRecording(let sessionID):
      if let session = model.activeWorkoutSession, session.id == sessionID,
         let accountID = authentication.signedInUser?.id {
        WorkoutRecordingScreen(session: session, previousPerformances: model.previousPerformances(for: session),
          previousPerformanceUnavailable: model.previousPerformanceUnavailable,
          onRetryPreviousPerformance: { Task { await model.retryPreviousPerformances(using: authentication) } }) {
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
          model.finishActiveWorkout(note: note, using: authentication)
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
