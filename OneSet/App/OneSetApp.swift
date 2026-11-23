import SwiftUI
import ClerkKit

@main
struct OneSetApp: App {
  private let restAlerts: WorkoutRestAlerts?
  @State private var onboarding: OnboardingModel
  @State private var authentication: AuthenticationModel
  @State private var subscriptionSettings: SubscriptionSettingsModel
  @Environment(\.scenePhase) private var scenePhase
  private let subscriptionAccounts: (any SubscriptionAccountSelecting)?

  #if DEBUG
  @State private var isDevelopmentSession = false
  #endif

  init() {
    Clerk.configure(publishableKey: "pk_test_ZXhhY3QtbGlnZXItMzM1Ni5jbGVyay5hY2NvdW50cy5kZXYk")

    let arguments = ProcessInfo.processInfo.arguments
    let dependencies = AppDependencies.live(arguments: arguments)
    let launch = AppLaunchConfiguration(arguments: arguments)
    #if DEBUG
    let restAlerts = ProcessInfo.processInfo.environment["ONESET_UI_TEST_ID"] == nil ? WorkoutRestAlerts() : nil
    #else
    let restAlerts = WorkoutRestAlerts()
    #endif
    self.restAlerts = restAlerts
    let model = OnboardingModel(
      catalog: dependencies.catalog,
      setupService: dependencies.accountSetup,
      cycleService: dependencies.accountCycles,
      previousPerformanceService: dependencies.previousPerformance,
      progressService: dependencies.accountProgress,
      completedSessionUploadService: dependencies.completedSessionUpload,
      sessionHistoryService: dependencies.sessionHistory,
      subscriptionAccess: dependencies.subscriptionAccess,
      paywallHost: dependencies.paywallHost,
      paywallApproval: dependencies.paywallApproval,
      progressStore: dependencies.onboardingProgress,
      workoutRepositoryFactory: dependencies.workoutRepositoryFactory,
      restAlerts: restAlerts,
      initialPath: launch.onboardingPath,
      initialSelectedProgramID: launch.selectedProgramID,
      initialProgramPath: launch.programPath,
      initialSettingsPath: launch.settingsPath,
      initialMainTab: launch.selectedMainTab
    )
    model.trainingDays = launch.trainingDays
    model.accountDeletion = dependencies.accountDeletion
    let accounts = dependencies.subscriptionAccess as? any SubscriptionAccountSelecting
    subscriptionAccounts = accounts
    Self.connect(model, to: accounts)
    if let accounts { model.accountSelectionProvider = { accounts.selection } }
    _onboarding = State(initialValue: model)
    _subscriptionSettings = State(initialValue: Self.subscriptionSettings(for: dependencies))
    _authentication = State(initialValue: AuthenticationModel(
      service: dependencies.authentication
    ))
  }

  /// Tells the account owner about account changes and confirmed sign-outs, and lets it finish a
  /// purchase before an explicit sign-out changes identity.
  private static func connect(_ model: OnboardingModel, to accounts: (any SubscriptionAccountSelecting)?) {
    model.onResolvedAccountChange = { accounts?.selectAccount($0) }
    model.beforeSignOut = { await accounts?.waitUntilNoInteractiveOperation() }
    model.onConfirmedSignOut = { accounts?.removeSavedAccessAfterSignOut(accountID: $0) }
  }

  private static func subscriptionSettings(for dependencies: AppDependencies) -> SubscriptionSettingsModel {
    SubscriptionSettingsModel(
      access: dependencies.subscriptionAccess, host: dependencies.paywallHost,
      approval: dependencies.paywallApproval)
  }

  private var onboardingFlow: OnboardingFlowView {
    var flow = OnboardingFlowView(model: onboarding, authentication: authentication, subscription: subscriptionSettings)
    #if DEBUG
    flow.onDevelopmentSignIn = {
      let dependencies = AppDependencies.development()
      onboarding = OnboardingModel(
        catalog: dependencies.catalog,
        setupService: dependencies.accountSetup,
      cycleService: dependencies.accountCycles,
        previousPerformanceService: dependencies.previousPerformance,
        progressService: dependencies.accountProgress,
        completedSessionUploadService: dependencies.completedSessionUpload,
        sessionHistoryService: dependencies.sessionHistory,
        subscriptionAccess: dependencies.subscriptionAccess,
        paywallHost: dependencies.paywallHost,
        paywallApproval: dependencies.paywallApproval,
        progressStore: dependencies.onboardingProgress,
        workoutRepositoryFactory: dependencies.workoutRepositoryFactory,
        restAlerts: restAlerts
      )
      onboarding.accountDeletion = dependencies.accountDeletion
      authentication = AuthenticationModel(service: dependencies.authentication)
      subscriptionSettings = Self.subscriptionSettings(for: dependencies)
      let accounts = dependencies.subscriptionAccess as? any SubscriptionAccountSelecting
      Self.connect(onboarding, to: accounts)
      isDevelopmentSession = true
    }
    flow.onDevelopmentSignOut = {
      guard isDevelopmentSession else { return }
      let dependencies = AppDependencies.live(arguments: ProcessInfo.processInfo.arguments)
      onboarding = OnboardingModel(
        catalog: dependencies.catalog,
        setupService: dependencies.accountSetup,
      cycleService: dependencies.accountCycles,
        previousPerformanceService: dependencies.previousPerformance,
        progressService: dependencies.accountProgress,
        completedSessionUploadService: dependencies.completedSessionUpload,
        sessionHistoryService: dependencies.sessionHistory,
        subscriptionAccess: dependencies.subscriptionAccess,
        paywallHost: dependencies.paywallHost,
        paywallApproval: dependencies.paywallApproval,
        progressStore: dependencies.onboardingProgress,
        workoutRepositoryFactory: dependencies.workoutRepositoryFactory,
        restAlerts: restAlerts
      )
      onboarding.accountDeletion = dependencies.accountDeletion
      authentication = AuthenticationModel(service: dependencies.authentication)
      subscriptionSettings = Self.subscriptionSettings(for: dependencies)
      let accounts = dependencies.subscriptionAccess as? any SubscriptionAccountSelecting
      Self.connect(onboarding, to: accounts)
      isDevelopmentSession = false
    }
    #endif
    return flow
  }

  var body: some Scene {
    WindowGroup {
      #if DEBUG
      if let paywallPreview = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments).paywallPreview {
        PaywallPreviewRoute(state: paywallPreview).tint(OneSetColors.accent)
      } else {
        mainContent
      }
      #else
      mainContent
      #endif
    }
  }

  @ViewBuilder private var mainContent: some View {
    onboardingFlow
      .id(ObjectIdentifier(authentication))
      .tint(OneSetColors.accent)
      .environment(Clerk.shared)
      .onChange(of: authentication.signedInUser?.id) { _, accountID in
        // Clerk lost or changed identity: drop the old account's access right away.
        if accountID != subscriptionAccounts?.selection?.accountID { subscriptionAccounts?.selectAccount(nil) }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { subscriptionAccounts?.appDidReturnToForeground() }
      }
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
