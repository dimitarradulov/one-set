import SwiftUI

struct UnitsSettingsScreen: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    Form {
      Section {
        ForEach(WeightUnit.allCases) { unit in
          SettingsChoiceRow(
            title: unit == .kilograms ? "Kilograms (kg)" : "Pounds (lb)",
            isSelected: model.weightUnit == unit,
            identifier: "settings.units.\(unit.rawValue)"
          ) { model.setPreferredUnit(unit) }
        }
      } footer: {
        if model.canChangeUnits {
          Text("Recorded results keep the unit they were logged in.")
        } else {
          Text(OnboardingModel.unitsLockedNote)
        }
      }
      .listRowBackground(OneSetColors.surface)
      .disabled(!model.canChangeUnits)
    }
    .settingsChoiceStyle(title: "Units")
    .saveFailureAlert(isPresented: $model.progressErrorPresented, message: model.progressErrorMessage)
  }
}

struct TrainingFrequencySettingsScreen: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    Form {
      Section {
        ForEach(Array(AccountPreferences.trainingDaysRange), id: \.self) { days in
          SettingsChoiceRow(
            title: "\(days) days per week",
            isSelected: model.trainingDays == days,
            identifier: "settings.frequency.\(days)"
          ) { model.setTrainingDays(days) }
        }
      } footer: {
        Text("Programs matching this appear first when you switch programs. Your current program stays the same.")
      }
      .listRowBackground(OneSetColors.surface)
    }
    .settingsChoiceStyle(title: "Training frequency")
    .saveFailureAlert(isPresented: $model.progressErrorPresented, message: model.progressErrorMessage)
  }
}

private struct SettingsChoiceRow: View {
  let title: String
  let isSelected: Bool
  let identifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textPrimary)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(OneSetColors.accent)
            .accessibilityHidden(true)
        }
      }
      .contentShape(Rectangle())
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(identifier)
  }
}

private extension View {
  /// Reports a failed local save of a preference change.
  func saveFailureAlert(isPresented: Binding<Bool>, message: String) -> some View {
    alert("Couldn’t save", isPresented: isPresented) {
      Button("OK", role: .cancel) { }
    } message: { Text(message) }
  }

  func settingsChoiceStyle(title: String) -> some View {
    scrollContentBackground(.hidden)
      .background(OneSetColors.background)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.visible, for: .tabBar)
  }
}
