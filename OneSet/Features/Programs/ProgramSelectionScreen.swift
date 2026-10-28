import SwiftUI

struct ProgramSelectionScreen: View {
  let programs: [TrainingProgram]
  let trainingDays: Int
  let selectedProgramID: TrainingProgram.ID?
  var recoveryMessage: String? = nil

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Choose your program")
            .font(OneSetTypography.h1)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("programs.title")

          Text("Programs for your \(trainingDays)-day schedule appear first. You can choose any program.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let recoveryMessage {
          Label(recoveryMessage, systemImage: "arrow.uturn.backward.circle")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OneSetColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("programs.recoveryMessage")
        }

        VStack(spacing: 8) {
          ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
            ProgramCard(
              program: program,
              position: index + 1,
              isMatch: program.trainingDaysPerWeek == trainingDays,
              isSelected: selectedProgramID == program.id
            )
          }
        }

        Text("Your schedule helps sort the list. It does not limit your choices.")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 4)
      }
      .frame(maxWidth: 560, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 28)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.hidden)
    .background(OneSetColors.background)
  }
}
