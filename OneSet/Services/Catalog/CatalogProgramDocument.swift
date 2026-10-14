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
        guard CatalogValueValidation.isStableKey(slot.key), let exercise = exercises[slot.exercise],
              CatalogValueValidation.isStableKey(exercise.key),
              !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.stoppingGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !exercise.warmupGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              exercise.restSeconds > 0,
              exercise.videoKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true,
              CatalogValueValidation.isValidRepRange(
                minimum: exercise.defaultReps.minimum, maximum: exercise.defaultReps.maximum
              ),
              CatalogValueValidation.isValidRepRange(minimum: slot.reps.minimum, maximum: slot.reps.maximum) else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        let scope: RepTarget.Scope
        switch slot.scope {
        case nil, "reps": scope = .reps
        case "each_leg": scope = .eachLeg
        case "each_side": scope = .eachSide
        default: throw ProgramCatalogServiceError.invalidResponse
        }
        guard let target = RepTarget(validating: slot.reps, scope: scope),
              let defaultTarget = RepTarget(validating: exercise.defaultReps) else {
          throw ProgramCatalogServiceError.invalidResponse
        }
        return WorkoutExercise(
          id: slot.key,
          exerciseKey: exercise.key,
          name: exercise.name,
          repTarget: target,
          instructions: exercise.instructions,
          stoppingGuidance: exercise.stoppingGuidance,
          warmupGuidance: exercise.warmupGuidance,
          restSeconds: exercise.restSeconds,
          defaultRepTarget: defaultTarget,
          videoKey: exercise.videoKey
        )
      }
      return WorkoutTemplate(id: workout.key, name: workout.name, exercises: slots)
    }
    guard (1...5).contains(visibleWorkouts.count) else {
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
