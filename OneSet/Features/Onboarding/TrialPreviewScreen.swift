import SwiftUI

struct TrialPreviewScreen: View {
  let program: TrainingProgram
  let onContinueWithoutTrial: () -> Void

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
              Text("7-day trial preview")
                .font(OneSetTypography.h1)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("trial.title")

              Text("Review the intended offer before continuing.")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
              Text("Selected program")
                .font(OneSetTypography.label)
                .foregroundStyle(OneSetColors.textSecondary)

              Text(program.name)
                .font(OneSetTypography.h2)
                .foregroundStyle(OneSetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

              Text("\(program.trainingDaysPerWeek) days per week · \(program.workoutCountLabel)")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(OneSetColors.border, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 12) {
              Label("Preview only", systemImage: "info.circle")
                .font(OneSetTypography.bodyStrong)
                .foregroundStyle(OneSetColors.textPrimary)

              Text("This is a preview. It does not check eligibility, enroll you, grant access, start a trial, or make a purchase. No trial has started.")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("trial.preview.notice")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: 560, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 24)
          .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)

        Button(action: onContinueWithoutTrial) {
          Text("Continue without trial")
            .font(OneSetTypography.button)
            .foregroundStyle(Color.black)
            .frame(maxWidth: 560, minHeight: 52)
            .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trial.continueWithoutTrial")
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
}
