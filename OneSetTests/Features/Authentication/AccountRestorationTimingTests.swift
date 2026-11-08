import Foundation
import Testing
@testable import OneSet

@MainActor
struct AccountRestorationTimingTests {
  @Test
  func timeoutOffersRecoveryAndIgnoresLateLookup() async {
    let clock = RestorationClock()
    let service = SuspendedSetupService()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: service, waitForSetupDelay: { delay in
      try await clock.wait(delay)
    })
    let attempt = Task { await model.resolveAccountSetup(using: authentication) }
    while !service.isWaiting || !clock.hasWaiter(1) || !clock.hasWaiter(15) { await Task.yield() }
    #expect(!model.showsSetupSpinner)
    clock.advance(1)
    await Task.yield()
    #expect(model.showsSetupSpinner)
    clock.advance(15)
    await Task.yield()
    if case .failed = model.setupResolution {} else { Issue.record("Recovery should be offered at the deadline") }
    service.complete()
    await attempt.value
    if case .failed = model.setupResolution {} else { Issue.record("A late response must not navigate") }
    #expect(model.path.isEmpty)
  }

  @Test
  func immediateCompletionDoesNotWaitForSpinner() async {
    let clock = RestorationClock()
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    let model = OnboardingModel(catalog: .bundled, setupService: PreviewAccountSetupService(), waitForSetupDelay: { delay in
      try await clock.wait(delay)
    })
    await model.resolveAccountSetup(using: authentication)
    #expect(model.path == [.preferences])
    #expect(!model.showsSetupSpinner)
    await Task.yield()
    clock.advance(1)
    clock.advance(15)
  }
}

@MainActor
private final class RestorationClock {
  private var waiters: [TimeInterval: CheckedContinuation<Void, any Error>] = [:]
  func wait(_ delay: TimeInterval) async throws {
    try await withCheckedThrowingContinuation { waiters[delay] = $0 }
  }
  func hasWaiter(_ delay: TimeInterval) -> Bool { waiters[delay] != nil }
  func advance(_ delay: TimeInterval) { waiters.removeValue(forKey: delay)?.resume() }
}

@MainActor
private final class SuspendedSetupService: AccountSetupService {
  private var continuation: CheckedContinuation<AccountSetup?, Never>?
  var isWaiting: Bool { continuation != nil }
  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? {
    await withCheckedContinuation { continuation = $0 }
  }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup { setup }
  func complete() { continuation?.resume(returning: nil); continuation = nil }
}
