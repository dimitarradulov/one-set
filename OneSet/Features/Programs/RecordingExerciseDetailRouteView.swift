import SwiftUI

struct RecordingExerciseDetailRouteView: View {
  let session: WorkoutSession
  let slotID: String

  var body: some View {
    Group {
      if let exercise = session.exercises.first(where: { $0.slotID == slotID }) {
        ExerciseDetailScreen(
          exercise: WorkoutExercise(
            id: exercise.slotID,
            exerciseKey: exercise.exerciseKey,
            name: exercise.name,
            repTarget: exercise.repTarget,
            instructions: exercise.instructions,
            stoppingGuidance: exercise.stoppingGuidance,
            warmupGuidance: exercise.warmupGuidance,
            restSeconds: exercise.restSeconds
          ),
          initiallyExpanded: true
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
