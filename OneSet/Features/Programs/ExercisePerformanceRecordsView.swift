import SwiftUI

struct ExercisePerformanceRecordsView: View {
  var model: ExercisePerformanceModel?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Heaviest weight").font(OneSetTypography.bodyStrong)
          .accessibilityIdentifier("exerciseDetail.heaviestWeight")
        Text(heaviestValue)
          .font(OneSetTypography.display).accessibilityIdentifier("exerciseDetail.heaviestWeightValue")
        Text(model?.heaviest.map { "\($0.reps) reps · \($0.date.formatted(date: .abbreviated, time: .omitted))" } ?? "No recorded sets")
          .font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)
      .overlay(alignment: .bottom) { Rectangle().fill(OneSetColors.border).frame(height: 1) }
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 20) { estimatedMaximum; mostRecentResult }
        VStack(alignment: .leading, spacing: 20) { estimatedMaximum; mostRecentResult }
      }
      Text("An estimate, not a tested single-repetition lift.")
        .font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("exerciseDetail.estimatedOneRepMaxNote")
      if model?.results.isEmpty != false {
        ExercisePerformanceEmptyStateView(titleIdentifier: "exerciseDetail.noRecords",
          explanationIdentifier: "exerciseDetail.noRecordsExplanation")
      }
    }.foregroundStyle(OneSetColors.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
  }

  private var heaviestValue: String {
    guard let model, let result = model.heaviest else { return "-" }
    return model.weight(result.weight)
  }

  private var estimatedValue: String {
    guard let model, let value = model.estimatedMaximum else { return "-" }
    return model.weight(value)
  }

  private var recentValue: String {
    guard let model, let result = model.results.first else { return "-" }
    return "\(model.weight(result.weight)) × \(result.reps)"
  }

  private var estimatedMaximum: some View {
    ExercisePerformanceStatisticView(title: "Estimated one-rep max",
      valueIdentifier: "exerciseDetail.estimatedOneRepMaxValue", titleIdentifier: "exerciseDetail.estimatedOneRepMax",
      note: model?.estimatedMaximum == nil ? "No estimate yet" : "Epley estimate · up to 10 reps",
      value: estimatedValue)
  }

  private var mostRecentResult: some View {
    ExercisePerformanceStatisticView(title: "Most recent result",
      valueIdentifier: "exerciseDetail.mostRecentResultValue", titleIdentifier: "exerciseDetail.mostRecentResult",
      note: model?.results.first.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "No recorded sets yet",
      value: recentValue)
  }
}
