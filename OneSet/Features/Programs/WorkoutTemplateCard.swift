import SwiftUI

struct WorkoutTemplateCard: View {
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
