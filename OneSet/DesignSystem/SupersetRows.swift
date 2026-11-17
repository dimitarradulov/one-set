import SwiftUI

struct SupersetRows<Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      Text("Superset")
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityAddTraits(.isHeader)
      content
    }
    .padding(.leading, 10)
    .overlay(alignment: .leading) {
      Rectangle().fill(OneSetColors.accent).frame(width: 1).accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
  }
}
