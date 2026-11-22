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

/// Fixed-state fake that never touches RevenueCat. The `checking` preset never resolves.
@MainActor
final class PreviewSubscriptionAccessService: SubscriptionAccessService {
  private let preset: SubscriptionAccessPreset

  init(preset: SubscriptionAccessPreset) {
    self.preset = preset
  }

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
    await currentAccess(for: selection)
  }

  func updates(for selection: AccountSelection) -> AsyncStream<SubscriptionAccessResult> {
    AsyncStream { $0.finish() }
  }
}
#endif
