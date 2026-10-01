import SwiftUI

struct ProgramCard: View {
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

