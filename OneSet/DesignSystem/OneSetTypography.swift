import SwiftUI
import UIKit

enum OneSetTypography {
  static let display = custom("BebasNeue-Regular", size: 40, relativeTo: .largeTitle, fallback: .default)
  static let h1 = custom("BebasNeue-Regular", size: 32, relativeTo: .largeTitle, fallback: .default)
  static let h2 = custom("BebasNeue-Regular", size: 24, relativeTo: .title2, fallback: .default)

  static let body = custom("Montserrat-Regular", size: 16, relativeTo: .body, fallback: .default)
  static let bodyStrong = custom("Montserrat-Medium", size: 16, relativeTo: .body, fallback: .default)
  static let label = custom("Montserrat-Medium", size: 14, relativeTo: .subheadline, fallback: .default)
  static let caption = custom("Montserrat-Regular", size: 12, relativeTo: .caption, fallback: .default)
  static let metric = custom("Montserrat-Medium", size: 20, relativeTo: .title3, fallback: .default)
    .monospacedDigit()
  static let button = custom("Montserrat-Medium", size: 16, relativeTo: .body, fallback: .default)

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
