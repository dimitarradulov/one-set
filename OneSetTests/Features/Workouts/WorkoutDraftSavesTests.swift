import Foundation
import Testing
@testable import OneSet

@MainActor
struct WorkoutDraftSavesTests {
  @Test(.timeLimit(.minutes(1)))
  func quickEditsSaveOnlyTheLatestWeightAndRepsAfterOneSecond() async throws {
    let saves = WorkoutDraftSaves()
    let (events, writes) = AsyncStream<ContinuousClock.Instant>.makeStream()
    defer { writes.finish() }
    let clock = ContinuousClock()
    var saved: [WorkoutDraftSaves.Input] = []
    let save: WorkoutDraftSaves.Save = { _, input in
      saved.append(input)
      writes.yield(clock.now)
    }

    saves.schedule(.init(weight: "32", reps: ""), for: "slot", save: save)
    saves.schedule(.init(weight: "54", reps: ""), for: "slot", save: save)
    saves.schedule(.init(weight: "52", reps: ""), for: "slot", save: save)
    let lastEdit = clock.now
    let latest = WorkoutDraftSaves.Input(weight: "52", reps: "8")
    saves.schedule(latest, for: "slot", save: save)

    #expect(saved.isEmpty)
    #expect(saves.input(for: "slot") == latest)
    var eventsIterator = events.makeAsyncIterator()
    let firstWrite = try #require(await eventsIterator.next())
    #expect(lastEdit.duration(to: firstWrite) >= .seconds(1))
    #expect(await saves.flush(save: save))
    #expect(saved == [latest])
    #expect(saves.input(for: "slot") == nil)
  }

  @Test
  func failedFlushRetainsInputForRetry() async {
    let saves = WorkoutDraftSaves()
    let input = WorkoutDraftSaves.Input(weight: "52", reps: "8")
    var attempts = 0
    let save: WorkoutDraftSaves.Save = { _, _ in
      attempts += 1
      if attempts == 1 { throw CocoaError(.fileWriteOutOfSpace) }
    }
    saves.schedule(input, for: "slot", save: save)

    #expect(!(await saves.flush(slotID: "slot", save: save)))
    #expect(saves.input(for: "slot") == input)
    #expect(saves.failures["slot"] != nil)
    #expect(await saves.flush(slotID: "slot", save: save))
    #expect(attempts == 2)
    #expect(saves.input(for: "slot") == nil)
    #expect(saves.failures.isEmpty)
  }
}
