#if DEBUG
import Foundation

enum SubscriptionAccessPreset: String, CaseIterable, Sendable {
  case active, inactive, checking, failed, pending

  static let activeExpiry = Date(timeIntervalSince1970: 4_102_444_800)

  var access: SubscriptionAccess {
    switch self {
    case .active: .proVerified(expiresAt: Self.activeExpiry)
    case .inactive: .verifiedInactive
    case .checking: .checking
    case .failed: .unconfirmed
    case .pending: .pendingApproval
    }
  }

  /// Reads `--ui-subscription-<preset>` from launch arguments.
  init?(arguments: [String]) {
    guard let match = Self.allCases.first(where: { arguments.contains("--ui-subscription-\($0.rawValue)") }) else {
      return nil
    }
    self = match
  }
}

/// What a fake Restore Purchases returns, from `--ui-subscription-restore-<name>`.
enum SubscriptionRestorePreset: String, CaseIterable, Sendable {
  case restored, noPurchase = "no-purchase", mismatch, failed, slow

  init?(arguments: [String]) {
    guard let match = Self.allCases.first(where: { arguments.contains("--ui-subscription-restore-\($0.rawValue)") }) else {
      return nil
    }
    self = match
  }
}

/// Fixed-state fake that never touches RevenueCat. The `checking` preset never resolves.
@MainActor
final class PreviewSubscriptionAccessService: SubscriptionAccessService, SubscriptionAccountSelecting {
  private let preset: SubscriptionAccessPreset
  private let restorePreset: SubscriptionRestorePreset?
  private var generation = 0
  private(set) var selection: AccountSelection?

  init(preset: SubscriptionAccessPreset, restore: SubscriptionRestorePreset? = nil) {
    self.preset = preset
    restorePreset = restore
  }

  @discardableResult
  func selectAccount(_ accountID: String?) -> AccountSelection? {
    if let accountID, accountID == selection?.accountID { return selection }
    generation += 1
    selection = accountID.map { AccountSelection(accountID: $0, generation: generation) }
    return selection
  }

  func appDidReturnToForeground() {}

  func currentAccess(for selection: AccountSelection) async -> SubscriptionAccessResult {
    if preset == .checking {
      try? await Task.sleep(for: .seconds(86_400))
    }
    return SubscriptionAccessResult(selection: selection, access: preset.access)
  }

  func refresh(for selection: AccountSelection) async -> SubscriptionAccessResult {
    await currentAccess(for: selection)
  }

  func purchase(_ package: SubscriptionPackage, for selection: AccountSelection) async throws
    -> SubscriptionAccessResult {
    SubscriptionAccessResult(selection: selection, access: preset == .inactive ? SubscriptionAccessPreset.active.access : preset.access)
  }

  func restore(for selection: AccountSelection) async throws -> SubscriptionAccessResult {
    switch restorePreset {
    case .restored: return SubscriptionAccessResult(selection: selection, access: SubscriptionAccessPreset.active.access)
    case .noPurchase: return SubscriptionAccessResult(selection: selection, access: .verifiedInactive)
    case .mismatch: throw SubscriptionOperationError.linkedToAnotherAccount
    case .failed: throw SubscriptionOperationError.failed
    case .slow:
      try? await Task.sleep(for: .seconds(86_400))
      throw SubscriptionOperationError.cancelled
    case nil: return await currentAccess(for: selection)
    }
  }

  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult> {
    AsyncStream { $0.finish() }
  }
}
#endif
