import SwiftUI

struct ExercisePerformanceStatisticView: View {
  let title: String
  let valueIdentifier: String
  let titleIdentifier: String
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier(titleIdentifier)
      Text("—")
        .font(OneSetTypography.metric)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityIdentifier(valueIdentifier)
      Text(note)
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
