import Foundation

struct CatalogExerciseDocument: Decodable, Sendable {
  let key: String
  let name: String
  let instructions: String
  let stoppingGuidance: String
  let warmupGuidance: String
  let restSeconds: Int
  let defaultReps: CatalogRepRange
  let videoKey: String?

  func model(slotID: String? = nil, target: RepTarget? = nil, stoppingOverride: String? = nil) throws -> WorkoutExercise {
    let guidance = stoppingOverride ?? stoppingGuidance
    guard CatalogValueValidation.isStableKey(key),
          !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !warmupGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          restSeconds > 0, videoKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true,
          let defaults = RepTarget(validating: defaultReps) else {
      throw ProgramCatalogServiceError.invalidResponse
    }
    return WorkoutExercise(
      id: slotID ?? key, exerciseKey: key, name: name, repTarget: target ?? defaults,
      instructions: instructions, stoppingGuidance: guidance, warmupGuidance: warmupGuidance,
      restSeconds: restSeconds, defaultRepTarget: defaults, videoKey: videoKey
    )
  }
}
