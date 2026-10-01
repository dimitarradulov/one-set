import SwiftUI

struct OneSetBrandMark: View {
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "dumbbell.fill")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(OneSetColors.accent)
      Text("1")
        .font(OneSetTypography.display)
        .foregroundStyle(.white)
      Text("ONESET")
        .font(OneSetTypography.h2)
        .foregroundStyle(.white)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("OneSet")
  }
}
