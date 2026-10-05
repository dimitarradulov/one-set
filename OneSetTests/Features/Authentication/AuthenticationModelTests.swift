import Testing
@testable import OneSet

@MainActor
struct AuthenticationModelTests {
  @Test(arguments: [false, true])
  func googleAuthenticationRoutesConfirmedAccountSetup(existing: Bool) async {
    let authentication = AuthenticationModel(service: PreviewAuthenticationService())
    let onboarding = OnboardingModel(
      catalog: .bundled,
      setupService: PreviewAccountSetupService(arguments: existing ? ["--ui-setup-completed"] : [])
    )

    await authentication.signInWithGoogle()
    #expect(authentication.didCompleteAuthentication)
    #expect(authentication.isWorking == false)
    #expect(authentication.signedInUser?.id == "preview-google")
    await onboarding.resolveAccountSetup(using: authentication)

    if existing {
      #expect(onboarding.path == [.programOverview("machine-full-body")])
      #expect(onboarding.weightUnit == .pounds)
      #expect(onboarding.trainingDays == 5)
      #expect(onboarding.restoredCycleID != nil)
    } else {
      #expect(onboarding.path == [.preferences])
      #expect(onboarding.weightUnit == .kilograms)
      #expect(onboarding.trainingDays == 3)
      #expect(onboarding.restoredCycleID == nil)
    }
  }

  @Test
  func googleCancellationFinishesWithoutAuthenticationOrError() async {
    let model = AuthenticationModel(service: PreviewAuthenticationService(googleCancels: true))
    await model.signInWithGoogle()
    #expect(model.signedInUser == nil)
    #expect(model.didCompleteAuthentication == false)
    #expect(model.errorMessage == nil)
    #expect(model.isWorking == false)
  }

  @Test
  func googleProviderFailureCanBeRetried() async {
    let model = AuthenticationModel(service: PreviewAuthenticationService(googleFails: true))
    await model.signInWithGoogle()
    #expect(model.errorMessage != nil)
    #expect(model.didCompleteAuthentication == false)
    #expect(model.isWorking == false)
    await model.signInWithGoogle()
    #expect(model.signedInUser?.id == "preview-google")
    #expect(model.didCompleteAuthentication)
    #expect(model.errorMessage == nil)
    #expect(model.isWorking == false)
  }

  @Test
  func googleResultWithoutAuthenticatedUserIsRecoverable() async {
    let model = AuthenticationModel(service: PreviewAuthenticationService(googleIncomplete: true))
    await model.signInWithGoogle()
    #expect(model.signedInUser == nil)
    #expect(model.didCompleteAuthentication == false)
    #expect(model.errorMessage == AuthenticationError.incompleteGoogleAuthentication.localizedDescription)
    #expect(model.isWorking == false)
  }
}
