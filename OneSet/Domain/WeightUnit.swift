enum WeightUnit: String, CaseIterable, Identifiable, Codable, Sendable {
  case kilograms = "kg"
  case pounds = "lb"

  var id: String { rawValue }
}
