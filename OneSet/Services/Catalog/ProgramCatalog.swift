import Foundation
import Observation

@MainActor
@Observable
final class ProgramCatalog {
  private(set) var programs: [TrainingProgram]
  private let bundledExercises: [WorkoutExercise]
  private var publishedExercises: [WorkoutExercise]?
  private let service: (any ProgramCatalogService)?
  private let persistence: (any ProgramCatalogPersistence)?
  private(set) var publicationID: String?
  private(set) var entityTag: String?
  private var refreshGeneration = 0

  init(
    programs: [TrainingProgram],
    bundledExercises: [WorkoutExercise] = [],
    service: (any ProgramCatalogService)? = nil,
    persistence: (any ProgramCatalogPersistence)? = nil
  ) {
    self.bundledExercises = bundledExercises
    self.service = service
    self.persistence = persistence
    self.programs = programs
    if let persistence, let saved = try? persistence.load(), Self.isCompatible(saved) {
      publicationID = saved.publicationID
      entityTag = saved.entityTag
      self.programs = saved.programs
      publishedExercises = saved.exerciseLibrary
    }
  }

  var exerciseLibrary: [String: WorkoutExercise] {
    let programmed = programs.flatMap { $0.workouts.flatMap(\.exercises) }
    let entries = publishedExercises ?? (programmed + bundledExercises)
    return Dictionary(entries.map { ($0.exerciseKey, $0) }, uniquingKeysWith: { first, _ in first })
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
      // Older caches contain workout slots only. Refresh once to fetch the full exercise library.
      switch try await service.fetchCatalog(ifNoneMatch: publishedExercises == nil ? nil : entityTag) {
      case .notModified:
        return
      case .snapshot(let snapshot):
        guard generation == refreshGeneration, Self.isCompatible(snapshot) else { return }
        try persistence?.save(snapshot)
        guard generation == refreshGeneration else { return }
        publicationID = snapshot.publicationID
        entityTag = snapshot.entityTag
        programs = snapshot.programs
        publishedExercises = snapshot.exerciseLibrary
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
      guard CatalogValueValidation.isStableKey(program.id), !program.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            (1...5).contains(program.trainingDaysPerWeek), program.recommendedWeeks > 0,
            !program.format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !program.emphasis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !program.workouts.isEmpty else { return false }
      for workout in program.workouts {
        guard CatalogValueValidation.isStableKey(workout.id), workoutIDs.insert(workout.id).inserted,
              !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !workout.exercises.isEmpty else { return false }
        for exercise in workout.exercises {
          guard CatalogValueValidation.isStableKey(exercise.id), slotIDs.insert(exercise.id).inserted,
                CatalogValueValidation.isStableKey(exercise.exerciseKey),
                !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.stoppingGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !exercise.warmupGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                let restSeconds = exercise.restSeconds, restSeconds > 0,
                CatalogValueValidation.isValidRepRange(
                  minimum: exercise.repTarget.minimum, maximum: exercise.repTarget.maximum
                ),
                let defaultTarget = exercise.defaultRepTarget,
                CatalogValueValidation.isValidRepRange(
                  minimum: defaultTarget.minimum, maximum: defaultTarget.maximum
                ) else { return false }
        }
      }
    }
    return true
  }
}
