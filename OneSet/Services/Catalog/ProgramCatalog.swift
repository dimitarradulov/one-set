import Foundation
import Observation

struct PublishedProgramCatalogSnapshot: Codable, Equatable, Sendable {
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
  private var refreshGeneration = 0

  init(
    programs: [TrainingProgram],
    service: (any ProgramCatalogService)? = nil,
    persistence: (any ProgramCatalogPersistence)? = nil
  ) {
    bundledPrograms = programs
    self.service = service
    self.persistence = persistence
    self.programs = programs
    if let persistence, let saved = try? persistence.load(), Self.isCompatible(saved) {
      publicationID = saved.publicationID
      entityTag = saved.entityTag
      self.programs = saved.programs
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
    refreshGeneration += 1
    let generation = refreshGeneration
    do {
      switch try await service.fetchCatalog(ifNoneMatch: entityTag) {
      case .notModified:
        return
      case .snapshot(let snapshot):
        guard generation == refreshGeneration, Self.isCompatible(snapshot) else { return }
        try persistence?.save(snapshot)
        guard generation == refreshGeneration else { return }
        publicationID = snapshot.publicationID
        entityTag = snapshot.entityTag
        programs = snapshot.programs
      }
    } catch {
      // Keep the bundled and last persisted catalog usable when the network or disk is unavailable.
    }
  }

  var immutableSnapshot: [TrainingProgram] { programs }

  private static func isCompatible(_ snapshot: PublishedProgramCatalogSnapshot) -> Bool {
    guard let publicationID = snapshot.publicationID, !publicationID.isEmpty,
          !snapshot.entityTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !snapshot.programs.isEmpty else { return false }

    let programs = snapshot.programs
    guard Set(programs.map(\.id)).count == programs.count else { return false }
    var workoutIDs = Set<String>()
    var slotIDs = Set<String>()
    for program in programs {
      guard Self.isStableKey(program.id), !program.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            (2...5).contains(program.trainingDaysPerWeek), program.recommendedWeeks > 0,
            !program.format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !program.emphasis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !program.workouts.isEmpty else { return false }
      for workout in program.workouts {
        guard Self.isStableKey(workout.id), workoutIDs.insert(workout.id).inserted,
              !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !workout.exercises.isEmpty else { return false }
        for exercise in workout.exercises {
          guard Self.isStableKey(exercise.id), slotIDs.insert(exercise.id).inserted,
                Self.isStableKey(exercise.exerciseKey),
                !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.stoppingGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.warmupGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let restSeconds = exercise.restSeconds, restSeconds > 0,
                exercise.repTarget.minimum > 0, exercise.repTarget.maximum >= exercise.repTarget.minimum,
                exercise.repTarget.maximum <= 100,
                let defaultTarget = exercise.defaultRepTarget,
                defaultTarget.minimum > 0, defaultTarget.maximum >= defaultTarget.minimum,
                defaultTarget.maximum <= 100 else { return false }
        }
      }
    }
    return true
  }

  private static func isStableKey(_ value: String) -> Bool {
    !value.isEmpty && value.range(of: #"^[a-z0-9][a-z0-9_-]*$"#, options: .regularExpression) != nil
  }
}
