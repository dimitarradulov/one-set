import SwiftUI

struct SupersetLabel: View {
  var body: some View {
    Text("Superset")
      .font(OneSetTypography.caption)
      .foregroundStyle(OneSetColors.textSecondary)
      .accessibilityAddTraits(.isHeader)
  }
}
