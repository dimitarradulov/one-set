import SwiftUI

struct WorkoutRecordingScreen: View {
  let session: WorkoutSession
  let previousPerformances: [String: WorkoutRepository.PreviousPerformance]
  let onDiscard: () -> Void
  let onSaveDraft: (String, String, String) -> Bool
  let onComplete: (String) -> Bool
  let onUpdate: (String, String, String) -> Bool
  let onUnmark: (String) -> Bool
  let onFinish: (String?) -> Bool
  let onAdjustRest: (Int) -> Bool
  let onSkipRest: () -> Bool
  @State private var confirmsDiscard = false
  @State private var showsFinishReview = false
  @State private var confirmsEmptyDiscard = false
  @State private var noteExpanded = false
  @State private var note = ""
  @State private var expandedGuidance: Set<String> = []
  @State private var inputs: [String: WorkoutSession.SetEntry]
  @FocusState private var focusedField: Field?

  private struct Field: Hashable {
    let slotID: String
    let name: Name
    enum Name { case weight, reps }
  }

  init(session: WorkoutSession, previousPerformances: [String: WorkoutRepository.PreviousPerformance] = [:],
       onDiscard: @escaping () -> Void,
       onSaveDraft: @escaping (String, String, String) -> Bool = { _, _, _ in true },
       onComplete: @escaping (String) -> Bool = { _ in true },
       onUpdate: @escaping (String, String, String) -> Bool = { _, _, _ in true },
       onUnmark: @escaping (String) -> Bool = { _ in true },
       onAdjustRest: @escaping (Int) -> Bool = { _ in true },
       onSkipRest: @escaping () -> Bool = { true },
       onFinish: @escaping (String?) -> Bool = { _ in true }) {
    self.session = session
    self.previousPerformances = previousPerformances
    self.onDiscard = onDiscard
    self.onSaveDraft = onSaveDraft
    self.onComplete = onComplete
    self.onUpdate = onUpdate
    self.onUnmark = onUnmark
    self.onFinish = onFinish
    self.onAdjustRest = onAdjustRest
    self.onSkipRest = onSkipRest
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
        if let deadline = session.restDeadline {
          RestCountdownView(deadline: deadline, onAdjust: onAdjustRest, onSkip: onSkipRest)
        }
        ForEach(session.exercises, id: \.slotID) { exercise in
          exerciseRow(exercise)
        }
        Button("Finish workout") { showsFinishReview = true }
          .font(OneSetTypography.button)
          .foregroundStyle(Color.black)
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
          .accessibilityIdentifier("recording.finish")
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
    .sheet(isPresented: $showsFinishReview) {
      finishReview
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .confirmationDialog("No sets are complete", isPresented: $confirmsEmptyDiscard, titleVisibility: .visible) {
      Button("Discard workout", role: .destructive, action: onDiscard)
      Button("Keep recording", role: .cancel) {}
    } message: {
      Text("An empty workout cannot be saved as completed.")
    }
  }

  private var finishReview: some View {
    let completed = session.setEntries.values.filter { $0.completedAt != nil }.count
    return VStack(alignment: .leading, spacing: 18) {
      Text("Finish workout")
        .font(OneSetTypography.h1)
        .foregroundStyle(OneSetColors.textPrimary)
      Text("\(completed) of \(session.exercises.count) exercises complete")
        .font(OneSetTypography.bodyStrong)
        .foregroundStyle(OneSetColors.textPrimary)
        .accessibilityIdentifier("finish.summary.count")
      Text("Duration · \(durationLabel)")
        .font(OneSetTypography.label)
        .foregroundStyle(OneSetColors.textSecondary)
      DisclosureGroup("Add note", isExpanded: $noteExpanded) {
        TextField("Optional workout note", text: $note, axis: .vertical)
          .lineLimit(2...5)
          .textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("finish.note")
      }
      .font(OneSetTypography.label)
      .tint(OneSetColors.accent)
      Button(completed == 0 ? "Discard empty workout" : "Save completed workout") {
        if completed == 0 { confirmsEmptyDiscard = true }
        else if onFinish(note) { showsFinishReview = false }
      }
      .font(OneSetTypography.button)
      .foregroundStyle(Color.black)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
      .accessibilityIdentifier("finish.confirm")
      Spacer(minLength: 0)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(OneSetColors.background)
  }

  private var durationLabel: String {
    let elapsed = max(0, Int(Date.now.timeIntervalSince(session.startedAt)))
    return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
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
      previousPerformanceView(for: exercise)
      if let guidance = exercise.progressionGuidance(for: entry.repsInput) {
        Label(guidance, systemImage: "arrow.trend.up")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("recording.progression.\(exercise.slotID)")
      }
      DisclosureGroup("Exercise guidance", isExpanded: guidanceBinding(exercise.slotID)) {
        VStack(alignment: .leading, spacing: 12) {
          guidanceSection("Technique", text: exercise.instructions)
          guidanceSection("Stopping", text: exercise.stoppingGuidance)
          guidanceSection("Warm-up", text: exercise.warmupGuidance)
          let ranges = exercise.warmupRanges(for: entry.weightInput)
          if !ranges.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Approximate warm-up loads · not logged")
                .font(OneSetTypography.caption)
                .foregroundStyle(OneSetColors.textSecondary)
              ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
                Text("\(range.reps.lowerBound)–\(range.reps.upperBound) reps · \(formatted(range.minimumLoad))–\(formatted(range.maximumLoad)) \(session.weightUnit.rawValue)")
                  .font(OneSetTypography.caption)
                  .foregroundStyle(OneSetColors.textPrimary)
              }
            }
            .accessibilityIdentifier("recording.warmup.loads.\(exercise.slotID)")
          }
        }
        .padding(.top, 8)
      }
      .font(OneSetTypography.label)
      .tint(OneSetColors.accent)
      .accessibilityIdentifier("recording.guidance.\(exercise.slotID)")
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { Rectangle().fill(OneSetColors.border).frame(height: 1) }
  }

  @ViewBuilder
  private func previousPerformanceView(for exercise: WorkoutSession.Exercise) -> some View {
    if let result = previousPerformances[exercise.slotID] {
      VStack(alignment: .leading, spacing: 3) {
        Text(result.isSameProgramWorkout ? "Previous in this workout" : "Latest elsewhere · \(result.workoutName)")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        Text("\(result.weightInput) \(result.weightUnit.rawValue) × \(result.repsInput) reps")
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textPrimary)
        if !result.isSameProgramWorkout {
          Text("Week \(result.week) · Day \(result.day)")
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.textSecondary)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("recording.previous.\(exercise.slotID)")
    } else {
      Text("No previous result yet")
        .font(OneSetTypography.caption)
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityIdentifier("recording.previous.empty.\(exercise.slotID)")
    }
  }

  @ViewBuilder
  private func guidanceSection(_ title: String, text: String) -> some View {
    if !text.isEmpty {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(OneSetTypography.label).foregroundStyle(OneSetColors.textPrimary)
        Text(text).font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func guidanceBinding(_ slotID: String) -> Binding<Bool> {
    Binding(get: { expandedGuidance.contains(slotID) }, set: { isExpanded in
      if isExpanded { expandedGuidance.insert(slotID) }
      else { expandedGuidance.remove(slotID) }
    })
  }

  private func formatted(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    return rounded.rounded(.towardZero) == rounded && rounded.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(rounded)) : String(format: "%.1f", rounded)
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

private struct RestCountdownView: View {
  let deadline: Date
  let onAdjust: (Int) -> Bool
  let onSkip: () -> Bool

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, Int(ceil(deadline.timeIntervalSince(context.date))))
      if remaining > 0 {
        HStack(spacing: 12) {
          Image(systemName: "timer")
            .font(.system(size: 20, weight: .semibold))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 2) {
            Text("Rest")
              .font(OneSetTypography.caption)
              .foregroundStyle(OneSetColors.textSecondary)
            Text(remaining.formattedRestTime)
              .font(OneSetTypography.metric)
              .monospacedDigit()
              .foregroundStyle(OneSetColors.textPrimary)
              .accessibilityLabel("Rest remaining, \(remaining.formattedRestTime)")
          }
          Spacer(minLength: 8)
          Button("−15s") { _ = onAdjust(-15) }
            .accessibilityLabel("Reduce rest by 15 seconds")
            .accessibilityIdentifier("recording.rest.reduce")
          Button("+15s") { _ = onAdjust(15) }
            .accessibilityLabel("Add 15 seconds of rest")
            .accessibilityIdentifier("recording.rest.add")
          Button("Skip") { _ = onSkip() }
            .accessibilityIdentifier("recording.rest.skip")
        }
        .font(OneSetTypography.label)
        .buttonStyle(.bordered)
        .tint(OneSetColors.accent)
        .padding(12)
        .background(OneSetColors.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recording.rest.countdown")
      }
    }
  }
}

private extension Int {
  var formattedRestTime: String {
    String(format: "%d:%02d", self / 60, self % 60)
  }
}
