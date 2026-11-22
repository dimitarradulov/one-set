import SwiftUI

struct WorkoutTemplatePreviewScreen: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let program: TrainingProgram
  let workout: WorkoutTemplate
  let day: Int
  let onStartWorkout: () -> Void
  var isActiveWorkout = false
  var isBrowsingProgram = false
  var requiresProgramUpdate = false
  var startStatus: WorkoutStartStatus?
  var onSeePlans: () -> Void = {}
  var onRetryAccess: () -> Void = {}

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        WorkoutBanner(program: program, workout: workout, day: day)

        VStack(alignment: .leading, spacing: 20) {
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

          VStack(alignment: .leading, spacing: 12) {
            sectionHeading

            ForEach(WorkoutExerciseGroup.ordered(workout.exercises, slotID: \.id, supersets: workout.supersets ?? [])) { group in
              let first = group.firstIndex
              if let second = group.secondIndex {
                SupersetRows(spacing: 0) {
                  exerciseLink(workout.exercises[first], index: first)
                  exerciseLink(workout.exercises[second], index: second)
                }
              } else {
                exerciseLink(workout.exercises[first], index: first)
              }
            }
          }
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
      if !isBrowsingProgram {
        footer
      }
    }
  }

  private var footer: some View {
    VStack(spacing: 0) {
      Rectangle().fill(OneSetColors.border).frame(height: 1).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 10) {
        if !isActiveWorkout, let notice = startNotice {
          startNoticeView(notice)
        }
        actionButton
      }
      .frame(maxWidth: 720)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
    }
    .background(OneSetColors.background)
  }

  private struct StartNotice {
    let symbol: String
    let title: String
    let detail: String?
    let tint: Color
  }

  private var startNotice: StartNotice? {
    switch startStatus {
    case .proRequired:
      StartNotice(symbol: "lock", title: "Pro is required to start",
        detail: "You can still preview workouts and view training history.", tint: OneSetColors.accent)
    case .unconfirmed:
      StartNotice(symbol: "exclamationmark.circle", title: "Connect to check Pro access",
        detail: "Reconnect to check your subscription and start a new workout.", tint: OneSetColors.error)
    case .pendingApproval:
      StartNotice(symbol: "clock", title: "Waiting for purchase approval",
        detail: "Check again after Apple approves the purchase.", tint: OneSetColors.accent)
    case .proActive:
      StartNotice(symbol: "checkmark.circle", title: "OneSet Pro is active", detail: nil, tint: OneSetColors.accent)
    case .checking, nil:
      nil
    }
  }

  private func startNoticeView(_ notice: StartNotice) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: notice.symbol)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(notice.tint)
        .frame(width: 20)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(notice.title)
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textPrimary)
        if let detail = notice.detail {
          Text(detail)
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.textSecondary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("workoutPreview.startNotice")
  }

  @ViewBuilder
  private var actionButton: some View {
    if isActiveWorkout {
      actionLabel("Resume workout", identifier: "workoutPreview.start", action: onStartWorkout)
    } else {
      switch startStatus {
      case .checking:
        actionLabel("Checking access…", identifier: "workoutPreview.start", showsSpinner: true, action: {})
          .disabled(true)
          .accessibilityHint("Checking whether OneSet Pro is active.")
      case .proRequired:
        actionLabel("See plans", identifier: "workoutPreview.seePlans", action: onSeePlans)
      case .unconfirmed:
        actionLabel("Try Again", identifier: "workoutPreview.retryAccess", action: onRetryAccess)
      case .pendingApproval:
        actionLabel("Check status", identifier: "workoutPreview.retryAccess", action: onRetryAccess)
      case .proActive, nil:
        actionLabel("Start workout", identifier: "workoutPreview.start", action: onStartWorkout)
          .disabled(requiresProgramUpdate)
          .accessibilityHint(requiresProgramUpdate ? "Update your program before starting a workout." : "")
      }
    }
  }

  private func actionLabel(_ title: String, identifier: String, showsSpinner: Bool = false,
                           action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if showsSpinner {
          ProgressView().tint(.black).accessibilityHidden(true)
        }
        Text(title)
      }
      .font(OneSetTypography.button)
      .foregroundStyle(Color.black)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
      .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
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

  private func exerciseLink(_ exercise: WorkoutExercise, index: Int) -> some View {
    NavigationLink(value: OnboardingRoute.exerciseDetail(
      programID: program.id, workoutID: workout.id, exerciseID: exercise.id
    )) {
      exerciseRow(exercise, order: index + 1)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(exercise.name), \(exercise.repTarget.label)")
    .accessibilityHint("Opens exercise instructions, video, and performance.")
    .accessibilityIdentifier("workoutPreview.exercise.\(exercise.id).open")
    .overlay(alignment: .bottom) {
      Rectangle().fill(OneSetColors.border).frame(height: 1).accessibilityHidden(true)
    }
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
    .accessibilityElement(children: .contain)
  }
}
