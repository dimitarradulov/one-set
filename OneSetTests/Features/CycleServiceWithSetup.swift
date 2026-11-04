import Foundation
@testable import OneSet

/// Test account fixtures include their existing setup in the complete cycle lookup.
@MainActor
struct CycleServiceWithSetup: AccountCycleService {
  let service: any AccountCycleService
  let setup: AccountSetup

  init(_ service: any AccountCycleService, setup: AccountSetup) {
    self.service = service
    self.setup = setup
  }

  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    let result = try await service.lookup(for: user)
    guard !result.cycles.contains(where: { $0.cycleID == setup.cycleID }) else { return result }
    let current = AccountCycle(cycleID: setup.cycleID, programID: setup.programID,
      startedAt: "2026-01-01T00:00:00Z")
    return AccountCycles(cycles: result.cycles + [current], selectedCycleID: result.selectedCycleID)
  }

  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    try await service.create(cycle, for: user)
  }

  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {
    try await service.activate(cycleID, for: user)
  }
}
