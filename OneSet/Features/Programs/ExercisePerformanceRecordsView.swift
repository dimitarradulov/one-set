import SwiftUI

struct ExercisePerformanceRecordsView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Heaviest weight")
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
          .accessibilityIdentifier("exerciseDetail.heaviestWeight")

        Text("—")
          .font(OneSetTypography.display)
          .foregroundStyle(OneSetColors.textPrimary)
          .accessibilityIdentifier("exerciseDetail.heaviestWeightValue")

        Text("No recorded sets")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 16)
      .overlay(alignment: .bottom) {
        Rectangle().fill(OneSetColors.border).frame(height: 1)
      }

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 20) {
          estimatedMaximum
          mostRecentResult
        }
        VStack(alignment: .leading, spacing: 20) {
          estimatedMaximum
          mostRecentResult
        }
      }

      Text("An estimate, not a tested single-repetition lift.")
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("exerciseDetail.estimatedOneRepMaxNote")

      ExercisePerformanceEmptyStateView(
        titleIdentifier: "exerciseDetail.noRecords",
        explanationIdentifier: "exerciseDetail.noRecordsExplanation"
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var estimatedMaximum: some View {
    ExercisePerformanceStatisticView(
      title: "Estimated one-rep max",
      valueIdentifier: "exerciseDetail.estimatedOneRepMaxValue",
      titleIdentifier: "exerciseDetail.estimatedOneRepMax",
      note: "No estimate yet"
    )
  }

  private var mostRecentResult: some View {
    ExercisePerformanceStatisticView(
      title: "Most recent result",
      valueIdentifier: "exerciseDetail.mostRecentResultValue",
      titleIdentifier: "exerciseDetail.mostRecentResult",
      note: "No recorded sets yet"
    )
  }
}
