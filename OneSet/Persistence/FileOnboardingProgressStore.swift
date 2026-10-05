import Foundation

/// An atomic, device-local file containing onboarding progress and pending setup uploads, never workout data.
@MainActor
final class FileOnboardingProgressStore: OnboardingProgressStore {
  private struct Document: Codable {
    var version = 1
    var accounts: [String: OnboardingProgress] = [:]
  }

  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func load(accountID: String) throws -> OnboardingProgress? {
    try read().accounts[accountID]
  }

  func save(_ progress: OnboardingProgress, accountID: String) throws {
    var document = try read()
    document.accounts[accountID] = progress
    try write(document)
  }

  func remove(accountID: String) throws {
    var document = try read()
    guard document.accounts.removeValue(forKey: accountID) != nil else { return }
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
