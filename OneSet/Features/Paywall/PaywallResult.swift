import Foundation

/// The one outcome every paywall caller (trial, workout preview, Settings) handles.
enum PaywallResult: Equatable, Sendable {
  /// OneSet verified Pro for the account.
  case verifiedPro
  /// The user closed checkout with nothing outstanding.
  case closed
  /// A payment or approval is outstanding, or Pro could not be verified after payment.
  /// Callers recheck access before deciding what to show.
  case unresolved
}
