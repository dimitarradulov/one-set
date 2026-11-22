import Foundation
import Testing
@testable import OneSet

@MainActor
struct SignOutSubscriptionTests {
  private final class Log {
    var events: [String] = []
  }

  private func makeModel(log: Log) -> OnboardingModel {
    let setup = AccountSetup(preferredUnit: .kilograms, trainingDays: 3, programID: "machine-full-body", cycleID: UUID())
    let model = OnboardingModel(catalog: .bundled, setupService: StaticAccountSetupService(setup: setup))
    model.beforeSignOut = { log.events.append("wait") }
    model.onConfirmedSignOut = { log.events.append("removed \($0)") }
    return model
  }

  @Test func confirmedSignOutWaitsForOperationsThenReportsTheAccount() async {
    let log = Log()
    let model = makeModel(log: log)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    await model.signOut(using: authentication, confirmed: true)

    #expect(authentication.signedInUser == nil)
    #expect(log.events == ["wait", "removed preview-user"])
  }

  @Test func failedSignOutKeepsSavedAccess() async {
    let log = Log()
    let model = makeModel(log: log)
    let authentication = AuthenticationModel(
      service: PreviewAuthenticationService(startsSignedIn: true, signOutFails: true))
    await model.resolveAccountSetup(using: authentication)

    await model.signOut(using: authentication, confirmed: true)

    #expect(authentication.signedInUser != nil)
    #expect(!log.events.contains { $0.hasPrefix("removed") })
  }

  @Test func identityLossWithoutSignOutKeepsSavedAccess() async {
    let log = Log()
    let model = makeModel(log: log)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    model.resetAccount()

    #expect(log.events.isEmpty)
  }
}
