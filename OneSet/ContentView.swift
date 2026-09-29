import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("ONESET")
        .font(.system(size: 40, weight: .bold))
        .fontWidth(.condensed)
        .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.02))

      Text("Your training starts here")
        .font(.title2.weight(.semibold))

      Text("The iOS app foundation is ready. Workouts and account setup are coming next.")
        .font(.body)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(24)
    .background(Color(red: 0.10, green: 0.10, blue: 0.10))
    .preferredColorScheme(.dark)
  }
}

#Preview {
  ContentView()
}
