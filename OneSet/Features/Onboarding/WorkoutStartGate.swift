import Foundation

/// What a workout preview shows in place of the plain Start button after a start attempt.
enum WorkoutStartStatus: Equatable, Sendable {
  /// One access check is running; the preview stays visible.
  case checking
  /// A fresh check verified there is no active Pro.
  case proRequired
  /// Access could not be confirmed. Offers a retry, never checkout.
  case unconfirmed
  /// A purchase is waiting for approval.
  case pendingApproval
  /// Pro is verified. The user taps Start again.
  case proActive
}

/// The gate state for one preview route, tied to the account selection it was produced for.
struct WorkoutStartGate: Equatable {
  let route: OnboardingRoute
  let selection: AccountSelection
  var status: WorkoutStartStatus
}

/// Everything a new session start depends on, captured before the access check.
struct WorkoutStartRequest {
  let selection: AccountSelection
  let programID: String
  let workoutID: String
  let week: Int?
  let cycleID: UUID
  let occurrenceWeek: Int
  let occurrenceDay: Int
  let route: OnboardingRoute
  /// Whether `route` was the visible preview when the start began.
  let routeWasVisible: Bool
}
