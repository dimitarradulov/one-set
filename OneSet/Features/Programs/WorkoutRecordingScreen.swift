import SwiftUI

struct WorkoutRecordingScreen: View {
  let session: WorkoutSession
  let model: OnboardingModel
  let authentication: AuthenticationModel
  let previousPerformances: [String: WorkoutRepository.PreviousPerformance]
  @State private var confirmsDiscard = false
  @State private var showsFinishReview = false
  @State private var confirmsEmptyDiscard = false
  @State private var noteExpanded = false
  @State private var note = ""
  @State private var failedCompletions: Set<String> = []
  @State private var warmupExercise: WorkoutSession.Exercise?
  @FocusState private var focusedField: Field?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private struct Field: Hashable {
    let slotID: String
    let name: Name
    enum Name { case weight, reps }
  }

  var body: some View {
    ScrollViewReader { scrollProxy in
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
            if exercise.slotID == session.restSlotID, let deadline = session.restDeadline {
              RestCountdownView(deadline: deadline, onAdjust: model.adjustWorkoutRest, onSkip: model.skipWorkoutRest)
                .accessibilityValue("After \(exercise.name)")
                .id("active-rest")
                .onAppear {
                  withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    // With no anchor, reveal only the portion outside the viewport.
                    scrollProxy.scrollTo("active-rest")
                  }
                }
            }
          }
          Button("Finish workout") {
            Task {
              _ = await model.applyWorkoutEdit(sessionID: session.id) {
                focusedField = nil
                showsFinishReview = true
                return true
              }
            }
          }
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
      .safeAreaInset(edge: .top, spacing: 0) {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text("Duration · \(durationLabel(at: context.date))")
            .font(OneSetTypography.label)
            .monospacedDigit()
            .foregroundStyle(OneSetColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(OneSetColors.background)
            .accessibilityIdentifier("recording.duration")
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .background(OneSetColors.background)
      .navigationTitle(session.workoutName)
      .navigationBarTitleDisplayMode(.inline)
      .alert("Discard this unfinished workout?", isPresented: $confirmsDiscard) {
        Button("Discard workout", role: .destructive, action: discard)
        Button("Keep workout", role: .cancel) {}
      } message: {
        Text("Your completed program progress will not change.")
      }
      .sheet(isPresented: $showsFinishReview) {
        finishReview
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: Binding(get: { warmupExercise != nil }, set: { if !$0 { warmupExercise = nil } })) {
        if let exercise = warmupExercise {
          WarmupSheet(exercise: exercise, unit: session.weightUnit, previous: previousPerformances[exercise.slotID])
        }
      }
      .alert("No sets are complete", isPresented: $confirmsEmptyDiscard) {
        Button("Discard workout", role: .destructive, action: discard)
        Button("Keep recording", role: .cancel) {}
      } message: {
        Text("An empty workout cannot be saved as completed.")
      }
    }
    .disabled(model.isApplyingWorkoutEdit)
    #if DEBUG
    .onAppear {
      if ProcessInfo.processInfo.arguments.contains("--ui-warmup-sheet") {
        warmupExercise = session.exercises.first
      } else if ProcessInfo.processInfo.arguments.contains("--ui-finish-review") {
        showsFinishReview = true
      }
    }
    #endif
    .onDisappear {
      Task { await model.flushWorkoutEdits(sessionID: session.id) }
    }
  }

