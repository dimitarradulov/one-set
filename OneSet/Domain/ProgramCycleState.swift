import Foundation

/// Account-scoped cycle knowledge and locally committed selection commands.
/// A missing or incomplete lookup must never be treated as proof that a program is new.
struct CycleRetryState: Codable, Sendable {
  var operation: String
  var attempts: Int
  var retryAfter: Date
}

struct ProgramCycleState: Codable, Sendable {
  var selectedProgramID: TrainingProgram.ID
  var selectedCycleID: UUID
  var knownCycles: [AccountCycle]
  var discoveryComplete: Bool
  /// Creation payloads retain their original IDs and start times until acknowledged.
  var pendingCreations: [AccountCycle]
  /// Locally trained cycles have complete local progress even when no sessions exist yet.
  var locallyKnownProgressCycleIDs: [UUID]? = nil
  /// Ordered desired selections, retained until the server acknowledges activation.
  var pendingActivations: [UUID]? = nil
  /// Permanently rejected creations are retained for recovery and not automatically retried.
  var rejectedCycleIDs: [UUID]? = nil
  var retry: CycleRetryState? = nil
  var authenticationDeferred: Bool? = nil
}
