import SwiftUI

struct ProgramOverviewScreen: View {
  let program: TrainingProgram
  var uploadMessage: String? = nil
  var onRetryUpload: (() -> Void)? = nil
  var preferencesSummary: String? = nil
  let onPreviewWorkout: (WorkoutTemplate) -> Void
  @State private var selectedWeek = 1

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text(program.name)
            .font(OneSetTypography.h1)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("overview.title")

          Text("\(program.trainingDaysPerWeek) days per week · \(program.workoutCountLabel)")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("overview.frequency")
          if let preferencesSummary {
            Text(preferencesSummary)
              .font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("overview.preferences")
          }
        }

        if let uploadMessage {
          VStack(alignment: .leading, spacing: 8) {
            Text(uploadMessage)
              .font(OneSetTypography.body)
              .foregroundStyle(OneSetColors.textSecondary)
              .accessibilityIdentifier("setup.uploadStatus")
            if let onRetryUpload {
              Button("Retry upload", action: onRetryUpload)
                .accessibilityIdentifier("setup.retryUpload")
            }
          }
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Recommended training weeks")
            .font(OneSetTypography.h2)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityAddTraits(.isHeader)

          Text("A training week is one rotation through these days, not a calendar week.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

          ScrollView(.horizontal) {
            HStack(spacing: 8) {
              ForEach(1...8, id: \.self) { week in
                Button {
                  selectedWeek = week
                } label: {
                  Text("\(week)")
                    .font(OneSetTypography.label)
                    .foregroundStyle(selectedWeek == week ? Color.black : OneSetColors.textPrimary)
                    .frame(minWidth: 48, minHeight: 48)
                    .background(
                      selectedWeek == week ? OneSetColors.accent : OneSetColors.surface,
                      in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                      RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                          selectedWeek == week ? OneSetColors.accent : OneSetColors.border,
                          lineWidth: 1
                        )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Week \(week)")
                .accessibilityAddTraits(selectedWeek == week ? .isSelected : [])
                .accessibilityIdentifier("overview.week.\(week)")
              }
            }
          }
          .scrollIndicators(.hidden)
          .accessibilityLabel("Recommended training weeks")

          Text("Week \(selectedWeek)")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityIdentifier("overview.selectedWeek")
            .padding(.top, 4)
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Training days")
            .font(OneSetTypography.h2)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityAddTraits(.isHeader)

          ForEach(Array(program.workouts.enumerated()), id: \.element.id) { index, workout in
            overviewCard(workout, day: index + 1)
          }
        }
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

  private func overviewCard(_ workout: WorkoutTemplate, day: Int) -> some View {
    Button {
      onPreviewWorkout(workout)
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Text("Day \(day)")
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
          .frame(minWidth: 48, alignment: .leading)

        VStack(alignment: .leading, spacing: 8) {
          Text(workout.name)
            .font(OneSetTypography.bodyStrong)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

          Label("Not started", systemImage: "circle")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textPrimary)
            .accessibilityIdentifier("overview.day.\(day).status")

          Text("\(workout.movements.count) exercises")
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.textSecondary)

          Label("Preview workout template", systemImage: "arrow.right")
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textPrimary)
            .labelStyle(.titleAndIcon)
            .frame(minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(OneSetColors.border, lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Preview Day \(day), \(workout.name), \(workout.movements.count) exercises, Not started")
    .accessibilityHint("Shows the exercise order and rep targets in a read-only preview.")
    .accessibilityIdentifier("overview.day.\(day).preview")
  }
}
