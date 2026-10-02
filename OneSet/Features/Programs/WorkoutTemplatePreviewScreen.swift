import SwiftUI

struct WorkoutTemplatePreviewScreen: View {
  let program: TrainingProgram
  let workout: WorkoutTemplate
  let day: Int

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Day \(day)")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textSecondary)

          Text(workout.name)
            .font(OneSetTypography.h1)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("workoutPreview.title")

          Text(program.name)
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("workoutPreview.program")
        }

        Label("Read-only template preview", systemImage: "doc.text.magnifyingglass")
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(OneSetColors.border, lineWidth: 1)
          }
          .accessibilityLabel("Read-only template preview. No workout has started.")
          .accessibilityIdentifier("workoutPreview.readOnly")

        VStack(alignment: .leading, spacing: 12) {
          Text("Exercise order and rep targets")
            .font(OneSetTypography.h2)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityAddTraits(.isHeader)

          ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
            exerciseRow(exercise, order: index + 1)
          }
        }

        Text("No workout has started.")
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityIdentifier("workoutPreview.notStarted")
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.hidden)
    .background(OneSetColors.background)
  }

  private func exerciseRow(_ exercise: WorkoutExercise, order: Int) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(String(format: "%02d", order))
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.name)
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("workoutPreview.exercise.\(order).name")

        Text(exercise.repTarget.label)
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityIdentifier("workoutPreview.exercise.\(order).reps")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(OneSetColors.border)
        .frame(height: 1)
        .accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("workoutPreview.exercise.\(order)")
  }
}
