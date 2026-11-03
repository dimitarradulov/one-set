import Foundation

@MainActor
protocol AccountProgressService {
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress?
}
