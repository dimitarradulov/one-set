import SwiftUI

/// The workout preview used by both routes (setup flow and tabs). It resumes an existing session
/// without a check and routes new starts through the model's subscription gate.
struct WorkoutStartPreviewScreen: View {
  @Bindable var model: OnboardingModel
  let authentication: AuthenticationModel
  let program: TrainingProgram
  let workout: WorkoutTemplate
  let week: Int?

  private var route: OnboardingRoute {
    .workoutPreview(programID: program.id, workoutID: workout.id, week: week)
  }

  private var status: WorkoutStartStatus? {
    guard let gate = model.workoutStartGate, gate.route == route,
          gate.selection == model.currentAccountSelection else { return nil }
    return gate.status
  }

  var body: some View {
    WorkoutTemplatePreviewScreen(
      program: program,
      workout: workout,
      day: program.trainingDay(for: workout),
      onStartWorkout: start,
      isActiveWorkout: isActiveWorkout,
      isBrowsingProgram: week.map { $0 != model.currentWorkoutWeek(programID: program.id) } ?? false,
      requiresProgramUpdate: model.requiresProgramUpdate,
      startStatus: status,
      onSeePlans: { model.presentPlans(for: route) },
      onRetryAccess: { Task { await model.recheckWorkoutAccess(route: route) } }
    )
    #if DEBUG
    .task {
      if ProcessInfo.processInfo.arguments.contains("--ui-main-workout-gated"), model.workoutStartGate == nil {
        start()
      }
    }
    #endif
    .onDisappear { model.clearWorkoutStartGate(for: route) }
    .paywallSheet(model: Binding(
      get: { model.paywallRoute == route ? model.paywall : nil },
      set: { if $0 == nil { model.paywall = nil } }
    ))
  }

  private var isActiveWorkout: Bool {
    model.activeWorkoutSession.map {
      $0.accountID == authentication.signedInUser?.id && $0.programID == program.id
        && $0.workoutID == workout.id && (week == nil || week == $0.week)
    } ?? false
  }

  private func start() {
    guard let accountID = authentication.signedInUser?.id else { return }
    if model.resumeWorkout(programID: program.id, workoutID: workout.id, accountID: accountID, week: week) {
      return
    }
    Task {
      await model.startWorkout(programID: program.id, workoutID: workout.id, accountID: accountID, week: week)
    }
  }
}
