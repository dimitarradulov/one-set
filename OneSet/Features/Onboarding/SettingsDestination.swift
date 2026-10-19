enum SettingsDestination: String, Hashable {
  case units
  case trainingFrequency
  case restAlerts
  case downloadedVideos
  case subscription
  case accountDeletion

  private var presentation: (title: String, explanation: String, symbol: String) {
    switch self {
    case .units: ("Units", "Unit preferences are coming soon.", "scalemass")
    case .trainingFrequency: ("Training frequency", "Training frequency settings are coming soon.", "calendar")
    case .restAlerts: ("Rest alerts", "Rest alert settings are coming soon.", "timer")
    case .downloadedVideos: ("Downloaded videos", "Video downloads are coming soon.", "arrow.down.circle")
    case .subscription: ("Subscription", "Subscription management is coming soon.", "creditcard")
    case .accountDeletion: ("Account deletion", "Account deletion is coming soon.", "person.crop.circle.badge.xmark")
    }
  }

  var title: String { presentation.title }
  var explanation: String { presentation.explanation }
  var symbol: String { presentation.symbol }
  var accessibilityIdentifier: String { "settings.row.\(rawValue)" }
}
