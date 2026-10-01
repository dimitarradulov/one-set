enum WeightUnit: String, CaseIterable, Identifiable {
  case kilograms = "kg"
  case pounds = "lb"

  var id: String { rawValue }
}
