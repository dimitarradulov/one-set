import Foundation

enum OnboardingRoute: Hashable {
  case preferences
  case programs
  case programDetail(String)
  case trialPreview(String)
  case programOverview(String)
  case workoutPreview(programID: String, workoutID: String)
  case workoutRecording(UUID)
  case recordingExerciseDetail(sessionID: UUID, slotID: String)
  case exerciseDetail(
    programID: String,
    workoutID: String,
    exerciseID: String,
    guidanceExpanded: Bool = false,
    initiallyShowingHistory: Bool = false
  )
  case emailAuthentication
}
