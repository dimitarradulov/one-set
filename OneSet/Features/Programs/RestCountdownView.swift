import SwiftUI

struct RestCountdownView: View {
  let deadline: Date
  let onAdjust: (Int) -> Bool
  let onSkip: () -> Bool

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(ceil(deadline.timeIntervalSince(context.date))))
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          countdown(remaining: remaining)
          Spacer(minLength: 8)
          if remaining > 0 { controls }
        }
        VStack(alignment: .leading, spacing: 12) {
          countdown(remaining: remaining)
          if remaining > 0 { controls }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(OneSetTypography.label)
      .buttonStyle(.bordered)
      .tint(OneSetColors.accent)
      .padding(12)
      .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("recording.rest.countdown")
    }
  }

  private func countdown(remaining: Int) -> some View {
    HStack(spacing: 12) {
      Image(systemName: remaining > 0 ? "timer" : "checkmark.circle")
        .font(OneSetTypography.metric)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(remaining > 0 ? "Rest" : "Rest complete")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        Text(remaining > 0 ? String(format: "%d:%02d", remaining / 60, remaining % 60) : "Ready when you are")
          .font(OneSetTypography.metric)
          .monospacedDigit()
          .foregroundStyle(OneSetColors.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var controls: some View {
    HStack(spacing: 12) {
      Button("−15s") { _ = onAdjust(-15) }
        .accessibilityLabel("Reduce rest by 15 seconds")
        .accessibilityIdentifier("recording.rest.reduce")
      Button("+15s") { _ = onAdjust(15) }
        .accessibilityLabel("Add 15 seconds of rest")
        .accessibilityIdentifier("recording.rest.add")
      Button("Skip") { _ = onSkip() }
        .accessibilityIdentifier("recording.rest.skip")
    }
    .frame(minHeight: 44)
  }
}
