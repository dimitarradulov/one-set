import Foundation
import Network
import Observation

@MainActor
@Observable
final class WorkoutNetworkMonitor {
  private(set) var isConnected = false

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.oneset.network-monitor")
  private var isStarted = false

  func start() {
    guard !isStarted else { return }
    isStarted = true
    monitor.pathUpdateHandler = { [weak self] path in
      let isConnected = path.status == .satisfied
      Task { @MainActor [weak self] in self?.isConnected = isConnected }
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}
