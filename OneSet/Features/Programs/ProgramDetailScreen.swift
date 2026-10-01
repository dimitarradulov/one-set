import SwiftUI

struct ProgramDetailScreen: View {
  let program: TrainingProgram
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Text(program.name)
              .font(OneSetTypography.h1)
              .foregroundStyle(OneSetColors.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityAddTraits(.isHeader)
              .accessibilityIdentifier("program.detail.title")

            VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                Label("\(program.trainingDaysPerWeek) days per week", systemImage: "calendar")
                Text("·")
                  .accessibilityHidden(true)
                Text(program.workoutCountLabel)
              }
              .font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.textSecondary)

              Text("Format")
                .font(OneSetTypography.label)
                .foregroundStyle(OneSetColors.textPrimary)

              Text(program.format)
                .font(OneSetTypography.bodyStrong)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("program.detail.format")

              Text(program.emphasis)
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .accessibilityIdentifier("program.detail.emphasis")
            }

            VStack(alignment: .leading, spacing: 12) {
              Text("Workout templates")
                .font(OneSetTypography.h2)
                .foregroundStyle(OneSetColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

              ForEach(Array(program.workouts.enumerated()), id: \.element.id) { index, workout in
                WorkoutTemplateCard(workout: workout, number: index + 1)
              }
            }
          }
          .frame(maxWidth: 560, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 24)
          .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)

        Button(action: onSelect) {
          HStack(spacing: 8) {
            if isSelected {
              Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true)
            }
            Text(isSelected ? "Selected program" : "Select program")
          }
          .font(OneSetTypography.button)
          .foregroundStyle(Color.black)
          .frame(maxWidth: 560, minHeight: 52)
          .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
          .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.detail.select")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
        .frame(maxWidth: .infinity)
        .background(OneSetColors.background)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(OneSetColors.background)
    }
  }
}

