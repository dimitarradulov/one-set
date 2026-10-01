import SwiftUI

struct TrainingPreferencesScreen: View {
  @Binding var weightUnit: WeightUnit
  @Binding var trainingDays: Int
  let onContinue: () -> Void

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Set your training preferences")
                .font(OneSetTypography.h1)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("preferences.title")

              Text("These help us recommend the best programs for your goals. You can change them later in settings.")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
              Text("Weight units")
                .font(OneSetTypography.label)
                .foregroundStyle(OneSetColors.textPrimary)

              HStack(spacing: 10) {
                ForEach(WeightUnit.allCases) { unit in
                  UnitChoiceButton(
                    unit: unit,
                    isSelected: weightUnit == unit,
                    action: { select(unit) }
                  )
                }
              }
            }

            VStack(alignment: .leading, spacing: 12) {
              Text("Training days per week")
                .font(OneSetTypography.label)
                .foregroundStyle(OneSetColors.textPrimary)

              HStack(spacing: 10) {
                ForEach([2, 3, 4, 5], id: \.self) { days in
                  TrainingDayButton(
                    days: days,
                    isSelected: trainingDays == days,
                    action: { select(days: days) }
                  )
                }
              }
            }

          }
          .frame(maxWidth: 560, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 28)
          .padding(.bottom, 20)
          .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)

        Button(action: onContinue) {
          HStack {
            Text("Continue")
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .semibold))
          }
          .font(OneSetTypography.button)
          .foregroundStyle(Color.black)
          .padding(.horizontal, 20)
          .frame(maxWidth: 560, minHeight: 52)
          .onboardingGlass(in: RoundedRectangle(cornerRadius: 12), tint: OneSetColors.accent)
          .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with selected preferences")
        .accessibilityIdentifier("preferences.continue")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
        .frame(maxWidth: .infinity)
        .background(OneSetColors.background)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(OneSetColors.background)
    }
  }

  private func select(_ unit: WeightUnit) {
    weightUnit = unit
  }

  private func select(days: Int) {
    trainingDays = days
  }
}
