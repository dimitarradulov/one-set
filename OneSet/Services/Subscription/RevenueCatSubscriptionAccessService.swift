import Foundation

/// Lets the app tell the owner which account is selected, or that none is.
@MainActor
protocol SubscriptionAccountSelecting: AnyObject {
  var selection: AccountSelection? { get }
  /// Selects the resolved account, or clears the selection with nil. Reselecting the current
  /// account is a no-op. Any other change starts a new generation and drops earlier access.
  @discardableResult
  func selectAccount(_ accountID: String?) -> AccountSelection?
  /// Refreshes access for the current selection when the app returns to the foreground.
  func appDidReturnToForeground()
  /// Suspends until no interactive purchase or restore is running. Explicit sign-out waits
  /// here before it changes identity.
  func waitUntilNoInteractiveOperation() async
}

/// What RevenueCatUI's paywall, and Settings, need from the owner to run a purchase or
/// restore. Every call carries the selection the screen was showing when the user acted.
/// Calls for a selection that is no longer current are refused or ignored.
@MainActor
protocol SubscriptionOperationApproving: AnyObject {
  /// Body for `.onPurchaseInitiated`: call `resume(shouldProceed:)` with the result.
  /// Claims the single operation slot, rechecks that access is freshly verified inactive with
  /// nothing pending, and returns whether the purchase may proceed. Once it returns true, the
  /// slot stays held until `paywallOperationFinished` runs for that selection.
  func onPurchaseInitiated(for selection: AccountSelection) async -> Bool
  /// Body for `.onRestoreInitiated`. Claims the slot the same way, without the inactivity check.
  func onRestoreInitiated(for selection: AccountSelection) async -> Bool
  /// Call from the paywall's completed, cancelled, and failure callbacks, and when the
  /// paywall closes without one. Releases the slot, refreshes access, and returns the result
  /// for that selection (unconfirmed when the selection is stale).
  @discardableResult
  func paywallOperationFinished(_ result: PaywallOperationResult, for selection: AccountSelection) async
    -> SubscriptionAccessResult
  /// Status check for a pending approval. Clears it once Pro is verified.
  func checkPendingStatus(for selection: AccountSelection) async -> SubscriptionAccessResult
}

