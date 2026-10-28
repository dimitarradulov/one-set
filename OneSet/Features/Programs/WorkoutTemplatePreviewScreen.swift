import SwiftUI

struct WorkoutTemplatePreviewScreen: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let program: TrainingProgram
  let workout: WorkoutTemplate
  let day: Int
  let onStartWorkout: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        WorkoutBanner(program: program, workout: workout, day: day)

        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Label {
              Text("\(workout.exercises.count) exercises · 1 working set each")
            } icon: {
              Image(systemName: "list.number")
                .accessibilityHidden(true)
            }
            .font(OneSetTypography.label)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("workoutPreview.summary")

            Label("Read-only template preview", systemImage: "doc.text.magnifyingglass")
              .font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
              .overlay {
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(OneSetColors.border, lineWidth: 1)
              }
              .accessibilityLabel("Read-only template preview. No workout has started.")
              .accessibilityIdentifier("workoutPreview.readOnly")
          }

          VStack(alignment: .leading, spacing: 12) {
            sectionHeading

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
              NavigationLink(value: OnboardingRoute.exerciseDetail(
                programID: program.id,
                workoutID: workout.id,
                exerciseID: exercise.id
              )) {
                exerciseRow(exercise, order: index + 1)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(exercise.name), \(exercise.repTarget.label)")
              .accessibilityHint("Opens exercise instructions and warmup guidance.")
              .accessibilityIdentifier("workoutPreview.exercise.\(exercise.id).open")
            }
          }

          Text("No workout has started.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .accessibilityIdentifier("workoutPreview.notStarted")
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .scrollIndicators(.hidden)
    .background(OneSetColors.background)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Button {
        onStartWorkout()
      } label: {
        Text("Start workout")
          .font(OneSetTypography.button)
          .foregroundStyle(Color.black)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
          .contentShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("workoutPreview.start")
      .frame(maxWidth: 720)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(OneSetColors.background)
    }
  }

  private var sectionHeading: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 2) {
          exerciseOrderHeading
          repTargetsHeading
        }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          exerciseOrderHeading
          Spacer(minLength: 4)
          repTargetsHeading
            .multilineTextAlignment(.trailing)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var exerciseOrderHeading: some View {
    Text("Exercise order")
      .font(OneSetTypography.h2)
      .foregroundStyle(OneSetColors.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
      .accessibilityIdentifier("workoutPreview.exerciseOrderHeading")
  }

  private var repTargetsHeading: some View {
    Text("Rep targets")
      .font(OneSetTypography.caption)
      .foregroundStyle(OneSetColors.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("workoutPreview.repTargetsHeading")
  }

  private func exerciseRow(_ exercise: WorkoutExercise, order: Int) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(String(format: "%02d", order))
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.name)
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("workoutPreview.exercise.\(order).name")

        Text(exercise.repTarget.label)
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityIdentifier("workoutPreview.exercise.\(order).reps")
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(OneSetColors.textSecondary)
        .frame(minWidth: 44, minHeight: 44, alignment: .center)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(OneSetColors.border)
        .frame(height: 1)
        .accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
  }
}
