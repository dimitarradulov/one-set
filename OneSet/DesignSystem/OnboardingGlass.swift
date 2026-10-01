import SwiftUI

extension View {
  @ViewBuilder
  func onboardingGlass<S: InsettableShape>(in shape: S, tint: Color?) -> some View {
    if #available(iOS 26.0, *) {
      if let tint {
        glassEffect(.regular.tint(tint), in: shape)
      } else {
        glassEffect(.regular, in: shape)
      }
    } else if let tint {
      background(tint, in: shape)
    } else {
      self
    }
  }
}
