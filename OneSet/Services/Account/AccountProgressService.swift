import Foundation

@MainActor
protocol AccountProgressService {
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress?
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress?
}

extension AccountProgressService {
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress? {
    let progress = try await lookup(for: user)
    return progress?.cycleID == cycleID ? progress : nil
  }
}
