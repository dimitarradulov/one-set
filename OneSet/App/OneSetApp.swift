import SwiftUI
import ClerkKit

@main
struct OneSetApp: App {
  @State private var onboarding: OnboardingModel

  init() {
    Clerk.configure(publishableKey: "pk_test_ZXhhY3QtbGlnZXItMzM1Ni5jbGVyay5hY2NvdW50cy5kZXYk")

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
        .environment(Clerk.shared)
    }
  }
}
