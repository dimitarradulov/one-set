import Foundation
import Testing
@testable import OneSet

@MainActor
struct ProgramCatalogOnboardingTests {
  @Test
  func legacyWorkoutAndUnknownBannerRemainUsableAndResolveToGeneralGym() throws {
    let decoder = JSONDecoder()
    let legacy = try decoder.decode(
      WorkoutTemplate.self,
      from: Data(#"{"id":"legacy","name":"Legacy workout","exercises":[]}"#.utf8)
    )
    #expect(legacy.banner == nil)
    #expect(WorkoutBannerAsset.assetName(for: legacy.banner) == "WorkoutBannerGeneralGym")

    let newer = try decoder.decode(
      WorkoutTemplate.self,
      from: Data(#"{"id":"newer","name":"New workout","banner":"future-theme","exercises":[]}"#.utf8)
    )
    #expect(newer.banner == "future-theme")
    #expect(WorkoutBannerAsset.assetName(for: newer.banner) == "WorkoutBannerGeneralGym")
    let themes = [
      "general-gym", "upper-body", "lower-body", "chest-push", "back-pull", "shoulders", "arms"
    ]
    #expect(themes.map { WorkoutBannerAsset.assetName(for: $0) } == [
      "WorkoutBannerGeneralGym", "WorkoutBannerUpperBody", "WorkoutBannerLowerBody",
      "WorkoutBannerChestPush", "WorkoutBannerBackPull", "WorkoutBannerShoulders", "WorkoutBannerArms"
    ])

    let legacyDocument = try decoder.decode(
      CatalogWorkoutDocument.self,
      from: Data(#"{"key":"legacy","name":"Legacy workout","exercises":[]}"#.utf8)
    )
    let newerDocument = try decoder.decode(
      CatalogWorkoutDocument.self,
      from: Data(#"{"key":"newer","name":"New workout","banner":"future-theme","exercises":[]}"#.utf8)
    )
    #expect(legacyDocument.banner == nil)
    #expect(newerDocument.banner == "future-theme")

    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "catalog.json")
    let legacySnapshot = snapshot("legacy-publication", "legacy-tag", [program(id: "legacy", name: "Legacy")])
    var savedDocument = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacySnapshot)) as? [String: Any])
    var savedPrograms = try #require(savedDocument["programs"] as? [[String: Any]])
    var savedProgram = try #require(savedPrograms.first)
    var savedWorkouts = try #require(savedProgram["workouts"] as? [[String: Any]])
    var savedWorkout = try #require(savedWorkouts.first)
    savedWorkout.removeValue(forKey: "banner")
    savedWorkouts[0] = savedWorkout
    savedProgram["workouts"] = savedWorkouts
    savedPrograms[0] = savedProgram
    savedDocument["programs"] = savedPrograms
    try JSONSerialization.data(withJSONObject: savedDocument).write(to: fileURL)
    let persistence = FileProgramCatalogPersistence(fileURL: fileURL)
    let loadedLegacy = try #require(try persistence.load())
    #expect(loadedLegacy.programs.first?.workouts.first?.banner == nil)
    #expect(loadedLegacy.programs.first?.workouts.first?.exercises.count == 1)

    let future = program(id: "future", name: "Future Theme", banner: "future-theme")
    try persistence.save(snapshot("future-publication", "future-tag", [future]))
    let loadedFuture = try #require(try persistence.load())
    #expect(loadedFuture.programs.first?.workouts.first?.banner == "future-theme")
  }

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
    #expect(added.trainingDaysPerWeek == added.workouts.count)
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
      id: "incomplete-plan", name: "Incomplete Plan",
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
}

