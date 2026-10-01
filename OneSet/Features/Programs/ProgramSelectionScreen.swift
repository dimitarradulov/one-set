import SwiftUI

struct ProgramSelectionScreen: View {
  let programs: [TrainingProgram]
  let trainingDays: Int
  let selectedProgramID: TrainingProgram.ID?

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

          Text("All ten programs are available. We’ll put your \(trainingDays)-day matches first.")
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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

        Text("Training frequency is a guide. Every program remains open to you.")
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
