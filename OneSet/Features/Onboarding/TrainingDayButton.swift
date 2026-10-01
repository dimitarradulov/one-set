import SwiftUI

struct TrainingDayButton: View {
  let days: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Text("\(days)")
          .font(OneSetTypography.metric)
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .accessibilityHidden(true)
        }
      }
      .foregroundStyle(isSelected ? Color.black : OneSetColors.textPrimary)
      .frame(maxWidth: .infinity, minHeight: 58)
      .background(
        isSelected ? OneSetColors.accent : OneSetColors.surface,
        in: RoundedRectangle(cornerRadius: 12)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(isSelected ? Color.white.opacity(0.65) : OneSetColors.border, lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(days) training days per week")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("preferences.days.\(days)")
  }
}