  private func discard() {
    guard model.activeWorkoutSession?.id == session.id,
          authentication.signedInUser?.id == session.accountID else { return }
    model.discardActiveWorkout(accountID: session.accountID)
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
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Text("Duration · \(durationLabel(at: context.date))")
          .font(OneSetTypography.label)
          .monospacedDigit()
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityIdentifier("finish.duration")
      }
      DisclosureGroup("Add note", isExpanded: $noteExpanded) {
        TextField("Optional workout note", text: $note, axis: .vertical)
          .lineLimit(2...5)
          .textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("finish.note")
      }
      .font(OneSetTypography.label)
      .tint(OneSetColors.accent)
      Button(completed == 0 ? "Discard empty workout" : "Save completed workout") {
        if completed == 0 {
          confirmsEmptyDiscard = true
        } else {
          Task {
            if await model.applyWorkoutEdit(sessionID: session.id, action: {
              model.finishActiveWorkout(note: note, using: authentication)
            }) {
              showsFinishReview = false
            }
          }
        }
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

  private func durationLabel(at date: Date) -> String {
    let elapsed = max(0, Int(date.timeIntervalSince(session.startedAt)))
    return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
  }

  private func exerciseRow(_ exercise: WorkoutSession.Exercise) -> some View {
    let slotID = exercise.slotID
    let entry = session.setEntries[slotID] ?? .init()
    let saveFailed = model.workoutDraftSaves.failures[slotID] != nil
    let needsRetry = saveFailed || failedCompletions.contains(slotID)
    let isComplete = entry.completedAt != nil
    return VStack(alignment: .leading, spacing: 12) {
      exerciseLink(exercise, isComplete: isComplete)
      HStack(spacing: 10) {
        input(title: "Weight (\(session.weightUnit.rawValue))", text: weightBinding(exercise.slotID),
              field: .init(slotID: exercise.slotID, name: .weight), keyboard: .decimalPad)
        input(title: "Reps", text: repsBinding(exercise.slotID),
              field: .init(slotID: exercise.slotID, name: .reps), keyboard: .numberPad)
        Button {
          if isComplete {
            if model.unmarkWorkoutSet(slotID: slotID), saveFailed {
              Task { await model.flushWorkoutEdits(sessionID: session.id, slotID: slotID) }
            }
          } else {
            complete(slotID)
          }
        } label: {
          Label(needsRetry && !isComplete ? "Retry" : (isComplete ? "Undo" : "Complete"),
                systemImage: isComplete ? "arrow.uturn.backward" : (needsRetry ? "arrow.clockwise" : "checkmark"))
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 48, height: 48)
            .background(isComplete ? OneSetColors.accentSubtle : OneSetColors.accent, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isComplete ? OneSetColors.textPrimary : .white)
        }
        .accessibilityLabel(isComplete ? "Undo completion for \(exercise.name)" : "Complete set for \(exercise.name)")
        .accessibilityIdentifier("recording.set.toggle.\(exercise.slotID)")
      }
      if needsRetry {
        Button("Retry saving this set") {
          if failedCompletions.contains(slotID) {
            complete(slotID)
          } else {
            Task { await model.flushWorkoutEdits(sessionID: session.id, slotID: slotID) }
          }
        }
          .font(OneSetTypography.label)
          .frame(minHeight: 44)
          .accessibilityIdentifier("recording.set.retry.\(exercise.slotID)")
      }
      previousPerformanceView(for: exercise)
      Button("Warmup") { warmupExercise = exercise }
        .font(OneSetTypography.label)
        .frame(minHeight: 44)
        .accessibilityLabel("Warmup for \(exercise.name)")
        .accessibilityIdentifier("recording.warmup.\(exercise.slotID)")
      if let guidance = exercise.progressionGuidance(for: input(for: slotID).reps) {
        Label(guidance, systemImage: "arrow.trend.up")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("recording.progression.\(exercise.slotID)")
      }
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { Rectangle().fill(OneSetColors.border).frame(height: 1) }
  }
}

extension WorkoutRecordingScreen {
  private func exerciseLink(_ exercise: WorkoutSession.Exercise, isComplete: Bool) -> some View {
    NavigationLink(value: OnboardingRoute.recordingExerciseDetail(sessionID: session.id, slotID: exercise.slotID)) {
      HStack(alignment: .top, spacing: 12) {
        Text(String(format: "%02d", exercise.order + 1))
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.name).font(OneSetTypography.bodyStrong).foregroundStyle(OneSetColors.textPrimary)
          Text("Target: \(exercise.repTarget.label)")
            .font(OneSetTypography.label).foregroundStyle(OneSetColors.textSecondary)
        }
        Spacer()
        if isComplete {
          Label("Set complete", systemImage: "checkmark.circle.fill")
            .font(OneSetTypography.caption)
            .foregroundStyle(OneSetColors.accent)
            .accessibilityIdentifier("recording.set.complete.\(exercise.slotID)")
        }
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(OneSetColors.textSecondary)
          .accessibilityHidden(true)
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(exercise.name), \(exercise.repTarget.label)")
    .accessibilityHint("Opens exercise instructions, video, and performance.")
    .accessibilityIdentifier("recording.exercise.\(exercise.slotID).open")
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
          Text(result.day.map { "Week \(result.week) · Day \($0)" }
            ?? "Week \(result.week) · \(result.completedAt.formatted(date: .abbreviated, time: .omitted))")
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

  private func input(title: String, text: Binding<String>, field: Field,
                     keyboard: UIKeyboardType) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(OneSetTypography.caption).foregroundStyle(OneSetColors.textSecondary)
      TextField("-", text: text)
        .keyboardType(keyboard)
        .focused($focusedField, equals: field)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(title)
        .accessibilityIdentifier("recording.input.\(field.slotID).\(field.name)")
    }
    .frame(maxWidth: .infinity)
  }

  private func input(for slotID: String) -> WorkoutDraftSaves.Input {
    let current = model.activeWorkoutSession
    let entry = current?.id == session.id ? current?.setEntries[slotID] : session.setEntries[slotID]
    let draft = current?.id == session.id ? model.workoutDraftSaves.input(for: slotID) : nil
    return draft ?? .init(weight: entry?.weightInput ?? "", reps: entry?.repsInput ?? "")
  }

  private func weightBinding(_ slotID: String) -> Binding<String> {
    binding(slotID, keyPath: \.weight)
  }

  private func repsBinding(_ slotID: String) -> Binding<String> {
    binding(slotID, keyPath: \.reps)
  }

  private func binding(_ slotID: String, keyPath: WritableKeyPath<WorkoutDraftSaves.Input, String>) -> Binding<String> {
    Binding {
      input(for: slotID)[keyPath: keyPath]
    } set: { value in
      var edit = input(for: slotID)
      guard edit[keyPath: keyPath] != value else { return }
      edit[keyPath: keyPath] = value
      model.scheduleWorkoutEdit(sessionID: session.id, slotID: slotID, input: edit)
    }
  }

  private func complete(_ slotID: String) {
    Task {
      let saved = await model.applyWorkoutEdit(sessionID: session.id, slotID: slotID) {
        model.completeWorkoutSet(slotID: slotID)
      }
      if saved {
        failedCompletions.remove(slotID)
        focusedField = nil
      } else {
        failedCompletions.insert(slotID)
      }
    }
  }
}
