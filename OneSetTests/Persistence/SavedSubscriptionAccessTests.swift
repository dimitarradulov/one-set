import Foundation
import Testing
@testable import OneSet

@MainActor
struct SavedSubscriptionAccessTests {
  private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  private let expiry = Date(timeIntervalSince1970: 1_800_086_400)
  private let selection = AccountSelection(accountID: "user", generation: 1)

  private func makeURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathComponent("saved.json")
  }

  private func makeAccess(
    url: URL, environment: BillingEnvironment = .production, selected: AccountSelection? = nil
  ) -> SavedSubscriptionAccess {
    let access = SavedSubscriptionAccess(store: FileSavedSubscriptionAccessStore(fileURL: url), environment: environment)
    access.select(selected ?? selection)
    return access
  }

  @Test func activeRecordAllowsOfflineStartOnlyBeforeExpiry() {
    let access = makeAccess(url: makeURL())
    #expect(access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection))
    #expect(access.access(for: selection, now: t0.addingTimeInterval(60)).allowsNewWorkout(at: t0.addingTimeInterval(60)))
    #expect(access.access(for: selection, now: expiry) == .unconfirmed)
    #expect(access.access(for: selection, now: expiry.addingTimeInterval(1)) == .unconfirmed)
  }

  @Test func relaunchBeforeAndAfterExpiryReadsSavedRecord() {
    let url = makeURL()
    makeAccess(url: url).record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    let relaunched = makeAccess(url: url)
    #expect(relaunched.access(for: selection, now: t0.addingTimeInterval(10)) == .proVerified(expiresAt: expiry))
    #expect(relaunched.access(for: selection, now: expiry.addingTimeInterval(10)) == .unconfirmed)
  }

  @Test func staleSelectionWritesAreRejected() {
    let access = makeAccess(url: makeURL())
    let stale = AccountSelection(accountID: "user", generation: 0)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: stale))
    #expect(access.access(for: selection, now: t0) == .unconfirmed)
  }

  @Test func newerActiveReplacesExpiry() {
    let access = makeAccess(url: makeURL())
    let later = expiry.addingTimeInterval(86_400)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    #expect(access.record(.verifiedActive(expiresAt: later), checkedAt: t0.addingTimeInterval(5), for: selection))
    #expect(access.access(for: selection, now: t0) == .proVerified(expiresAt: later))
  }

  @Test func newerInactiveClearsAndOlderReplyCannotRestore() {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    #expect(access.record(.verifiedInactive, checkedAt: t0.addingTimeInterval(10), for: selection))
    #expect(access.access(for: selection, now: t0.addingTimeInterval(11)) == .unconfirmed)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0.addingTimeInterval(5), for: selection))
    #expect(access.access(for: selection, now: t0.addingTimeInterval(11)) == .unconfirmed)
  }

  @Test func outOfOrderActiveRepliesKeepNewest() {
    let access = makeAccess(url: makeURL())
    let later = expiry.addingTimeInterval(86_400)
    access.record(.verifiedActive(expiresAt: later), checkedAt: t0.addingTimeInterval(10), for: selection)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection))
    #expect(access.access(for: selection, now: t0) == .proVerified(expiresAt: later))
  }

  @Test(arguments: [SubscriptionObservation.failed, .onDeviceOnly])
  func failedOrOnDeviceChecksLeaveSavedActiveRecordUnchanged(observation: SubscriptionObservation) {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    #expect(!access.record(observation, checkedAt: t0.addingTimeInterval(10), for: selection))
    #expect(access.access(for: selection, now: t0.addingTimeInterval(20)) == .proVerified(expiresAt: expiry))
  }

  @Test func savedInactiveNeverEnablesCheckout() {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedInactive, checkedAt: t0, for: selection)
    let result = access.access(for: selection, now: t0)
    #expect(!result.allowsCheckout)
    #expect(!result.allowsNewWorkout(at: t0))
  }

  @Test func readRequiresEstablishedMatchingSelection() {
    let url = makeURL()
    let access = makeAccess(url: url)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    access.select(nil)
    #expect(access.access(for: selection, now: t0) == .unconfirmed)
    access.select(AccountSelection(accountID: "other", generation: 2))
    #expect(access.access(for: selection, now: t0) == .unconfirmed)
    #expect(access.access(for: AccountSelection(accountID: "other", generation: 2), now: t0) == .unconfirmed)
  }

  @Test func sandboxAccessIsNeverReadableByProductionLookup() {
    let url = makeURL()
    makeAccess(url: url, environment: .sandbox)
      .record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    #expect(makeAccess(url: url, environment: .production).access(for: selection, now: t0) == .unconfirmed)
    #expect(makeAccess(url: url, environment: .sandbox).access(for: selection, now: t0) == .proVerified(expiresAt: expiry))
  }

  @Test func accountsAreIsolated() {
    let url = makeURL()
    let access = makeAccess(url: url)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    let other = AccountSelection(accountID: "other", generation: 1)
    access.select(other)
    #expect(access.access(for: other, now: t0) == .unconfirmed)
  }

  @Test func confirmedSignOutAndDeletionRemoveAllEnvironments() throws {
    let url = makeURL()
    for environment in [BillingEnvironment.sandbox, .production] {
      makeAccess(url: url, environment: environment)
        .record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    }
    let production = makeAccess(url: url)
    try production.removeAfterConfirmedSignOut(accountID: "user")
    #expect(production.access(for: selection, now: t0) == .unconfirmed)
    #expect(makeAccess(url: url, environment: .sandbox).access(for: selection, now: t0) == .unconfirmed)

    production.record(.verifiedActive(expiresAt: expiry), checkedAt: t0, for: selection)
    try production.removeForDeletedAccount(accountID: "user")
    #expect(production.access(for: selection, now: t0) == .unconfirmed)
  }
}
