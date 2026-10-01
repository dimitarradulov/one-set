import SwiftUI

struct ProgramOverviewScreen: View {
  let program: TrainingProgram
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
    VStack(alignment: .leading, spacing: 12) {
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

          DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(workout.movements.enumerated()), id: \.offset) { index, movement in
                HStack(alignment: .top, spacing: 8) {
                  Text(String(format: "%02d", index + 1))
                    .font(OneSetTypography.caption)
                    .foregroundStyle(OneSetColors.textSecondary)
                    .accessibilityHidden(true)

                  Text(movement)
                    .font(OneSetTypography.body)
                    .foregroundStyle(OneSetColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
            .padding(.top, 8)
          } label: {
            Text("Preview exercises")
              .font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.textPrimary)
              .frame(minHeight: 44, alignment: .leading)
              .contentShape(Rectangle())
          }
          .accessibilityIdentifier("overview.day.\(day).preview")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(OneSetColors.border, lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("overview.day.\(day)")
  }
}
