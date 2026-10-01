import SwiftUI

struct UnitChoiceButton: View {
  let unit: WeightUnit
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(unit.rawValue)
          .font(OneSetTypography.metric)
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .accessibilityHidden(true)
        }
      }
      .foregroundStyle(isSelected ? Color.black : OneSetColors.textPrimary)
      .frame(maxWidth: .infinity, minHeight: 52)
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
    .accessibilityLabel(unit == .kilograms ? "Kilograms" : "Pounds")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("preferences.unit.\(unit.rawValue)")
  }
}
