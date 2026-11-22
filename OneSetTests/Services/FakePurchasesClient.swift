import Foundation
@testable import OneSet

/// Test seam for the SDK. Fetches and logins wait until the test releases them.
@MainActor
final class FakePurchasesClient: PurchasesClient {
  private(set) var isConfigured = false
  private(set) var currentAppUserID: String?
  private(set) var configureCalls: [(apiKey: String, appUserID: String)] = []
  private(set) var loginCalls: [String] = []
  private(set) var fetchCount = 0
  var loginError: (any Error)?
  var holdsFetches = false
  private var heldFetches: [CheckedContinuation<Result<CustomerAccessSnapshot, any Error>, Never>] = []
  var nextSnapshot: Result<CustomerAccessSnapshot, any Error> = .failure(SubscriptionOperationError.failed)

  func configure(apiKey: String, appUserID: String) {
    isConfigured = true
    currentAppUserID = appUserID
    configureCalls.append((apiKey, appUserID))
  }

  func logIn(appUserID: String) async throws {
    loginCalls.append(appUserID)
    if let loginError { throw loginError }
    currentAppUserID = appUserID
  }

  func fetchAccessSnapshot() async throws -> CustomerAccessSnapshot {
    fetchCount += 1
    if holdsFetches {
      return try await withCheckedContinuation { heldFetches.append($0) }.get()
    }
    return try nextSnapshot.get()
  }

  func waitForHeldFetch() async {
    while heldFetches.isEmpty { await Task.yield() }
  }

  func releaseFetches(with result: Result<CustomerAccessSnapshot, any Error>) {
    let held = heldFetches
    heldFetches = []
    held.forEach { $0.resume(returning: result) }
  }

  // MARK: Purchases and restores

  private(set) var purchaseCalls: [String] = []
  private(set) var restoreCount = 0
  var holdsOperations = false
  var nextPurchase: Result<PurchaseOutcome, any Error> = .success(.purchased)
  var nextRestore: Result<Void, any Error> = .success(())
  private var heldPurchases: [CheckedContinuation<Result<PurchaseOutcome, any Error>, Never>] = []
  private var heldRestores: [CheckedContinuation<Result<Void, any Error>, Never>] = []

  func purchase(packageID: String) async throws -> PurchaseOutcome {
    purchaseCalls.append(packageID)
    if holdsOperations {
      return try await withCheckedContinuation { heldPurchases.append($0) }.get()
    }
    return try nextPurchase.get()
  }

  func restorePurchases() async throws {
    restoreCount += 1
    if holdsOperations {
      return try await withCheckedContinuation { heldRestores.append($0) }.get()
    }
    return try nextRestore.get()
  }

  func waitForHeldPurchase() async {
    while heldPurchases.isEmpty { await Task.yield() }
  }

  func releasePurchases(with result: Result<PurchaseOutcome, any Error>) {
    let held = heldPurchases
    heldPurchases = []
    held.forEach { $0.resume(returning: result) }
  }
}
