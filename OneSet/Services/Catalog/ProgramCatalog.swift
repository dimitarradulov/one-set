import Foundation
import Observation

struct PublishedProgramCatalogSnapshot: Codable, Sendable {
  let publicationID: String?
  let entityTag: String
  let programs: [TrainingProgram]
}

enum ProgramCatalogFetchResult: Sendable {
  case notModified
  case snapshot(PublishedProgramCatalogSnapshot)
}

@MainActor
protocol ProgramCatalogService {
  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult
}

@MainActor
protocol ProgramCatalogPersistence {
  func load() throws -> PublishedProgramCatalogSnapshot?
  func save(_ snapshot: PublishedProgramCatalogSnapshot) throws
}

@MainActor
@Observable
final class ProgramCatalog {
  private(set) var programs: [TrainingProgram]
  private let bundledPrograms: [TrainingProgram]
  private let service: (any ProgramCatalogService)?
  private let persistence: (any ProgramCatalogPersistence)?
  private(set) var publicationID: String?
  private(set) var entityTag: String?

  init(
    programs: [TrainingProgram],
    service: (any ProgramCatalogService)? = nil,
    persistence: (any ProgramCatalogPersistence)? = nil
  ) {
    bundledPrograms = programs
    self.service = service
    self.persistence = persistence
    self.programs = programs
    if let persistence, let saved = try? persistence.load() {
      publicationID = saved.publicationID
      entityTag = saved.entityTag
      self.programs = Self.merge(bundled: programs, published: saved.programs)
    }
  }

  var offeredPrograms: [TrainingProgram] {
    programs.filter(\.isOffered)
  }

  func program(id: TrainingProgram.ID) -> TrainingProgram? {
    programs.first { $0.id == id }
  }

  func refresh() async {
    guard let service else { return }
    do {
      switch try await service.fetchCatalog(ifNoneMatch: entityTag) {
      case .notModified:
        return
      case .snapshot(let snapshot):
        guard !snapshot.programs.isEmpty else { return }
        try persistence?.save(snapshot)
        publicationID = snapshot.publicationID
        entityTag = snapshot.entityTag
        programs = Self.merge(bundled: bundledPrograms, published: snapshot.programs)
      }
    } catch {
      // Keep the bundled and last persisted catalog usable when the network or disk is unavailable.
    }
  }

  private static func merge(bundled: [TrainingProgram], published: [TrainingProgram]) -> [TrainingProgram] {
    var merged = bundled
    for program in published {
      if let index = merged.firstIndex(where: { $0.id == program.id }) {
        merged[index] = program
      } else {
        merged.append(program)
      }
    }
    return merged
  }
}
