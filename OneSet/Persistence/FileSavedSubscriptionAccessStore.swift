import Foundation

/// An atomic, device-local file holding saved subscription access, never workout data.
@MainActor
final class FileSavedSubscriptionAccessStore: SavedSubscriptionAccessStore {
  private struct Entry: Codable {
    var accountID: String
    var environment: BillingEnvironment
    var record: SavedSubscriptionRecord
  }

  private struct Document: Codable {
    var version = 1
    var entries: [Entry] = []
  }

  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func load(accountID: String, environment: BillingEnvironment) throws -> SavedSubscriptionRecord? {
    try read().entries.first { $0.accountID == accountID && $0.environment == environment }?.record
  }

  func save(_ record: SavedSubscriptionRecord, accountID: String, environment: BillingEnvironment) throws {
    var document = try read()
    document.entries.removeAll { $0.accountID == accountID && $0.environment == environment }
    document.entries.append(Entry(accountID: accountID, environment: environment, record: record))
    try write(document)
  }

  func removeAll(accountID: String) throws {
    var document = try read()
    let count = document.entries.count
    document.entries.removeAll { $0.accountID == accountID }
    guard document.entries.count != count else { return }
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
