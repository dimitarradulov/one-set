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
}

/// The app-scoped RevenueCat owner: SDK setup, account selection, and the access check.
/// Purchases and restores arrive in a later ticket.
@MainActor
final class RevenueCatSubscriptionAccessService: SubscriptionAccessService, SubscriptionAccountSelecting {
  private let client: any PurchasesClient
  private let apiKey: RevenueCatAPIKeyConfiguration
  private let saved: [BillingEnvironment: SavedSubscriptionAccess]
  private let savedEnvironments: [BillingEnvironment]
  private let now: @MainActor () -> Date

  private(set) var selection: AccountSelection?
  private var generation = 0
  private var verifiedAccess: SubscriptionAccessResult?
  private var inFlight: (selection: AccountSelection, task: Task<SubscriptionAccessResult, Never>)?
  private var subscribers: [UUID: (selection: AccountSelection, continuation: AsyncStream<SubscriptionAccessResult>.Continuation)] = [:]

  /// - Parameter acceptsSandboxSavedAccess: Whether an offline fallback may use saved sandbox
  ///   access. Public builds pass false so a sandbox purchase never unlocks offline.
  init(
    client: any PurchasesClient,
    apiKey: RevenueCatAPIKeyConfiguration,
    store: any SavedSubscriptionAccessStore,
    acceptsSandboxSavedAccess: Bool,
    now: @escaping @MainActor () -> Date = { .now }
  ) {
    self.client = client
    self.apiKey = apiKey
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
    let result = SubscriptionAccessResult(selection: selection, access: outcome.access)
    if outcome.isConclusive {
      verifiedAccess = result
    } else if verifiedAccess?.selection == selection {
      verifiedAccess = nil
    }
    broadcast(result)
    return result
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
      do {
        try await client.logIn(appUserID: selection.accountID)
      } catch {
        return false
      }
    }
    return selection == self.selection && client.currentAppUserID == selection.accountID
  }

  // MARK: Purchases and restores (a later ticket)

  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult {
    throw SubscriptionOperationError.failed
  }

  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult {
    throw SubscriptionOperationError.failed
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
