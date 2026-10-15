import SwiftUI

struct ExercisePerformanceHistoryView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Past results")
        .font(OneSetTypography.bodyStrong)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)

      ExercisePerformanceEmptyStateView(
        titleIdentifier: "exerciseDetail.emptyHistory",
        explanationIdentifier: "exerciseDetail.emptyHistoryExplanation"
      )
    }
  }
}
