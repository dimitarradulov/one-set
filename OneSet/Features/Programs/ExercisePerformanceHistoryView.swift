import SwiftUI

struct ExercisePerformanceHistoryView: View {
  var model: ExercisePerformanceModel?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Past results").font(OneSetTypography.bodyStrong).foregroundStyle(OneSetColors.textPrimary)
        .accessibilityAddTraits(.isHeader)
      if let model, !model.results.isEmpty {
        ForEach(model.results) { result in
          NavigationLink {
            let history = HistoryModel(accountID: result.session.accountID, displayUnit: model.unit,
              loadSessions: { _ in [] }, resolveProgramName: { _ in nil })
            HistorySessionDetailScreen(session: result.session, programName: model.programName(for: result.session),
              displayWeight: { history.formattedWeight($0, in: result.session) },
              completedCount: history.completedExerciseCount(for: result.session), duration: history.duration(for: result.session))
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("\(model.weight(result.weight)) × \(result.reps) reps").font(OneSetTypography.bodyStrong)
                Text("\(result.date.formatted(date: .abbreviated, time: .omitted)) · \(model.programName(for: result.session)) · \(result.session.workoutName)")
                  .font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
              }.frame(maxWidth: .infinity, alignment: .leading)
              Image(systemName: "chevron.right").foregroundStyle(OneSetColors.textSecondary)
                .accessibilityHidden(true)
            }.padding(.vertical, 8)
          }.foregroundStyle(OneSetColors.textPrimary)
        }
      } else {
        ExercisePerformanceEmptyStateView(titleIdentifier: "exerciseDetail.emptyHistory",
          explanationIdentifier: "exerciseDetail.emptyHistoryExplanation")
      }
    }
  }
}
