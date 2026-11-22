import Foundation
@testable import OneSet

/// Test fake: checks wait until the test resolves or fails them, and state can change at any time.
@MainActor
final class ControllableSubscriptionAccessService: SubscriptionAccessService {
  private(set) var checkCount = 0
  private var waiters: [CheckedContinuation<SubscriptionAccess, Never>] = []
  private var subscribers: [UUID: (AccountSelection, AsyncStream<SubscriptionAccessResult>.Continuation)] = [:]
  private var current: SubscriptionAccess = .checking
  var purchaseResult: Result<SubscriptionAccess, SubscriptionOperationError> = .success(.pendingApproval)
  var restoreResult: Result<SubscriptionAccess, SubscriptionOperationError> = .failure(.failed)

  func currentAccess(for selection: AccountSelection) async -> SubscriptionAccessResult {
    if !waiters.isEmpty || current == .checking {
      return await check(for: selection)
    }
    return SubscriptionAccessResult(selection: selection, access: current)
  }

  func refresh(for selection: AccountSelection) async -> SubscriptionAccessResult {
    await check(for: selection)
  }

  private func check(for selection: AccountSelection) async -> SubscriptionAccessResult {
    if waiters.isEmpty { checkCount += 1 }
    let access = await withCheckedContinuation { waiters.append($0) }
    return SubscriptionAccessResult(selection: selection, access: access)
  }

  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult {
    let access = try purchaseResult.get()
    set(access, for: selection)
    return SubscriptionAccessResult(selection: selection, access: access)
  }

  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult {
    let access = try restoreResult.get()
    set(access, for: selection)
    return SubscriptionAccessResult(selection: selection, access: access)
  }

  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult> {
    let id = UUID()
    return AsyncStream { continuation in
      subscribers[id] = (selection, continuation)
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor in self?.subscribers[id] = nil }
      }
    }
  }

  func waitForPendingCheck() async {
    while waiters.isEmpty { await Task.yield() }
  }

  func resolve(_ access: SubscriptionAccess) {
    current = access
    let pending = waiters
    waiters = []
    pending.forEach { $0.resume(returning: access) }
  }

  func fail() { resolve(.unconfirmed) }

  func set(_ access: SubscriptionAccess, for selection: AccountSelection) {
    current = access
    for (subscribed, continuation) in subscribers.values where subscribed == selection {
      continuation.yield(SubscriptionAccessResult(selection: selection, access: access))
    }
  }
}
