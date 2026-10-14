import Foundation

extension RepTarget {
  init?(validating range: CatalogRepRange, scope: Scope = .reps) {
    guard CatalogValueValidation.isValidRepRange(minimum: range.minimum, maximum: range.maximum) else { return nil }
    self.init(minimum: range.minimum, maximum: range.maximum, scope: scope)
  }
}
