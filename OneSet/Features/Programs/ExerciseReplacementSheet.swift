import SwiftUI

struct ExerciseReplacementSheet: View {
  let exercise: WorkoutSession.Exercise
  let library: [WorkoutExercise]
  let onSelect: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  private var results: [WorkoutExercise] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return library.filter {
      $0.exerciseKey != exercise.exerciseKey
        && (query.isEmpty || $0.name.localizedStandardContains(query))
    }
  }

  var body: some View {
    NavigationStack {
      List(results, id: \.exerciseKey) { candidate in
        Button {
          onSelect(candidate.exerciseKey)
        } label: {
          Text(candidate.name)
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textPrimary)
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("replacement.exercise.\(candidate.exerciseKey)")
      }
      .overlay {
        if results.isEmpty { ContentUnavailableView.search }
      }
      .searchable(text: $search, prompt: "Search exercises")
      .navigationTitle("Replace exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
