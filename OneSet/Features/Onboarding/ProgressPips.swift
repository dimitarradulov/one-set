import SwiftUI

struct ProgressPips: View {
  var currentStep = 1

  var body: some View {
    HStack(spacing: 5) {
      ForEach(1...4, id: \.self) { step in
        Capsule()
          .fill(step <= currentStep ? OneSetColors.accent : OneSetColors.surfaceRaised)
          .frame(width: 36, height: 5)
      }
    }
    .accessibilityElement(children: .ignore)
  }
}
