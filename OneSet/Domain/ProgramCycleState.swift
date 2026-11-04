import Foundation

/// Account-scoped cycle knowledge and locally committed selection commands.
/// A missing or incomplete lookup must never be treated as proof that a program is new.
struct ProgramCycleState: Codable, Sendable {
  var selectedProgramID: TrainingProgram.ID
  var selectedCycleID: UUID
  var knownCycles: [AccountCycle]
  var discoveryComplete: Bool
  /// Creation payloads retain their original IDs and start times until acknowledged.
  var pendingCreations: [AccountCycle]
  /// Permanently rejected creations are retained for recovery and not automatically retried.
  var rejectedCycleIDs: [UUID]? = nil
}
