import SwiftUI

struct ProgramSelectionScreen: View {
  @Binding var trainingDays: Int
  @Binding var selectedProgram: TrainingProgram?
  let onSelect: (TrainingProgram) -> Void

  private var programs: [TrainingProgram] {
    TrainingProgram.matchingPreferenceFirst(TrainingProgram.all, days: trainingDays)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Choose your program")
            .font(OneSetTypography.h1)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("programs.title")

          Text("All ten programs are available. We’ll put your \(trainingDays)-day matches first.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        VStack(spacing: 8) {
          ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
            ProgramCard(
              program: program,
              position: index + 1,
              isMatch: program.trainingDaysPerWeek == trainingDays,
              isSelected: selectedProgram == program
            )
          }
        }

        Text("Training frequency is a guide. Every program remains open to you.")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 4)
      }
      .frame(maxWidth: 560, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 28)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.hidden)
    .background(OneSetColors.background)
  }
}

private struct ProgramCard: View {
  let program: TrainingProgram
  let position: Int
  let isMatch: Bool
  let isSelected: Bool

  var body: some View {
    NavigationLink(value: OnboardingRoute.programDetail(program.id)) {
      HStack(alignment: .top, spacing: 16) {
        Image(systemName: program.symbol)
          .font(.system(size: 19, weight: .medium))
          .foregroundStyle(isSelected ? OneSetColors.accent : OneSetColors.textSecondary)
          .frame(width: 40, height: 40)
          .background(OneSetColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(program.name)
              .font(OneSetTypography.bodyStrong)
              .foregroundStyle(OneSetColors.textPrimary)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if isSelected {
              Label("Selected", systemImage: "checkmark.circle.fill")
                .font(OneSetTypography.caption)
                .foregroundStyle(OneSetColors.textPrimary)
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("programs.selected.\(program.id)")
            }
          }

          HStack(spacing: 8) {
            Text("\(program.trainingDaysPerWeek) days / week")
            Text("·")
              .accessibilityHidden(true)
            Text(program.workoutCountLabel)
          }
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)

          Text(program.format)
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("programs.format.\(program.id)")

          HStack(spacing: 8) {
            if isMatch {
              Text("Matches your schedule")
                .font(OneSetTypography.caption)
                .foregroundStyle(OneSetColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minHeight: 28)
                .background(OneSetColors.accentSubtle, in: Capsule())
                .accessibilityIdentifier("programs.match.\(program.id)")
            }

            Spacer(minLength: 0)

            Text(String(format: "%02d", position))
              .font(OneSetTypography.caption)
              .foregroundStyle(OneSetColors.textTertiary)
              .accessibilityHidden(true)
          }
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(OneSetColors.textSecondary)
          .frame(minWidth: 24, minHeight: 44)
          .accessibilityHidden(true)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(isSelected ? OneSetColors.accent : OneSetColors.border, lineWidth: isSelected ? 1.5 : 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(program.name), \(program.trainingDaysPerWeek) days per week, \(program.workoutCountLabel)\(isMatch ? ", matches your schedule" : "")\(isSelected ? ", selected" : "")")
    .accessibilityHint(isMatch ? "Matches your preferred training frequency. Opens program details." : "Opens program details.")
    .accessibilityIdentifier("programs.card.\(program.id)")
  }
}

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

private struct WorkoutTemplateCard: View {
  let workout: WorkoutTemplate
  let number: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        Text(String(format: "%02d", number))
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 8) {
          Text(workout.name)
            .font(OneSetTypography.bodyStrong)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

          Text("\(workout.movements.count) exercises · \(workout.summary)")
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
    .accessibilityElement(children: .combine)
  }
}
