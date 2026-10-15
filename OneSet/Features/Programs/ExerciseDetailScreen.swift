import SwiftUI

struct ExerciseDetailScreen: View {
  let exercise: WorkoutExercise
  var initiallyExpanded = false
  var initiallyShowingHistory = false

  @State private var guidanceExpanded: Bool
  @State private var warmupExpanded: Bool

  init(exercise: WorkoutExercise, initiallyExpanded: Bool = false, initiallyShowingHistory: Bool = false) {
    self.exercise = exercise
    self.initiallyExpanded = initiallyExpanded
    self.initiallyShowingHistory = initiallyShowingHistory
    _guidanceExpanded = State(initialValue: initiallyExpanded)
    _warmupExpanded = State(initialValue: false)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(exercise.name)
          .font(OneSetTypography.h1)
          .foregroundStyle(OneSetColors.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("exerciseDetail.title")

        videoPlaceholder

        VStack(alignment: .leading, spacing: 12) {
          DisclosureGroup(isExpanded: $guidanceExpanded) {
            VStack(alignment: .leading, spacing: 16) {
              Text(exercise.instructions)
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exerciseDetail.techniqueGuidance")

              VStack(alignment: .leading, spacing: 4) {
                Text("When to stop")
                  .font(OneSetTypography.label)
                  .foregroundStyle(OneSetColors.textSecondary)
                Text(exercise.stoppingGuidance)
                  .font(OneSetTypography.body)
                  .foregroundStyle(OneSetColors.textPrimary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(.top, 12)
          } label: {
            Text("Technique and when to stop")
              .font(OneSetTypography.bodyStrong)
              .foregroundStyle(OneSetColors.textPrimary)
              .frame(minHeight: 44, alignment: .leading)
              .accessibilityIdentifier("exerciseDetail.techniqueDisclosure")
          }

          DisclosureGroup(isExpanded: $warmupExpanded) {
            Text(exercise.warmupGuidance)
              .font(OneSetTypography.body)
              .foregroundStyle(OneSetColors.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 12)
              .accessibilityIdentifier("exerciseDetail.warmupGuidance")
          } label: {
            Text("Warmup guidance")
              .font(OneSetTypography.bodyStrong)
              .foregroundStyle(OneSetColors.textPrimary)
              .frame(minHeight: 44, alignment: .leading)
              .accessibilityIdentifier("exerciseDetail.warmupDisclosure")
          }
        }
        .tint(OneSetColors.accent)
        .padding(16)
        .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(OneSetColors.border, lineWidth: 1)
        }

        ExercisePerformanceSection(initiallyShowingHistory: initiallyShowingHistory)
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.hidden)
    .background(OneSetColors.background)
  }

  private var videoPlaceholder: some View {
    VStack(spacing: 12) {
      Image(systemName: "video.slash")
        .font(.system(size: 28, weight: .regular))
        .accessibilityHidden(true)
      Text("Exercise video coming soon")
        .font(OneSetTypography.bodyStrong)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundStyle(OneSetColors.textSecondary)
    .frame(maxWidth: .infinity, minHeight: 176)
    .padding(20)
    .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(OneSetColors.border, lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("exerciseDetail.videoPlaceholder")
  }
}
