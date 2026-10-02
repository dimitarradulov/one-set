import SwiftUI

@main
struct OneSetApp: App {
  @State private var onboarding: OnboardingModel

  init() {
    let dependencies = AppDependencies.live
    let launch = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
    let model = OnboardingModel(
      catalog: dependencies.catalog,
      initialPath: launch.onboardingPath,
      initialSelectedProgramID: launch.selectedProgramID
    )
    model.trainingDays = launch.trainingDays
    _onboarding = State(initialValue: model)
  }

  var body: some Scene {
    WindowGroup {
      OnboardingFlowView(model: onboarding)
        .tint(OneSetColors.accent)
    }
  }
}
