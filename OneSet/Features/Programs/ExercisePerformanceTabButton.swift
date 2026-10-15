import SwiftUI

struct ExercisePerformanceTabButton: View {
  let title: String
  let isSelected: Bool
  let identifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .accessibilityHidden(true)
        }
        Text(title)
          .font(OneSetTypography.bodyStrong)
          .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(isSelected ? OneSetColors.textPrimary : OneSetColors.textSecondary)
      .frame(maxWidth: .infinity, minHeight: 48)
      .contentShape(Rectangle())
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(isSelected ? OneSetColors.accent : OneSetColors.border)
          .frame(height: isSelected ? 3 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityHint("Shows the exercise's \(title.lowercased()).")
  }
}
