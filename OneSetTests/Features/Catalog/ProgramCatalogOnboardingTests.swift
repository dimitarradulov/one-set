import Foundation
import Testing
@testable import OneSet

@MainActor
struct ProgramCatalogOnboardingTests {
  @Test
  func refreshedProgramCanBeSelectedAlongsideTheBundledLibrary() async {
    let added = TrainingProgram(
      id: "founder-authored-plan",
      name: "Founder Authored Plan",
      format: "A / B",
      emphasis: "A newly published plan.",
      workouts: [
        WorkoutTemplate(id: "founder-plan-a", name: "Workout A", exercises: []),
        WorkoutTemplate(id: "founder-plan-b", name: "Workout B", exercises: []),
      ],
      recommendedWeeks: 6
    )
    let persistence = MemoryProgramCatalogPersistence()
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      service: StubProgramCatalogService(result: .snapshot(.init(
        publicationID: "publication-1", entityTag: "\"catalog-1\"", programs: [added]
      ))),
      persistence: persistence
    )

    await catalog.refresh()

    #expect(catalog.program(id: added.id) == added)
    #expect(added.trainingDaysPerWeek == added.workouts.count)
    #expect(catalog.offeredPrograms.count == ProgramCatalog.bundled.programs.count + 1)
    let onboarding = OnboardingModel(
      catalog: catalog,
      initialPath: [.preferences, .programs, .programDetail(added.id)]
    )
    onboarding.selectProgram(added.id)

    #expect(onboarding.selectedProgramID == added.id)
    #expect(onboarding.path.last == .trialPreview(added.id))
    #expect(persistence.snapshot?.programs == [added])
    let restartedCatalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      persistence: persistence
    )
    #expect(restartedCatalog.program(id: added.id) == added)
    #expect(restartedCatalog.offeredPrograms.count == ProgramCatalog.bundled.programs.count + 1)
  }

  @Test
  func setupRestoresAFoundingProgramPublishedAfterTheAppRelease() async {
    let added = TrainingProgram(
      id: "founder-authored-plan",
      name: "Founder Authored Plan",
      format: "A / B / C",
      emphasis: "A newly published plan.",
      workouts: [WorkoutTemplate(id: "founder-plan-a", name: "Workout A", exercises: [])],
      recommendedWeeks: 6
    )
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
    let removed = TrainingProgram(
      id: "founder-authored-plan",
      name: "Founder Authored Plan",
      format: "A / B / C",
      emphasis: "A removed program retained for current followers.",
      workouts: [WorkoutTemplate(id: "founder-plan-a", name: "Workout A", exercises: [])],
      recommendedWeeks: 6,
      isOffered: false
    )
    let persistence = MemoryProgramCatalogPersistence()
    let catalog = ProgramCatalog(
      programs: ProgramCatalog.bundled.programs,
      service: StubProgramCatalogService(result: .snapshot(.init(
        publicationID: "publication-removed", entityTag: "\"catalog-removed\"", programs: [removed]
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
}

@MainActor
private struct StubProgramCatalogService: ProgramCatalogService {
  let result: ProgramCatalogFetchResult

  func fetchCatalog(ifNoneMatch: String?) async throws -> ProgramCatalogFetchResult {
    result
  }
}

@MainActor
private final class MemoryProgramCatalogPersistence: ProgramCatalogPersistence {
  private(set) var snapshot: PublishedProgramCatalogSnapshot?

  func load() -> PublishedProgramCatalogSnapshot? { snapshot }
  func save(_ snapshot: PublishedProgramCatalogSnapshot) throws { self.snapshot = snapshot }
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
