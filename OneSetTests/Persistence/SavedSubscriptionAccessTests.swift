import Foundation
import Testing
@testable import OneSet

@MainActor
struct SavedSubscriptionAccessTests {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)
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
    #expect(access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection))
    #expect(access.access(for: selection, now: start.addingTimeInterval(60)).allowsNewWorkout(at: start.addingTimeInterval(60)))
    #expect(access.access(for: selection, now: expiry) == .unconfirmed)
    #expect(access.access(for: selection, now: expiry.addingTimeInterval(1)) == .unconfirmed)
  }

  @Test func relaunchBeforeAndAfterExpiryReadsSavedRecord() {
    let url = makeURL()
    makeAccess(url: url).record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    let relaunched = makeAccess(url: url)
    #expect(relaunched.access(for: selection, now: start.addingTimeInterval(10)) == .proVerified(expiresAt: expiry))
    #expect(relaunched.access(for: selection, now: expiry.addingTimeInterval(10)) == .unconfirmed)
  }

  @Test func staleSelectionWritesAreRejected() {
    let access = makeAccess(url: makeURL())
    let stale = AccountSelection(accountID: "user", generation: 0)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: stale))
    #expect(access.access(for: selection, now: start) == .unconfirmed)
  }

  @Test func newerActiveReplacesExpiry() {
    let access = makeAccess(url: makeURL())
    let later = expiry.addingTimeInterval(86_400)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    #expect(access.record(.verifiedActive(expiresAt: later), checkedAt: start.addingTimeInterval(5), for: selection))
    #expect(access.access(for: selection, now: start) == .proVerified(expiresAt: later))
  }

  @Test func newerInactiveClearsAndOlderReplyCannotRestore() {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    #expect(access.record(.verifiedInactive, checkedAt: start.addingTimeInterval(10), for: selection))
    #expect(access.access(for: selection, now: start.addingTimeInterval(11)) == .unconfirmed)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: start.addingTimeInterval(5), for: selection))
    #expect(access.access(for: selection, now: start.addingTimeInterval(11)) == .unconfirmed)
  }

  @Test func outOfOrderActiveRepliesKeepNewest() {
    let access = makeAccess(url: makeURL())
    let later = expiry.addingTimeInterval(86_400)
    access.record(.verifiedActive(expiresAt: later), checkedAt: start.addingTimeInterval(10), for: selection)
    #expect(!access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection))
    #expect(access.access(for: selection, now: start) == .proVerified(expiresAt: later))
  }

  @Test(arguments: [SubscriptionObservation.failed, .onDeviceOnly])
  func failedOrOnDeviceChecksLeaveSavedActiveRecordUnchanged(observation: SubscriptionObservation) {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    #expect(!access.record(observation, checkedAt: start.addingTimeInterval(10), for: selection))
    #expect(access.access(for: selection, now: start.addingTimeInterval(20)) == .proVerified(expiresAt: expiry))
  }

  @Test func savedInactiveNeverEnablesCheckout() {
    let access = makeAccess(url: makeURL())
    access.record(.verifiedInactive, checkedAt: start, for: selection)
    let result = access.access(for: selection, now: start)
    #expect(!result.allowsCheckout)
    #expect(!result.allowsNewWorkout(at: start))
  }

  @Test func readRequiresEstablishedMatchingSelection() {
    let url = makeURL()
    let access = makeAccess(url: url)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    access.select(nil)
    #expect(access.access(for: selection, now: start) == .unconfirmed)
    access.select(AccountSelection(accountID: "other", generation: 2))
    #expect(access.access(for: selection, now: start) == .unconfirmed)
    #expect(access.access(for: AccountSelection(accountID: "other", generation: 2), now: start) == .unconfirmed)
  }

  @Test func sandboxAccessIsNeverReadableByProductionLookup() {
    let url = makeURL()
    makeAccess(url: url, environment: .sandbox)
      .record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    #expect(makeAccess(url: url, environment: .production).access(for: selection, now: start) == .unconfirmed)
    #expect(makeAccess(url: url, environment: .sandbox).access(for: selection, now: start) == .proVerified(expiresAt: expiry))
  }

  @Test func accountsAreIsolated() {
    let url = makeURL()
    let access = makeAccess(url: url)
    access.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    let other = AccountSelection(accountID: "other", generation: 1)
    access.select(other)
    #expect(access.access(for: other, now: start) == .unconfirmed)
  }

  @Test func confirmedSignOutAndDeletionRemoveAllEnvironments() throws {
    let url = makeURL()
    for environment in [BillingEnvironment.sandbox, .production] {
      makeAccess(url: url, environment: environment)
        .record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    }
    let production = makeAccess(url: url)
    try production.removeAfterConfirmedSignOut(accountID: "user")
    #expect(production.access(for: selection, now: start) == .unconfirmed)
    #expect(makeAccess(url: url, environment: .sandbox).access(for: selection, now: start) == .unconfirmed)

    production.record(.verifiedActive(expiresAt: expiry), checkedAt: start, for: selection)
    try production.removeForDeletedAccount(accountID: "user")
    #expect(production.access(for: selection, now: start) == .unconfirmed)
  }
}