/// The app-scoped RevenueCat owner: SDK setup, account selection, and the access check.
/// It also owns purchases and restores: one runs at a time, tied to the selection that started it.
@MainActor
final class RevenueCatSubscriptionAccessService: SubscriptionAccessService, SubscriptionAccountSelecting,
  SubscriptionOperationApproving {
  private let client: any PurchasesClient
  private let apiKey: RevenueCatAPIKeyConfiguration
  private let saved: [BillingEnvironment: SavedSubscriptionAccess]
  private let savedEnvironments: [BillingEnvironment]
  private let pending: any PendingSubscriptionOperationStore
  private let now: @MainActor () -> Date

  private(set) var selection: AccountSelection?
  private var generation = 0
  private var verifiedAccess: SubscriptionAccessResult?
  private var inFlight: (selection: AccountSelection, task: Task<SubscriptionAccessResult, Never>)?
  private var operation: Operation?
  private var idleWaiters: [CheckedContinuation<Void, Never>] = []
  private var subscribers: [UUID: (selection: AccountSelection, continuation: AsyncStream<SubscriptionAccessResult>.Continuation)] = [:]

  /// - Parameter acceptsSandboxSavedAccess: Whether an offline fallback may use saved sandbox
  ///   access. Public builds pass false so a sandbox purchase never unlocks offline.
  init(
    client: any PurchasesClient,
    apiKey: RevenueCatAPIKeyConfiguration,
    store: any SavedSubscriptionAccessStore,
    pendingStore: any PendingSubscriptionOperationStore,
    acceptsSandboxSavedAccess: Bool,
    now: @escaping @MainActor () -> Date = { .now }
  ) {
    self.client = client
    self.apiKey = apiKey
    pending = pendingStore
    self.now = now
    saved = [
      .production: SavedSubscriptionAccess(store: store, environment: .production),
      .sandbox: SavedSubscriptionAccess(store: store, environment: .sandbox)
    ]
    savedEnvironments = acceptsSandboxSavedAccess ? [.production, .sandbox] : [.production]
  }

  // MARK: Account selection

  @discardableResult
  func selectAccount(_ accountID: String?) -> AccountSelection? {
    if let accountID, accountID == selection?.accountID { return selection }
    generation += 1
    verifiedAccess = nil
    inFlight?.task.cancel()
    inFlight = nil
    finishSubscribers()
    guard let accountID else {
      selection = nil
      saved.values.forEach { $0.select(nil) }
      return nil
    }
    let next = AccountSelection(accountID: accountID, generation: generation)
    selection = next
    saved.values.forEach { $0.select(next) }
    return next
  }

  func appDidReturnToForeground() {
    guard let selection else { return }
    Task { _ = await refresh(for: selection) }
  }

  // MARK: Access check

  func currentAccess(for selection: AccountSelection) async -> SubscriptionAccessResult {
    guard selection == self.selection else { return SubscriptionAccessResult(selection: selection, access: .unconfirmed) }
    if let verifiedAccess, verifiedAccess.selection == selection { return verifiedAccess }
    return await sharedCheck(for: selection)
  }

  func refresh(for selection: AccountSelection) async -> SubscriptionAccessResult {
    guard selection == self.selection else { return SubscriptionAccessResult(selection: selection, access: .unconfirmed) }
    return await sharedCheck(for: selection)
  }

  private func sharedCheck(for selection: AccountSelection) async -> SubscriptionAccessResult {
    if let inFlight, inFlight.selection == selection { return await inFlight.task.value }
    let task = Task { @MainActor in await self.runCheck(for: selection) }
    inFlight = (selection, task)
    let result = await task.value
    if inFlight?.selection == selection, inFlight?.task == task { inFlight = nil }
    return result
  }

  private func runCheck(for selection: AccountSelection) async -> SubscriptionAccessResult {
    let outcome = await fetchOutcome(for: selection)
    guard selection == self.selection else {
      return SubscriptionAccessResult(selection: selection, access: .unconfirmed)
    }
    let result = SubscriptionAccessResult(selection: selection, access: applyingPending(outcome, for: selection))
    if outcome.isConclusive {
      verifiedAccess = result
    } else if verifiedAccess?.selection == selection {
      verifiedAccess = nil
    }
    broadcast(result)
    return result
  }

  /// A verified Pro result settles any pending payment. Otherwise a pending payment keeps the
  /// account out of checkout, including offline and across relaunch.
  private func applyingPending(_ outcome: Outcome, for selection: AccountSelection) -> SubscriptionAccess {
    if case .proVerified = outcome.access {
      if outcome.isConclusive { try? pending.remove(accountID: selection.accountID) }
      return outcome.access
    }
    guard (try? pending.load(accountID: selection.accountID)) != nil else { return outcome.access }
    return .pendingApproval
  }

  private struct Outcome {
    let access: SubscriptionAccess
    let isConclusive: Bool
  }

  private func fetchOutcome(for selection: AccountSelection) async -> Outcome {
    guard case .configured(let key) = apiKey else { return Outcome(access: .unconfirmed, isConclusive: false) }
    guard await connect(selection, apiKey: key) else { return fallback(for: selection) }
    let snapshot: CustomerAccessSnapshot
    do {
      snapshot = try await client.fetchAccessSnapshot()
    } catch {
      return fallback(for: selection)
    }
    // A switch during the fetch, or an SDK identity that no longer matches, voids the reply.
    guard selection == self.selection, client.currentAppUserID == selection.accountID else {
      return fallback(for: selection)
    }
    let checkedAt = now()
    switch snapshot.verification {
    case .serverVerified:
      return recordVerified(snapshot, checkedAt: checkedAt, for: selection)
    case .onDeviceOnly, .unverified:
      saved[snapshot.environment]?.record(.onDeviceOnly, checkedAt: checkedAt, for: selection)
      return fallback(for: selection)
    }
  }

  private func recordVerified(
    _ snapshot: CustomerAccessSnapshot, checkedAt: Date, for selection: AccountSelection
  ) -> Outcome {
    let saver = saved[snapshot.environment]
    if snapshot.isActive {
      let expiresAt = snapshot.expiresAt ?? .distantFuture
      guard expiresAt > checkedAt else {
        saver?.record(.verifiedInactive, checkedAt: checkedAt, for: selection)
        return Outcome(access: .verifiedInactive, isConclusive: true)
      }
      saver?.record(.verifiedActive(expiresAt: expiresAt), checkedAt: checkedAt, for: selection)
      return Outcome(access: .proVerified(expiresAt: expiresAt), isConclusive: true)
    }
    saver?.record(.verifiedInactive, checkedAt: checkedAt, for: selection)
    return Outcome(access: .verifiedInactive, isConclusive: true)
  }

  /// Offline or failed: only unexpired saved access counts. Otherwise access can't be confirmed.
  private func fallback(for selection: AccountSelection) -> Outcome {
    let current = now()
    for environment in savedEnvironments {
      if let access = saved[environment]?.access(for: selection, now: current),
        case .proVerified = access {
        return Outcome(access: access, isConclusive: false)
      }
    }
    return Outcome(access: .unconfirmed, isConclusive: false)
  }

  /// Configures the SDK once, then confirms its App User ID matches the selection.
  private func connect(_ selection: AccountSelection, apiKey: String) async -> Bool {
    if !client.isConfigured {
      client.configure(apiKey: apiKey, appUserID: selection.accountID)
    }
    if client.currentAppUserID != selection.accountID {
      // An operation for another selection still runs on the old SDK identity.
      while let running = operation, running.selection != selection { await waitForOperationEnd() }
      guard selection == self.selection else { return false }
      do {
        try await client.logIn(appUserID: selection.accountID)
      } catch {
        return false
      }
    }
    return selection == self.selection && client.currentAppUserID == selection.accountID
  }

  // MARK: Purchases and restores

  private enum OperationKind { case purchase, restore }

  private struct Operation {
    let id = UUID()
    let kind: OperationKind
    let selection: AccountSelection
  }

  /// Claims the single operation slot. Synchronous, so a double tap cannot get two.
  private func beginOperation(_ kind: OperationKind, for selection: AccountSelection) -> Operation? {
    guard operation == nil, selection == self.selection else { return nil }
    let started = Operation(kind: kind, selection: selection)
    operation = started
    return started
  }

  private func endOperation(_ ended: Operation) {
    guard operation?.id == ended.id else { return }
    operation = nil
    let waiters = idleWaiters
    idleWaiters = []
    waiters.forEach { $0.resume() }
  }

  private func waitForOperationEnd() async {
    await withCheckedContinuation { idleWaiters.append($0) }
  }

  func waitUntilNoInteractiveOperation() async {
    while operation != nil { await waitForOperationEnd() }
  }

  private func stale(_ selection: AccountSelection) -> SubscriptionAccessResult {
    SubscriptionAccessResult(selection: selection, access: .unconfirmed)
  }

  /// Rechecks, with a fresh check, that the account may open checkout.
  private func recheckInactive(for selection: AccountSelection) async -> Bool {
    let result = await refresh(for: selection)
    return result.selection == self.selection && result.access.allowsCheckout
      && client.currentAppUserID == selection.accountID
  }

  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult {
    guard selection == self.selection else { return stale(selection) }
    guard let running = beginOperation(.purchase, for: selection) else {
      throw SubscriptionOperationError.operationInProgress
    }
    defer { endOperation(running) }
    guard await recheckInactive(for: selection) else { throw SubscriptionOperationError.checkoutUnavailable }
    let outcome = try await client.purchase(packageID: package.id)
    return await settlePurchase(outcome, for: selection)
  }

  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult {
    guard selection == self.selection else { return stale(selection) }
    guard let running = beginOperation(.restore, for: selection) else {
      throw SubscriptionOperationError.operationInProgress
    }
    defer { endOperation(running) }
    guard await connectForOperation(selection) else { throw SubscriptionOperationError.failed }
    try await client.restorePurchases()
    guard selection == self.selection else { return stale(selection) }
    return await refresh(for: selection)
  }

  /// Records a pending payment for the initiating account, even if the selection moved on,
  /// then applies the outcome only to that selection.
  private func settlePurchase(_ outcome: PurchaseOutcome, for selection: AccountSelection) async
    -> SubscriptionAccessResult {
    switch outcome {
    case .pendingApproval: recordPending(.approval, for: selection)
    case .purchased: recordPending(.unresolvedCharge, for: selection)
    }
    guard selection == self.selection else { return stale(selection) }
    if outcome == .pendingApproval { return markPending(for: selection) }
    return await refresh(for: selection)
  }

  private func recordPending(_ kind: PendingSubscriptionOperation.Kind, for selection: AccountSelection) {
    try? pending.save(PendingSubscriptionOperation(kind: kind, startedAt: now()), accountID: selection.accountID)
  }

  private func markPending(for selection: AccountSelection) -> SubscriptionAccessResult {
    let result = SubscriptionAccessResult(selection: selection, access: .pendingApproval)
    verifiedAccess = result
    broadcast(result)
    return result
  }

  /// Makes sure the SDK identity matches before a restore, without waiting on this operation.
  private func connectForOperation(_ selection: AccountSelection) async -> Bool {
    guard case .configured(let key) = apiKey else { return false }
    return await connect(selection, apiKey: key)
  }

  // MARK: Paywall approval

  func onPurchaseInitiated(for selection: AccountSelection) async -> Bool {
    guard let running = beginOperation(.purchase, for: selection) else { return false }
    guard await recheckInactive(for: selection) else {
      endOperation(running)
      return false
    }
    return true
  }

  func onRestoreInitiated(for selection: AccountSelection) async -> Bool {
    guard let running = beginOperation(.restore, for: selection) else { return false }
    guard await connectForOperation(selection) else {
      endOperation(running)
      return false
    }
    return true
  }

  func paywallOperationFinished(_ result: PaywallOperationResult, for selection: AccountSelection) async
    -> SubscriptionAccessResult {
    // Only the operation that began for this exact selection can be finished by it.
    guard let running = operation, running.selection == selection else { return stale(selection) }
    defer { endOperation(running) }
    switch result {
    case .pendingApproval:
      recordPending(.approval, for: selection)
      guard selection == self.selection else { return stale(selection) }
      return markPending(for: selection)
    case .succeeded:
      if running.kind == .purchase { recordPending(.unresolvedCharge, for: selection) }
      guard selection == self.selection else { return stale(selection) }
      return await refresh(for: selection)
    case .cancelled, .failed:
      guard selection == self.selection else { return stale(selection) }
      return await currentAccess(for: selection)
    }
  }

  func checkPendingStatus(for selection: AccountSelection) async -> SubscriptionAccessResult {
    await refresh(for: selection)
  }

  // MARK: Updates

  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult> {
    let id = UUID()
    return AsyncStream { continuation in
      guard selection == self.selection else {
        continuation.finish()
        return
      }
      subscribers[id] = (selection, continuation)
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor in self?.subscribers[id] = nil }
      }
    }
  }

  private func broadcast(_ result: SubscriptionAccessResult) {
    for subscriber in subscribers.values where subscriber.selection == result.selection {
      subscriber.continuation.yield(result)
    }
  }

  private func finishSubscribers() {
    subscribers.values.forEach { $0.continuation.finish() }
    subscribers = [:]
  }
}
