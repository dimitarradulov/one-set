import SwiftUI

struct WarmupSheet: View {
  let exercise: WorkoutSession.Exercise
  let unit: WeightUnit
  let previous: WorkoutRepository.PreviousPerformance?
  @Environment(\.dismiss) private var dismiss
  @State private var plannedWeight = ""

  private let stages = ["40–50% · 6–8 reps", "65–70% · 3–5 reps", "80–85% · 1–3 reps"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(exercise.name)
            .font(OneSetTypography.h1)
          if let estimate = previousWeight {
            Text("Starting estimate from your previous set: \(format(estimate)) \(unit.rawValue). Adjust for today.")
              .font(OneSetTypography.body)
              .accessibilityIdentifier("warmup.estimate")
          } else {
            Text("Enter an optional planned weight to estimate warmup loads.")
              .font(OneSetTypography.body)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Planned working weight (\(unit.rawValue))")
              .font(OneSetTypography.label)
            TextField("Optional", text: $plannedWeight)
              .keyboardType(.decimalPad)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("Planned working weight in \(unit.rawValue)")
              .accessibilityIdentifier("warmup.plannedWeight")
            if !plannedWeight.isEmpty && validWeight == nil {
              Text("Enter a weight greater than zero, or leave this empty.")
                .font(OneSetTypography.caption)
                .foregroundStyle(.red)
            }
          }
          let ranges = exercise.warmupRanges(for: validWeight.map { String($0) } ?? "")
          ForEach(stages.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 4) {
              Text(stages[index])
              if ranges.indices.contains(index) {
                Text("\(format(ranges[index].minimumLoad))–\(format(ranges[index].maximumLoad)) \(unit.rawValue)")
                  .font(OneSetTypography.bodyStrong)
              }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("warmup.range.\(index)")
          }
          Text("Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.")
            .font(OneSetTypography.body)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(OneSetColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
      }
      .background(OneSetColors.background)
      .navigationTitle("Warmup")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close") { dismiss() }.accessibilityIdentifier("warmup.close")
        }
      }
      .onAppear {
        if let estimate = previousWeight { plannedWeight = format(estimate) }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var previousWeight: Double? {
    guard let previous, let value = Double(previous.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
          value.isFinite, value > 0 else { return nil }
    let source: UnitMass = previous.weightUnit == .kilograms ? .kilograms : .pounds
    let target: UnitMass = unit == .kilograms ? .kilograms : .pounds
    return Measurement(value: value, unit: source).converted(to: target).value
  }

  private var validWeight: Double? {
    let formatter = NumberFormatter()
    formatter.locale = .current
    formatter.numberStyle = .decimal
    let separator = formatter.decimalSeparator ?? "."
    let parts = plannedWeight.components(separatedBy: separator)
    guard parts.count <= 2, parts.joined().allSatisfy(\.isNumber), !parts.joined().isEmpty else { return nil }
    guard let number = formatter.number(from: plannedWeight), number.doubleValue.isFinite, number.doubleValue > 0 else { return nil }
    return number.doubleValue
  }

  private func format(_ value: Double) -> String {
    value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
  }
}
