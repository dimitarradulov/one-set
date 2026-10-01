import SwiftUI

struct ProgressPips: View {
  var body: some View {
    HStack(spacing: 5) {
      Capsule().fill(OneSetColors.accent).frame(width: 36, height: 5)
      ForEach(0..<3) { _ in
        Capsule().fill(OneSetColors.surfaceRaised).frame(width: 36, height: 5)
      }
    }
    .accessibilityElement(children: .ignore)
  }
}
