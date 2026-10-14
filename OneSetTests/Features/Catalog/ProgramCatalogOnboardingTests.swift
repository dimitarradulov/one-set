import Foundation
import Testing
@testable import OneSet

@MainActor
struct ProgramCatalogOnboardingTests {
  @Test
  func backendPublicationSurvivesOfflineRestartAndRestoresSyntheticChanges() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let persistence = FileProgramCatalogPersistence(fileURL: directory.appending(path: "catalog.json"))
    let bundled = ProgramCatalog.bundled.programs
    let edited = replacing(bundled[0], name: "Updated Machine Full Body")
    let removed = replacing(bundled[1], offered: false)
    let added = program(id: "founder-authored-plan", name: "Founder Authored Plan")
    let backendPrograms = [edited, removed] + Array(bundled.dropFirst(2)) + [added]
    let firstCatalog = ProgramCatalog(
      programs: bundled,
      service: StubProgramCatalogService(result: .snapshot(snapshot("publication-1", "\"catalog-1\"", backendPrograms))),
      persistence: persistence
    )

    await firstCatalog.refresh()

    #expect(firstCatalog.immutableSnapshot == backendPrograms)
    #expect(firstCatalog.program(id: added.id) == added)
    #expect(firstCatalog.offeredPrograms.contains(where: { $0.id == removed.id }) == false)

    let offlineRestart = ProgramCatalog(programs: bundled, persistence: persistence)
    #expect(offlineRestart.immutableSnapshot == backendPrograms)
    #expect(offlineRestart.program(id: added.id) == added)
    #expect(offlineRestart.program(id: removed.id)?.isOffered == false)

    let restored = replacing(removed, offered: true)
    let restoredCatalog = ProgramCatalog(
      programs: bundled,
      service: StubProgramCatalogService(result: .snapshot(snapshot(
        "publication-2", "\"catalog-2\"", backendPrograms.map { $0.id == restored.id ? restored : $0 }
      ))),
      persistence: persistence
    )
    await restoredCatalog.refresh()

