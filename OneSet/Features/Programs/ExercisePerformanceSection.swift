import SwiftUI

struct ExercisePerformanceSection: View {
  @State private var showingHistory: Bool
  @State private var model: ExercisePerformanceModel?

  init(initiallyShowingHistory: Bool = false, model: ExercisePerformanceModel? = nil) {
    _showingHistory = State(initialValue: initiallyShowingHistory)
    _model = State(initialValue: model)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Your performance")
        .font(OneSetTypography.h2).foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)
      Text("Across programs")
        .font(OneSetTypography.label).foregroundStyle(OneSetColors.textSecondary)
        .accessibilityIdentifier("exerciseDetail.performanceScope")
      HStack(spacing: 8) {
        ExercisePerformanceTabButton(title: "Records", isSelected: !showingHistory,
          identifier: "exerciseDetail.recordsTab", action: { showingHistory = false })
        ExercisePerformanceTabButton(title: "History", isSelected: showingHistory,
          identifier: "exerciseDetail.historyTab", action: { showingHistory = true })
      }.padding(.bottom, 4)
      if let model {
        if model.isLoading && model.results.isEmpty {
          ProgressView("Loading performance…")
        } else if model.error != nil && model.results.isEmpty {
          Text("Performance couldn’t be loaded.").font(OneSetTypography.bodyStrong)
        } else if showingHistory {
          ExercisePerformanceHistoryView(model: model)
        } else {
          ExercisePerformanceRecordsView(model: model)
        }
        if let error = model.error {
          Text(error).font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
          Button("Try again") { Task { await model.reload() } }
        }
      } else if showingHistory {
        ExercisePerformanceHistoryView()
      } else {
        ExercisePerformanceRecordsView()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task { await model?.reload() }
  }
}
