import SwiftUI

struct ExerciseDetailRouteView: View {
  let workout: WorkoutTemplate
  let exerciseID: WorkoutExercise.ID
  var model: OnboardingModel? = nil
  var authentication: AuthenticationModel? = nil
  var initiallyExpanded = false
  var initiallyShowingHistory = false

  var body: some View {
    Group {
      if let exercise = workout.exercises.first(where: { $0.id == exerciseID }) {
        ExerciseDetailScreen(
          exercise: exercise,
          initiallyExpanded: initiallyExpanded,
          initiallyShowingHistory: initiallyShowingHistory,
          performance: authentication.flatMap { model?.exercisePerformance(for: exercise.exerciseKey, using: $0) }
        )
      } else {
        ContentUnavailableView("Exercise unavailable", systemImage: "dumbbell")
      }
    }
    .navigationTitle("Exercise")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
  }
}
