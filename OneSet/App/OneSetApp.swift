import SwiftUI
import ClerkKit

@main
struct OneSetApp: App {
  @State private var onboarding: OnboardingModel
  @State private var authentication: AuthenticationModel

  #if DEBUG
  @State private var isDevelopmentSession = false
  #endif

  init() {
    Clerk.configure(publishableKey: "pk_test_ZXhhY3QtbGlnZXItMzM1Ni5jbGVyay5hY2NvdW50cy5kZXYk")

    let arguments = ProcessInfo.processInfo.arguments
    let dependencies = AppDependencies.live(arguments: arguments)
    let launch = AppLaunchConfiguration(arguments: arguments)
    let model = OnboardingModel(
      catalog: dependencies.catalog,
      setupService: dependencies.accountSetup,
      progressStore: dependencies.onboardingProgress,
      workoutRepositoryFactory: dependencies.workoutRepositoryFactory,
      initialPath: launch.onboardingPath,
      initialSelectedProgramID: launch.selectedProgramID,
      initialProgramPath: launch.programPath,
      initialSettingsPath: launch.settingsPath,
      initialMainTab: launch.selectedMainTab
    )
    model.trainingDays = launch.trainingDays
    _onboarding = State(initialValue: model)
    _authentication = State(initialValue: AuthenticationModel(
      service: dependencies.authentication
    ))
  }

  private var onboardingFlow: OnboardingFlowView {
    var flow = OnboardingFlowView(model: onboarding, authentication: authentication)
    #if DEBUG
    flow.onDevelopmentSignIn = {
      let dependencies = AppDependencies.development()
      onboarding = OnboardingModel(
        catalog: dependencies.catalog,
        setupService: dependencies.accountSetup,
        progressStore: dependencies.onboardingProgress,
        workoutRepositoryFactory: dependencies.workoutRepositoryFactory
      )
      authentication = AuthenticationModel(service: dependencies.authentication)
      isDevelopmentSession = true
    }
    flow.onDevelopmentSignOut = {
      guard isDevelopmentSession else { return }
      let dependencies = AppDependencies.live(arguments: ProcessInfo.processInfo.arguments)
      onboarding = OnboardingModel(
        catalog: dependencies.catalog,
        setupService: dependencies.accountSetup,
        progressStore: dependencies.onboardingProgress,
        workoutRepositoryFactory: dependencies.workoutRepositoryFactory
      )
      authentication = AuthenticationModel(service: dependencies.authentication)
      isDevelopmentSession = false
    }
    #endif
    return flow
  }

  var body: some Scene {
    WindowGroup {
      onboardingFlow
        .id(ObjectIdentifier(authentication))
        .tint(OneSetColors.accent)
        .environment(Clerk.shared)
        #if DEBUG
        .task {
          if ProcessInfo.processInfo.arguments.contains("--ui-apple-auth-error") {
            await authentication.signInWithApple()
          } else if ProcessInfo.processInfo.arguments.contains("--ui-google-auth-error") {
            await authentication.signInWithGoogle()
          }
        }
        #endif
    }
  }
}
