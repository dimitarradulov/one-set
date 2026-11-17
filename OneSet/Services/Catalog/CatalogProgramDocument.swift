import Foundation

struct CatalogProgramDocument: Decodable, Sendable {
  let key: String
  let name: String
  let recommendedWeeks: Int
  let format: String
  let emphasis: String
  let removed: Bool?
  let workouts: [CatalogWorkoutDocument]

  func model(exercises: [String: CatalogExerciseDocument]) throws -> TrainingProgram {
    guard CatalogValueValidation.isStableKey(key), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          recommendedWeeks > 0,
          !format.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !emphasis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !workouts.isEmpty else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    let visibleWorkouts = try workouts.filter { $0.removed != true }.map { workout in
      guard CatalogValueValidation.isStableKey(workout.key), !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !workout.exercises.isEmpty else {
        throw ProgramCatalogServiceError.invalidResponse
      }
      let slots = try workout.exercises.filter { $0.removed != true }.map { slot in
        guard CatalogValueValidation.isStableKey(slot.key), let exercise = exercises[slot.exercise] else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        let scope: RepTarget.Scope
        switch slot.scope {
        case nil, "reps": scope = .reps
        case "each_leg": scope = .eachLeg
        case "each_side": scope = .eachSide
        default: throw ProgramCatalogServiceError.invalidResponse
        }
        guard let target = RepTarget(validating: slot.reps, scope: scope) else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        return try exercise.model(slotID: slot.key, target: target, stoppingOverride: slot.stoppingGuidance)
      }
      var pairedSlots = Set<String>()
      for pair in workout.supersets ?? [] {
        guard let first = slots.firstIndex(where: { $0.id == pair.firstSlotID }),
              slots.indices.contains(first + 1), slots[first + 1].id == pair.secondSlotID,
              pairedSlots.insert(pair.firstSlotID).inserted,
              pairedSlots.insert(pair.secondSlotID).inserted else {
          throw ProgramCatalogServiceError.invalidResponse
        }
      }
      return WorkoutTemplate(
        id: workout.key, name: workout.name, banner: workout.banner, weekParity: workout.weekParity,
        exercises: slots, supersets: workout.supersets
      )
    }
    let oddCount = visibleWorkouts.count { $0.weekParity != .even }
    let evenCount = visibleWorkouts.count { $0.weekParity != .odd }
    guard (1...5).contains(oddCount), oddCount == evenCount else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    return TrainingProgram(
      id: key,
      name: name,
      format: format,
      emphasis: emphasis,
      workouts: visibleWorkouts,
      recommendedWeeks: recommendedWeeks,
      isOffered: removed != true
    )
  }
}
