import Foundation

@MainActor
struct FileProgramCatalogPersistence: ProgramCatalogPersistence {
  let fileURL: URL

  func load() throws -> PublishedProgramCatalogSnapshot? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    let data = try Data(contentsOf: fileURL)
    let snapshot = try JSONDecoder().decode(PublishedProgramCatalogSnapshot.self, from: data)
    guard !snapshot.programs.isEmpty else { throw ProgramCatalogPersistenceError.emptySnapshot }
    return snapshot
  }

  func save(_ snapshot: PublishedProgramCatalogSnapshot) throws {
    guard !snapshot.programs.isEmpty else { throw ProgramCatalogPersistenceError.emptySnapshot }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }
}
