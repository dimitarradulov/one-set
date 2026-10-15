import SwiftUI

struct ExerciseDetailRouteView: View {
  let workout: WorkoutTemplate
  let exerciseID: WorkoutExercise.ID
  var initiallyExpanded = false
  var initiallyShowingHistory = false

  var body: some View {
    Group {
      if let exercise = workout.exercises.first(where: { $0.id == exerciseID }) {
        ExerciseDetailScreen(
          exercise: exercise,
          initiallyExpanded: initiallyExpanded,
          initiallyShowingHistory: initiallyShowingHistory
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
