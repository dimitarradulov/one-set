import SwiftUI

struct WorkoutRecordingScreen: View {
  let session: WorkoutSession
  let onDiscard: () -> Void
  @State private var confirmsDiscard = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Week \(session.week) · Day \(session.day)")
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
        Text("Your workout is saved on this device. You can leave and resume it later.")
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textSecondary)
        ForEach(session.exercises, id: \.slotID) { exercise in
          HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", exercise.order + 1))
              .font(OneSetTypography.caption)
              .foregroundStyle(OneSetColors.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
              Text(exercise.name).font(OneSetTypography.bodyStrong).foregroundStyle(OneSetColors.textPrimary)
              Text(exercise.repTarget.label).font(OneSetTypography.label).foregroundStyle(OneSetColors.textSecondary)
            }
            Spacer()
          }
          .padding(.vertical, 12)
          .overlay(alignment: .bottom) { Rectangle().fill(OneSetColors.border).frame(height: 1) }
        }
        Button("Discard workout", role: .destructive) { confirmsDiscard = true }
          .frame(minHeight: 44)
          .accessibilityIdentifier("recording.discard")
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .background(OneSetColors.background)
    .navigationTitle(session.workoutName)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog("Discard this unfinished workout?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
      Button("Discard workout", role: .destructive, action: onDiscard)
      Button("Keep workout", role: .cancel) {}
    } message: {
      Text("Your completed program progress will not change.")
    }
  }
}
