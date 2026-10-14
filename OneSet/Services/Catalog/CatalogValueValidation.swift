import Foundation

enum CatalogValueValidation {
  static func isStableKey(_ value: String) -> Bool {
    !value.isEmpty && value.range(of: #"^[a-z0-9][a-z0-9_-]*$"#, options: .regularExpression) != nil
  }

  static func isValidRepRange(minimum: Int, maximum: Int) -> Bool {
    minimum > 0 && maximum >= minimum && maximum <= 100
  }
}
