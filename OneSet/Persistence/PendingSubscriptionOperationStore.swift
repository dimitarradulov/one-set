import Foundation

/// Durable storage for the payment still unresolved for each account, so pending approval
/// survives relaunch and stays with the account that started it.
@MainActor
protocol PendingSubscriptionOperationStore {
  func load(accountID: String) throws -> PendingSubscriptionOperation?
  func save(_ operation: PendingSubscriptionOperation, accountID: String) throws
  func remove(accountID: String) throws
}

/// An atomic, device-local file holding pending operations, never workout data.
@MainActor
final class FilePendingSubscriptionOperationStore: PendingSubscriptionOperationStore {
  private struct Document: Codable {
    var version = 1
    var operations: [String: PendingSubscriptionOperation] = [:]
  }

  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func load(accountID: String) throws -> PendingSubscriptionOperation? {
    try read().operations[accountID]
  }

  func save(_ operation: PendingSubscriptionOperation, accountID: String) throws {
    var document = try read()
    document.operations[accountID] = operation
    try write(document)
  }

  func remove(accountID: String) throws {
    var document = try read()
    guard document.operations.removeValue(forKey: accountID) != nil else { return }
    try write(document)
  }

  private func read() throws -> Document {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return Document() }
    let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: fileURL))
    guard document.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
    return document
  }

  private func write(_ document: Document) throws {
    var directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try directory.setResourceValues(resourceValues)
    try JSONEncoder().encode(document).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
  }
}