    #expect(restoredCatalog.offeredPrograms.contains(where: { $0.id == restored.id }))
    #expect(ProgramCatalog(programs: bundled, persistence: persistence).program(id: restored.id) == restored)
  }

  @Test
  func unchangedPublicationRevalidatesUsingSavedEntityTagAndKeepsSnapshot() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let persistence = FileProgramCatalogPersistence(fileURL: directory.appending(path: "catalog.json"))
    let downloaded = snapshot("publication-1", "\"catalog-1\"", [program(id: "backend-plan", name: "Backend Plan")])
    try persistence.save(downloaded)
    let service = RecordingProgramCatalogService(result: .notModified)
    let catalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs, service: service, persistence: persistence)
    let before = catalog.immutableSnapshot

    await catalog.refresh()

    #expect(service.receivedEntityTags == [downloaded.entityTag])
    #expect(catalog.immutableSnapshot == before)
    #expect(catalog.publicationID == downloaded.publicationID)
  }

  @Test
  func failedAtomicWriteKeepsTheBundledCatalogAndDoesNotAdoptTheDownload() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appending(path: "not-a-directory")
    try Data("file".utf8).write(to: blocker)
    let bundled = ProgramCatalog.bundled.programs
    let downloaded = snapshot("publication-1", "\"catalog-1\"", [program(id: "backend-plan", name: "Backend Plan")])
    let catalog = ProgramCatalog(
      programs: bundled,
      service: StubProgramCatalogService(result: .snapshot(downloaded)),
      persistence: FileProgramCatalogPersistence(fileURL: blocker.appending(path: "catalog.json"))
    )

    await catalog.refresh()

    #expect(catalog.immutableSnapshot == bundled)
    #expect(catalog.publicationID == nil)
    #expect(catalog.entityTag == nil)
  }

  @Test
  func incompatibleDownloadKeepsLastUsableDurableCatalog() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let persistence = FileProgramCatalogPersistence(fileURL: directory.appending(path: "catalog.json"))
    let saved = snapshot("publication-1", "\"catalog-1\"", [program(id: "backend-plan", name: "Backend Plan")])
    try persistence.save(saved)
    let malformed = TrainingProgram(
      id: "incomplete-plan", name: "Incomplete Plan", trainingDaysPerWeek: 3,
      format: "A / B", emphasis: "Incomplete", workouts: [], recommendedWeeks: 8
    )
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      service: StubProgramCatalogService(result: .snapshot(snapshot("publication-2", "\"catalog-2\"", [malformed]))),
      persistence: persistence
    )

    await catalog.refresh()

    #expect(catalog.program(id: "backend-plan") == saved.programs[0])
    #expect(catalog.publicationID == saved.publicationID)
    #expect(try persistence.load() == saved)
  }

  @Test
  func overlappingRefreshesKeepTheNewestAcceptedPublication() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let persistence = FileProgramCatalogPersistence(fileURL: directory.appending(path: "catalog.json"))
    let service = GatedProgramCatalogService()
    let catalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs, service: service, persistence: persistence)
    let older = snapshot("publication-old", "\"catalog-old\"", [program(id: "older-plan", name: "Older Plan")])
    let newer = snapshot("publication-new", "\"catalog-new\"", [program(id: "newer-plan", name: "Newer Plan")])

    let olderRefresh = Task { await catalog.refresh() }
    await service.waitForRequestCount(1)
    let newerRefresh = Task { await catalog.refresh() }
    await service.waitForRequestCount(2)
    service.resumeRequest(at: 1, with: .snapshot(newer))
    await newerRefresh.value
    service.resumeRequest(at: 0, with: .snapshot(older))
    await olderRefresh.value

    #expect(catalog.program(id: "newer-plan") == newer.programs[0])
    #expect(catalog.program(id: "older-plan") == nil)
    #expect(try persistence.load() == newer)
  }

  @Test
  func refreshLeavesSelectedProgramAndCapturedSnapshotUntouched() async {
    let old = program(id: "backend-plan", name: "Backend Plan")
    let changed = replacing(old, name: "Updated Backend Plan")
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs + [old],
      service: StubProgramCatalogService(result: .snapshot(snapshot("publication-1", "\"catalog-1\"", [changed])))
    )
    let capturedSnapshot = catalog.immutableSnapshot
    let onboarding = OnboardingModel(
      catalog: catalog,
      initialPath: [.programOverview(old.id)],
      initialSelectedProgramID: old.id
    )

    await onboarding.refreshCatalog()

    #expect(onboarding.selectedProgramID == old.id)
    #expect(onboarding.path == [.programOverview(old.id)])
    #expect(catalog.program(id: old.id) == changed)
    #expect(capturedSnapshot.first(where: { $0.id == old.id }) == old)
  }

  @Test
  func setupRestoresAProgramPublishedAfterTheAppRelease() async {
    let added = program(id: "founder-authored-plan", name: "Founder Authored Plan")
    let catalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs + [added])
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: added.id,
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
    let model = OnboardingModel(catalog: catalog, setupService: StubAccountSetupService(setup: setup))
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))

    await model.resolveAccountSetup(using: authentication)

    #expect(catalog.offeredPrograms.contains(where: { $0.id == added.id }))
    #expect(model.program(id: added.id) == added)
    #expect(model.selectedProgramID == added.id)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.path == [.programOverview(added.id)])
  }

  @Test
  func removedProgramStaysAvailableToExistingFollowersButNotNewSelections() async {
    let removed = replacing(
      program(id: "founder-authored-plan", name: "Founder Authored Plan"), offered: false
    )
    let persistence = MemoryProgramCatalogPersistence()
    let completeCatalog = ProgramCatalog.bundled.programs + [removed]
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      service: StubProgramCatalogService(result: .snapshot(.init(
        publicationID: "publication-removed", entityTag: "\"catalog-removed\"", programs: completeCatalog
      ))),
      persistence: persistence
    )
    await catalog.refresh()
    let restoredCatalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs, persistence: persistence)
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: removed.id,
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
    let model = OnboardingModel(catalog: restoredCatalog, setupService: StubAccountSetupService(setup: setup))
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))

    await model.resolveAccountSetup(using: authentication)

    #expect(restoredCatalog.program(id: removed.id) == removed)
    #expect(!restoredCatalog.offeredPrograms.contains(where: { $0.id == removed.id }))
    #expect(!model.programs.contains(where: { $0.id == removed.id }))
    #expect(model.selectedProgramID == removed.id)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.path == [.programOverview(removed.id)])

    model.path = [.preferences, .programs, .programDetail(removed.id)]
    model.selectProgram(removed.id)
    #expect(model.path.last == .programDetail(removed.id))
  }

  @Test
  func removedProgramPendingUploadOffersSelectionOfAnAvailableProgram() async {
    let catalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs)
    let setupService = StubAccountSetupService(setup: nil, saveError: .programUnavailable)
    let model = OnboardingModel(catalog: catalog, setupService: setupService)
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))

    await model.resolveAccountSetup(using: authentication)
    model.path = [.preferences, .programs, .programDetail("machine-full-body")]
    model.selectProgram("machine-full-body")
    model.continueWithoutTrial()

    #expect(model.hasPendingSetup)
    await model.uploadCompletedSetup(using: authentication)

    #expect(!model.hasPendingSetup)
    #expect(model.selectedProgramID == nil)
    #expect(model.path == [.preferences, .programs])
    #expect(model.programSelectionMessage?.contains("no longer available") == true)
    #expect(!model.hasCompletedSetup)
  }

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func snapshot(
    _ publicationID: String,
    _ entityTag: String,
    _ programs: [TrainingProgram]
  ) -> PublishedProgramCatalogSnapshot {
    PublishedProgramCatalogSnapshot(publicationID: publicationID, entityTag: entityTag, programs: programs)
  }

  private func program(id: String, name: String) -> TrainingProgram {
    TrainingProgram(
      id: id, name: name, trainingDaysPerWeek: 3, format: "A / B / C", emphasis: "A published plan.",
      workouts: [WorkoutTemplate(id: "\(id)-day-a", name: "Day A", exercises: [
        WorkoutExercise(
          id: "\(id)-slot-a", exerciseKey: "barbell-row", name: "Barbell Row",
          repTarget: RepTarget(minimum: 8, maximum: 12), instructions: "Row with control.",
          stoppingGuidance: "Stop when form breaks.", warmupGuidance: "Warm up gradually.",
          restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12)
        )
      ])], recommendedWeeks: 8
    )
  }

  private func replacing(
    _ program: TrainingProgram,
    name: String? = nil,
    offered: Bool? = nil
  ) -> TrainingProgram {
    TrainingProgram(
      id: program.id, name: name ?? program.name, trainingDaysPerWeek: program.trainingDaysPerWeek,
      format: program.format, emphasis: program.emphasis, workouts: program.workouts,
      recommendedWeeks: program.recommendedWeeks, isOffered: offered ?? program.isOffered
    )
  }
}

