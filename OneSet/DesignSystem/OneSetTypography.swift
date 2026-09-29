import SwiftUI
import UIKit

enum OneSetTypography {
  static let display = custom("BebasNeue-Regular", size: 40, relativeTo: .largeTitle, fallback: .default)
  static let h1 = custom("BebasNeue-Regular", size: 32, relativeTo: .largeTitle, fallback: .default)
  static let h2 = custom("BebasNeue-Regular", size: 24, relativeTo: .title2, fallback: .default)

  static let body = custom("RobotoMono-Regular", size: 16, relativeTo: .body, fallback: .monospaced)
  static let bodyStrong = custom("RobotoMono-Medium", size: 16, relativeTo: .body, fallback: .monospaced)
  static let label = custom("RobotoMono-Medium", size: 14, relativeTo: .subheadline, fallback: .monospaced)
  static let caption = custom("RobotoMono-Regular", size: 12, relativeTo: .caption, fallback: .monospaced)
  static let metric = custom("RobotoMono-Medium", size: 20, relativeTo: .title3, fallback: .monospaced)
    .monospacedDigit()
  static let button = custom("RobotoMono-Medium", size: 16, relativeTo: .body, fallback: .monospaced)

  private static func custom(
    _ name: String,
    size: CGFloat,
    relativeTo textStyle: Font.TextStyle,
    fallback design: Font.Design
  ) -> Font {
    if UIFont(name: name, size: size) != nil {
      return .custom(name, size: size, relativeTo: textStyle)
    }
    return .system(textStyle, design: design)
  }
}
