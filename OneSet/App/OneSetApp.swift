import SwiftUI

@main
struct OneSetApp: App {
  @State private var onboarding: OnboardingModel

  init() {
    let dependencies = AppDependencies.live
    let launch = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
    _onboarding = State(initialValue: OnboardingModel(
      catalog: dependencies.catalog,
      initialPath: launch.onboardingPath
    ))
  }

  var body: some Scene {
    WindowGroup {
      OnboardingFlowView(model: onboarding)
        .tint(OneSetColors.accent)
    }
  }
}
