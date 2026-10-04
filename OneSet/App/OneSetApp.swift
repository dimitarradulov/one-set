import SwiftUI
import ClerkKit

@main
struct OneSetApp: App {
  @State private var onboarding: OnboardingModel
  @State private var authentication: AuthenticationModel

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
    _authentication = State(initialValue: AuthenticationModel(service: dependencies.authentication))
  }

  var body: some Scene {
    WindowGroup {
      OnboardingFlowView(model: onboarding, authentication: authentication)
        .tint(OneSetColors.accent)
        .environment(Clerk.shared)
    }
  }
}
