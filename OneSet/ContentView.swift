import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("ONESET")
        .font(OneSetTypography.display)
        .foregroundStyle(OneSetColors.accent)

      Text("Your training starts here")
        .font(OneSetTypography.h2)
        .foregroundStyle(OneSetColors.textPrimary)

      Text("The iOS app foundation is ready. Workouts and account setup are coming next.")
        .font(OneSetTypography.body)
        .foregroundStyle(OneSetColors.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(24)
    .background(OneSetColors.background)
    .preferredColorScheme(.dark)
  }
}

#Preview {
  ContentView()
}
