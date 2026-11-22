import Foundation

/// What the trial screen shows for the shared access decision and the setup save that follows it.
enum TrialAccessStatus: Equatable, Sendable {
  /// An access check is running.
  case checking
  /// A fresh check verified there is no active Pro. Offers plans.
  case offer
  /// Access could not be confirmed. Offers a retry, never checkout.
  case unconfirmed
  /// A purchase is waiting for approval.
  case pendingApproval
  /// Pro is verified and the setup is being saved.
  case saving
  /// Pro is verified but the setup could not be saved. Retrying never opens checkout.
  case saveFailed
}

/// The trial screen state for one program, tied to the account selection it was produced for.
struct TrialGate: Equatable {
  let programID: String
  let selection: AccountSelection
  var status: TrialAccessStatus
}
