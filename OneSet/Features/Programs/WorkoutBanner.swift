import SwiftUI
import UIKit

enum WorkoutBannerAsset {
  private static let fallbackAssetName = "WorkoutBannerGeneralGym"

  private static let names: [String: String] = [
    "general-gym": "WorkoutBannerGeneralGym",
    "upper-body": "WorkoutBannerUpperBody",
    "lower-body": "WorkoutBannerLowerBody",
    "chest-push": "WorkoutBannerChestPush",
    "back-pull": "WorkoutBannerBackPull",
    "shoulders": "WorkoutBannerShoulders",
    "arms": "WorkoutBannerArms",
  ]

  static func assetName(for identifier: String?) -> String {
    guard let identifier, let name = names[identifier], UIImage(named: name) != nil else {
      return fallbackAssetName
    }
    return name
  }
}

struct WorkoutBanner: View {
  let program: TrainingProgram
  let workout: WorkoutTemplate
  let day: Int

  private var assetName: String {
    WorkoutBannerAsset.assetName(for: workout.banner)
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Day \(day)")
          .font(OneSetTypography.label)
          .foregroundStyle(.white.opacity(0.82))

        Text(workout.name)
          .font(OneSetTypography.h1)
          .foregroundStyle(.white)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("workoutPreview.title")

        Text(program.name)
          .font(OneSetTypography.body)
          .foregroundStyle(.white.opacity(0.86))
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("workoutPreview.program")
      }
      .frame(maxWidth: .infinity, minHeight: 248, alignment: .bottomLeading)
      .padding(.horizontal, 20)
      .padding(.vertical, 18)
      .background {
        GeometryReader { geometry in
          Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay {
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0.2),
                  .init(color: .black.opacity(0.88), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            }
            .accessibilityHidden(true)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("workoutPreview.banner")
  }
}
