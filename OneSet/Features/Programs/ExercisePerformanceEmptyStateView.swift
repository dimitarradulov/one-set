import SwiftUI

struct ExercisePerformanceEmptyStateView: View {
  let titleIdentifier: String
  let explanationIdentifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("No recorded sets yet")
        .font(OneSetTypography.bodyStrong)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityIdentifier(titleIdentifier)
      Text("Record this exercise to see your results here.")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(explanationIdentifier)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(OneSetColors.border, lineWidth: 1)
    }
  }
}
