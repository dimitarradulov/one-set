import SwiftUI

enum OneSetColors {
  static let background = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
  static let surface = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
  static let surfaceRaised = Color(red: 42 / 255, green: 42 / 255, blue: 42 / 255)
  static let border = Color(red: 58 / 255, green: 58 / 255, blue: 58 / 255)

  static let textPrimary = Color(red: 229 / 255, green: 229 / 255, blue: 229 / 255)
  static let textSecondary = Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255)
  static let textTertiary = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255)
  static let error = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)

  static let accent = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
  static let accentPressed = Color(red: 184 / 255, green: 97 / 255, blue: 5 / 255)
  static let accentSubtle = accent.opacity(0.14)
  static let overlay = Color.black.opacity(0.64)
}
