import SwiftUI

struct WorkoutRecordingScreen: View {
  let session: WorkoutSession
  let onDiscard: () -> Void
  let onSaveDraft: (String, String, String) -> Bool
  let onComplete: (String) -> Bool
  let onUpdate: (String, String, String) -> Bool
  let onUnmark: (String) -> Bool
  @State private var confirmsDiscard = false
  @State private var inputs: [String: WorkoutSession.SetEntry]
  @FocusState private var focusedField: Field?

  private struct Field: Hashable {
    let slotID: String
    let name: Name
    enum Name { case weight, reps }
  }

  init(session: WorkoutSession, onDiscard: @escaping () -> Void,
       onSaveDraft: @escaping (String, String, String) -> Bool = { _, _, _ in true },
       onComplete: @escaping (String) -> Bool = { _ in true },
       onUpdate: @escaping (String, String, String) -> Bool = { _, _, _ in true },
       onUnmark: @escaping (String) -> Bool = { _ in true }) {
    self.session = session
    self.onDiscard = onDiscard
    self.onSaveDraft = onSaveDraft
    self.onComplete = onComplete
    self.onUpdate = onUpdate
    self.onUnmark = onUnmark
    _inputs = State(initialValue: session.setEntries)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Week \(session.week) · Day \(session.day)")
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
        Text("Your workout is saved on this device. You can leave and resume it later.")
          .font(OneSetTypography.body)
          .foregroundStyle(OneSetColors.textSecondary)
        ForEach(session.exercises, id: \.slotID) { exercise in
          exerciseRow(exercise)
        }
        Button("Discard workout", role: .destructive) { confirmsDiscard = true }
          .frame(minHeight: 44)
          .accessibilityIdentifier("recording.discard")
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(OneSetColors.background)
    .navigationTitle(session.workoutName)
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog("Discard this unfinished workout?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
      Button("Discard workout", role: .destructive, action: onDiscard)
      Button("Keep workout", role: .cancel) {}
    } message: {
      Text("Your completed program progress will not change.")
    }
  }

  private func exerciseRow(_ exercise: WorkoutSession.Exercise) -> some View {
    let entry = inputs[exercise.slotID] ?? .init()
    let isComplete = entry.completedAt != nil
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Text(String(format: "%02d", exercise.order + 1))
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.name).font(OneSetTypography.bodyStrong).foregroundStyle(OneSetColors.textPrimary)
          Text("Target: \(exercise.repTarget.label) reps")
            .font(OneSetTypography.label).foregroundStyle(OneSetColors.textSecondary)
        }
        Spacer()
        if isComplete {
          Label("Set complete", systemImage: "checkmark.circle.fill")
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.accent)
            .accessibilityIdentifier("recording.set.complete.\(exercise.slotID)")
        }
      }
      HStack(spacing: 10) {
        input(title: "Weight (\(session.weightUnit.rawValue))", text: weightBinding(exercise.slotID),
              field: .init(slotID: exercise.slotID, name: .weight), keyboard: .decimalPad)
        input(title: "Reps", text: repsBinding(exercise.slotID),
              field: .init(slotID: exercise.slotID, name: .reps), keyboard: .numberPad)
        Button {
          if isComplete {
            guard onUnmark(exercise.slotID) else { return }
            var updated = inputs[exercise.slotID] ?? .init()
            updated.completedAt = nil
            inputs[exercise.slotID] = updated
          } else if onComplete(exercise.slotID) {
            var updated = inputs[exercise.slotID] ?? .init()
            updated.completedAt = .now
            inputs[exercise.slotID] = updated
            focusedField = nil
          }
        } label: {
          Label(isComplete ? "Undo" : "Complete", systemImage: isComplete ? "arrow.uturn.backward" : "checkmark")
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 48, height: 48)
            .background(isComplete ? OneSetColors.accentSubtle : OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isComplete ? OneSetColors.textPrimary : .white)
        }
        .accessibilityLabel(isComplete ? "Undo completion for \(exercise.name)" : "Complete set for \(exercise.name)")
        .accessibilityIdentifier("recording.set.toggle.\(exercise.slotID)")
      }
      Text("No previous result yet")
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { Rectangle().fill(OneSetColors.border).frame(height: 1) }
  }

  private func input(title: String, text: Binding<String>, field: Field,
                     keyboard: UIKeyboardType) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
      TextField("—", text: text)
        .keyboardType(keyboard)
        .focused($focusedField, equals: field)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(title)
        .accessibilityIdentifier("recording.input.\(field.slotID).\(field.name)")
    }
    .frame(maxWidth: .infinity)
  }

  private func weightBinding(_ slotID: String) -> Binding<String> {
    Binding(get: { inputs[slotID]?.weightInput ?? "" }, set: { update(slotID, weight: $0) })
  }

  private func repsBinding(_ slotID: String) -> Binding<String> {
    Binding(get: { inputs[slotID]?.repsInput ?? "" }, set: { update(slotID, reps: $0) })
  }

  private func update(_ slotID: String, weight: String? = nil, reps: String? = nil) {
    var entry = inputs[slotID] ?? .init()
    if let weight { entry.weightInput = weight }
    if let reps { entry.repsInput = reps }
    inputs[slotID] = entry
    _ = onSaveDraft(slotID, entry.weightInput, entry.repsInput)
  }
}
