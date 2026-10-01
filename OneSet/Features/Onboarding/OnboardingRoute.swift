enum OnboardingRoute: Hashable {
  case preferences
  case programs
  case programDetail(String)
  case trialPreview(String)
  case programOverview(String)
  case login
}
