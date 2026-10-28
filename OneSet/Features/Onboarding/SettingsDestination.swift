enum SettingsDestination: String, Hashable {
  case units
  case trainingFrequency
  case restAlerts
  case downloadedVideos
  case subscription
  case accountDeletion

  private var presentation: (title: String, explanation: String, symbol: String) {
    switch self {
    case .units: ("Units", "Change between kilograms and pounds here.", "scalemass")
    case .trainingFrequency: ("Training frequency", "Change how many days you plan to train each week.", "calendar")
    case .restAlerts: ("Rest alerts", "Choose whether to get a notification when rest ends.", "timer")
    case .downloadedVideos: ("Downloaded videos", "Manage exercise videos saved on this device.", "arrow.down.circle")
    case .subscription: ("Subscription", "Manage your subscription and restore purchases.", "creditcard")
    case .accountDeletion: ("Account deletion", "Delete your OneSet account and its data.", "person.crop.circle.badge.xmark")
    }
  }

  var title: String { presentation.title }
  var explanation: String { presentation.explanation }
  var symbol: String { presentation.symbol }
  var accessibilityIdentifier: String { "settings.row.\(rawValue)" }
}
