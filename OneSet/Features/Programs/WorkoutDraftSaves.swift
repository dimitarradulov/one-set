import Foundation
import Observation

@MainActor
@Observable
final class WorkoutDraftSaves {
  struct Input: Equatable, Sendable {
    var weight: String
    var reps: String
  }

  private struct Edit {
    let id = UUID()
    let input: Input
  }

  private(set) var failures: [String: String] = [:]
  private var edits: [String: Edit] = [:]
  @ObservationIgnored private var timers: [String: Task<Void, Never>] = [:]
  @ObservationIgnored private var ready: Set<String> = []
  @ObservationIgnored private var savingEditID: UUID?
  @ObservationIgnored private var worker: Task<Void, Never>?

  func input(for slotID: String) -> Input? { edits[slotID]?.input }

  func schedule(_ input: Input, for slotID: String, save: @escaping Save) {
    guard edits[slotID]?.input != input else { return }
    let edit = Edit(input: input)
    edits[slotID] = edit
    failures[slotID] = nil
    ready.remove(slotID)
    timers[slotID]?.cancel()
    timers[slotID] = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(1)) } catch { return }
      guard !Task.isCancelled, let self, edits[slotID]?.id == edit.id else { return }
      timers[slotID] = nil
      ready.insert(slotID)
      startWorker(save: save)
    }
  }

  typealias Save = @MainActor (String, Input) async throws -> Void

  func flush(slotID: String? = nil, save: @escaping Save) async -> Bool {
    let slots = slotID.map { [$0] } ?? Array(edits.keys)
    for slot in slots {
      guard let edit = edits[slot], edit.id != savingEditID else { continue }
      timers.removeValue(forKey: slot)?.cancel()
      ready.insert(slot)
    }
    startWorker(save: save)
    await worker?.value
    return slots.allSatisfy { edits[$0] == nil }
  }

  func cancel() {
    for timer in timers.values { timer.cancel() }
    timers.removeAll()
    ready.removeAll()
    edits.removeAll()
    failures.removeAll()
  }

  private func startWorker(save: @escaping Save) {
    guard worker == nil, !ready.isEmpty else { return }
    worker = Task {
      defer { worker = nil }
      while let slot = ready.popFirst() {
        guard let edit = edits[slot] else { continue }
        savingEditID = edit.id
        do {
          try await save(slot, edit.input)
          if edits[slot]?.id == edit.id {
            edits[slot] = nil
            failures[slot] = nil
          }
        } catch {
          if edits[slot]?.id == edit.id {
            failures[slot] = error.localizedDescription
          }
        }
        savingEditID = nil
      }
    }
  }
}