extension ProgramCatalogOnboardingTests {
  @Test
  func browsingProgramsDoesNotChangeTheCurrentSelection() async {
    let setup = AccountSetup(preferredUnit: .pounds, trainingDays: 3,
      programID: "machine-full-body", cycleID: UUID())
    let model = OnboardingModel(catalog: .bundled, setupService: CatalogAccountSetupStub(setup: setup))
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))
    await model.resolveAccountSetup(using: authentication)

    model.showProgramSwitcher()

    #expect(model.programPath == [.programs])
    #expect(model.selectedProgramID == setup.programID)
    #expect(model.restoredCycleID == setup.cycleID)
  }

  @Test
  func setupRestoresAProgramPublishedAfterTheAppRelease() async {
    let added = program(id: "founder-authored-plan", name: "Founder Authored Plan")
    let catalog = ProgramCatalog(programs: ProgramCatalog.bundled.programs + [added])
    let setup = AccountSetup(
      preferredUnit: .pounds, trainingDays: 3, programID: added.id,
      cycleID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    )
    let model = OnboardingModel(catalog: catalog, setupService: CatalogAccountSetupStub(setup: setup))
    let authentication = AuthenticationModel(service: PreviewAuthenticationService(startsSignedIn: true))

    await model.resolveAccountSetup(using: authentication)

    #expect(catalog.offeredPrograms.contains(where: { $0.id == added.id }))
    #expect(model.program(id: added.id) == added)
    #expect(model.selectedProgramID == added.id)
    #expect(model.restoredCycleID == setup.cycleID)
    #expect(model.path == [.programOverview(added.id)])
  }

  @Test
  func removedProgramStaysAvailableToExistingFollowersButNotNewSelections() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let removed = replacing(
      program(id: "founder-authored-plan", name: "Founder Authored Plan"), offered: false
    )
    let persistence = FileProgramCatalogPersistence(fileURL: directory.appending(path: "catalog.json"))
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
    let model = OnboardingModel(catalog: restoredCatalog, setupService: CatalogAccountSetupStub(setup: setup))
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
    let setupService = CatalogAccountSetupStub(setup: nil, saveError: .programUnavailable)
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

  func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  func snapshot(
    _ publicationID: String,
    _ entityTag: String,
    _ programs: [TrainingProgram]
  ) -> PublishedProgramCatalogSnapshot {
    PublishedProgramCatalogSnapshot(publicationID: publicationID, entityTag: entityTag, programs: programs)
  }

  func program(id: String, name: String, banner: String? = nil) -> TrainingProgram {
    TrainingProgram(
      id: id, name: name, format: "A / B / C", emphasis: "A published plan.",
      workouts: [WorkoutTemplate(id: "\(id)-day-a", name: "Day A", banner: banner, exercises: [
        WorkoutExercise(
          id: "\(id)-slot-a", exerciseKey: "barbell-row", name: "Barbell Row",
          repTarget: RepTarget(minimum: 8, maximum: 12), instructions: "Row with control.",
          stoppingGuidance: "Stop when form breaks.", warmupGuidance: "Warm up gradually.",
          restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12)
        )
      ])], recommendedWeeks: 8
    )
  }

  func replacing(
    _ program: TrainingProgram,
    name: String? = nil,
    offered: Bool? = nil
  ) -> TrainingProgram {
    TrainingProgram(
      id: program.id, name: name ?? program.name,
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
struct CatalogAccountSetupStub: AccountSetupService {
  let setup: AccountSetup?
  var saveError: AccountSetupError? = nil

  func lookup(for user: AuthenticatedUser) async throws -> AccountSetup? { setup }
  func save(_ setup: AccountSetup, for user: AuthenticatedUser) async throws -> AccountSetup {
    if let saveError { throw saveError }
    return setup
  }
}

@MainActor
struct OfflineCycleService: AccountCycleService {
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    throw AccountCycleError.unavailable
  }
}

@MainActor
final class SwitchFailingStore: OnboardingProgressStore {
  let file: FileOnboardingProgressStore
  var fails = false
  init(file: FileOnboardingProgressStore) { self.file = file }
  func load(accountID: String) throws -> OnboardingProgress? { try file.load(accountID: accountID) }
  func save(_ progress: OnboardingProgress, accountID: String) throws {
    if fails { throw CocoaError(.fileWriteOutOfSpace) }
    try file.save(progress, accountID: accountID)
  }
  func remove(accountID: String) throws { try file.remove(accountID: accountID) }
}

@MainActor
struct UnavailableCycleService: AccountCycleService {
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles { throw AccountCycleError.unavailable }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws { throw AccountCycleError.unavailable }
}

@MainActor
final class RecordingCycleService: AccountCycleService {
  var knownCycles: [AccountCycle] = []
  var created: [UUID] = []
  var activated: [UUID] = []
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: knownCycles, selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws { created.append(cycle.cycleID) }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { activated.append(cycleID) }
}

@MainActor
final class BackoffCycleService: AccountCycleService {
  var available = false
  var attempts: [UUID] = []
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    attempts.append(cycle.cycleID)
    if !available { throw AccountCycleError.unavailable }
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
final class LostCycleResponseService: AccountCycleService {
  var selected: UUID
  var created: Set<UUID> = []
  var loseResponse = true
  init(selected: UUID) { self.selected = selected }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    if created.insert(cycle.cycleID).inserted { selected = cycle.cycleID }
    if loseResponse { loseResponse = false; throw AccountCycleError.unavailable }
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws { selected = cycleID }
}

@MainActor
final class SuspendedCycleService: AccountCycleService {
  private var started = false
  private var startWaiter: CheckedContinuation<Void, Never>?
  private var pending: CheckedContinuation<Void, Never>?
  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { startWaiter = $0 }
  }
  func finish() { pending?.resume(); pending = nil }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    started = true
    startWaiter?.resume()
    startWaiter = nil
    await withCheckedContinuation { pending = $0 }
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
final class AuthenticationCycleService: AccountCycleService {
  var authenticated = false
  var attempts = 0
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    attempts += 1
    if !authenticated { throw AccountCycleError.authenticationRequired }
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
struct PerCycleProgressService: AccountProgressService {
  let summaries: [UUID: AccountProgress]
  let active: AccountProgress?
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? { active }
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress? { summaries[cycleID] }
}

@MainActor
final class SuspendedCycleProgressService: AccountProgressService {
  let summary: AccountProgress
  let active: AccountProgress
  private var pending: CheckedContinuation<AccountProgress?, Never>?
  private var waiter: CheckedContinuation<Void, Never>?
  init(summary: AccountProgress, active: AccountProgress) { self.summary = summary; self.active = active }
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? { active }
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress? {
    await withCheckedContinuation { continuation in
      pending = continuation
      waiter?.resume()
      waiter = nil
    }
  }
  func waitUntilRequested() async {
    if pending != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }
  func resume() { pending?.resume(returning: summary); pending = nil }
}

@MainActor
final class RejectingCycleService: AccountCycleService {
  let rejected: UUID
  var payloads: [AccountCycle] = []
  let rejectActivation: Bool
  var creations: [UUID] = []
  var activations: [UUID] = []
  init(rejected: UUID, rejectActivation: Bool = false) {
    self.rejected = rejected
    self.rejectActivation = rejectActivation
  }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [], selectedCycleID: nil)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {
    creations.append(cycle.cycleID)
    payloads.append(cycle)
    if cycle.cycleID == rejected { throw AccountCycleError.programUnavailable }
  }
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {
    activations.append(cycleID)
    if rejectActivation && cycleID == rejected { throw AccountCycleError.programUnavailable }
  }
}

@MainActor
final class MutableCatalogService: ProgramCatalogService {
  var result: ProgramCatalogFetchResult = .notModified
  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult { result }
}

@MainActor
struct SelectedCycleService: AccountCycleService {
  let cycle: AccountCycle
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [cycle], selectedCycleID: cycle.cycleID)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {}
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
final class FailDiscoverySaveStore: OnboardingProgressStore {
  let file: FileOnboardingProgressStore
  init(file: FileOnboardingProgressStore) { self.file = file }
  func load(accountID: String) throws -> OnboardingProgress? { try file.load(accountID: accountID) }
  func save(_ progress: OnboardingProgress, accountID: String) throws {
    throw CocoaError(.fileWriteOutOfSpace)
  }
  func remove(accountID: String) throws { try file.remove(accountID: accountID) }
}

@MainActor
final class MutableSelectedCycleService: AccountCycleService {
  var cycle: AccountCycle
  init(cycle: AccountCycle) { self.cycle = cycle }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    AccountCycles(cycles: [cycle], selectedCycleID: cycle.cycleID)
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {}
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
final class InterleavedDiscoveryService: AccountCycleService {
  private var requests: [CheckedContinuation<AccountCycles, any Error>] = []
  private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
  func waitForRequests(_ count: Int) async {
    if requests.count >= count { return }
    await withCheckedContinuation { waiters.append((count, $0)) }
  }
  func respond(_ index: Int, result: Result<AccountCycles, any Error>) {
    requests[index].resume(with: result)
  }
  func lookup(for user: AuthenticatedUser) async throws -> AccountCycles {
    try await withCheckedThrowingContinuation { continuation in
      requests.append(continuation)
      let ready = waiters.filter { requests.count >= $0.0 }
      waiters.removeAll { requests.count >= $0.0 }
      for (_, waiter) in ready { waiter.resume() }
    }
  }
  func create(_ cycle: AccountCycle, for user: AuthenticatedUser) async throws {}
  func activate(_ cycleID: UUID, for user: AuthenticatedUser) async throws {}
}

@MainActor
final class FailOnSaveStore: OnboardingProgressStore {
  let file: FileOnboardingProgressStore
  let failOnSave: Int
  var saves = 0
  init(file: FileOnboardingProgressStore, failOnSave: Int) {
    self.file = file
    self.failOnSave = failOnSave
  }
  func load(accountID: String) throws -> OnboardingProgress? { try file.load(accountID: accountID) }
  func save(_ progress: OnboardingProgress, accountID: String) throws {
    saves += 1
    if saves == failOnSave { throw CocoaError(.fileWriteOutOfSpace) }
    try file.save(progress, accountID: accountID)
  }
  func remove(accountID: String) throws { try file.remove(accountID: accountID) }
}

@MainActor
final class SelectivelySuspendedProgressService: AccountProgressService {
  let active: AccountProgress
  let suspended: AccountProgress
  private var pending: CheckedContinuation<AccountProgress?, Never>?
  private var waiter: CheckedContinuation<Void, Never>?
  init(active: AccountProgress, suspended: AccountProgress) { self.active = active; self.suspended = suspended }
  func lookup(for user: AuthenticatedUser) async throws -> AccountProgress? { active }
  func lookup(cycleID: UUID, for user: AuthenticatedUser) async throws -> AccountProgress? {
    guard cycleID == suspended.cycleID else { return nil }
    return await withCheckedContinuation { continuation in
      pending = continuation
      waiter?.resume()
      waiter = nil
    }
  }
  func waitUntilRequested() async {
    if pending != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }
  func resume() { pending?.resume(returning: suspended); pending = nil }
}