@MainActor
private struct StubProgramCatalogService: ProgramCatalogService {
  let result: ProgramCatalogFetchResult

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    result
  }
}

@MainActor
private final class RecordingProgramCatalogService: ProgramCatalogService {
  let result: ProgramCatalogFetchResult
  private(set) var receivedEntityTags: [String?] = []

  init(result: ProgramCatalogFetchResult) { self.result = result }

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    receivedEntityTags.append(ifNoneMatch)
    return result
  }
}

@MainActor
private final class GatedProgramCatalogService: ProgramCatalogService {
  private var requests: [CheckedContinuation<ProgramCatalogFetchResult, any Error>] = []
  private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    try await withCheckedThrowingContinuation { continuation in
      requests.append(continuation)
      let ready = countWaiters.filter { requests.count >= $0.0 }
      countWaiters.removeAll { requests.count >= $0.0 }
      ready.forEach { $0.1.resume() }
    }
  }

  func waitForRequestCount(_ count: Int) async {
    guard requests.count < count else { return }
    await withCheckedContinuation { countWaiters.append((count, $0)) }
  }

  func resumeRequest(at index: Int, with result: ProgramCatalogFetchResult) {
    requests[index].resume(returning: result)
  }
}

@MainActor
private struct StubAccountSetupService: AccountSetupService {
  let setup: AccountSetup?
  var saveError: AccountSetupError? = nil

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { setup }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    if let saveError { throw saveError }
    return setup
  }
}
