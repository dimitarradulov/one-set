import SwiftUI

struct ExercisePerformanceSection: View {
  var initiallyShowingHistory = false

  @State private var showingHistory: Bool

  init(initiallyShowingHistory: Bool = false) {
    self.initiallyShowingHistory = initiallyShowingHistory
    _showingHistory = State(initialValue: initiallyShowingHistory)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Your performance")
        .font(OneSetTypography.h2)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)

      Text("Across programs")
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityIdentifier("exerciseDetail.performanceScope")

      HStack(spacing: 8) {
        ExercisePerformanceTabButton(
          title: "Records",
          isSelected: !showingHistory,
          identifier: "exerciseDetail.recordsTab",
          action: showRecords
        )
        ExercisePerformanceTabButton(
          title: "History",
          isSelected: showingHistory,
          identifier: "exerciseDetail.historyTab",
          action: showHistory
        )
      }
      .padding(.bottom, 4)

      if showingHistory {
        ExercisePerformanceHistoryView()
      } else {
        ExercisePerformanceRecordsView()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func showRecords() {
    showingHistory = false
  }

  private func showHistory() {
    showingHistory = true
  }
}
