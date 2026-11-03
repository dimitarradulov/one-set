import SwiftUI

struct HistoryScreen: View {
  @State private var model: HistoryModel
  @State private var path: [UUID] = []
  @State private var initialRouteHandled = false
  let isActive: Bool
  let initialSessionID: UUID?

  init(
    accountID: String,
    displayUnit: WeightUnit,
    isActive: Bool,
    initialSessionID: UUID? = nil,
    loadSessions: @escaping @MainActor (String) throws -> [WorkoutSession],
    resolveProgramName: @escaping @MainActor (String) -> String?
  ) {
    _model = State(initialValue: HistoryModel(
      accountID: accountID,
      displayUnit: displayUnit,
      loadSessions: loadSessions,
      resolveProgramName: resolveProgramName
    ))
    self.isActive = isActive
    self.initialSessionID = initialSessionID
  }

  var body: some View {
    NavigationStack(path: $path) {
      content
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: UUID.self) { sessionID in
          if let session = model.session(id: sessionID) {
            HistorySessionDetailScreen(
              session: session,
              programName: model.programName(for: session),
              displayWeight: { entry in model.formattedWeight(entry, in: session) },
              completedCount: model.completedExerciseCount(for: session),
              duration: model.duration(for: session)
            )
          } else {
            ContentUnavailableView("Session unavailable", systemImage: "clock.arrow.circlepath")
          }
        }
    }
    .task {
      await model.reload()
      guard !initialRouteHandled else { return }
      initialRouteHandled = true
      if let initialSessionID, model.session(id: initialSessionID) != nil {
        path = [initialSessionID]
      }
    }
    .onChange(of: isActive) { _, active in
      if active { Task { await model.reload() } }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
      model.refreshCalendarContext()
    }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoading && model.sessions.isEmpty && model.loadError == nil {
      ProgressView("Loading saved workouts…")
        .font(OneSetTypography.body)
        .accessibilityIdentifier("history.loading")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if model.loadError != nil, model.sessions.isEmpty {
      ContentUnavailableView {
        Label("History couldn’t be loaded", systemImage: "exclamationmark.triangle")
      } description: {
        Text("Saved workouts on this device are still kept. Try loading them again.")
      } actions: {
        Button("Try again", systemImage: "arrow.clockwise") { Task { await model.reload() } }
          .accessibilityIdentifier("history.retry")
      }
    } else if model.sessions.isEmpty {
      ContentUnavailableView {
        Label("No workouts on this device", systemImage: "clock.arrow.circlepath")
      } description: {
        Text("Completed workouts saved on this device will appear here.")
      }
      .accessibilityIdentifier("history.empty")
    } else {
      List {
        if model.loadError != nil {
          Section {
            Label("Some saved workouts couldn’t be refreshed.", systemImage: "exclamationmark.triangle")
              .font(OneSetTypography.label)
              .foregroundStyle(OneSetColors.textSecondary)
            Button("Try again", systemImage: "arrow.clockwise") { Task { await model.reload() } }
              .accessibilityIdentifier("history.retry")
          }
        }
        ForEach(model.months()) { month in
          Section(month.title) {
            ForEach(month.sessions) { session in
              Button {
                path.append(session.id)
              } label: {
                HistorySessionRow(
                  session: session,
                  programName: model.programName(for: session),
                  completedCount: model.completedExerciseCount(for: session)
                )
              }
              .buttonStyle(.plain)
              .accessibilityLabel(HistorySessionRow.accessibilityLabel(
                for: session,
                programName: model.programName(for: session),
                completedCount: model.completedExerciseCount(for: session)
              ))
              .accessibilityIdentifier("history.session.\(session.id.uuidString)")
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(OneSetColors.background)
      .refreshable { await model.reload() }
      .accessibilityIdentifier("history.list")
    }
  }
}

private struct HistorySessionRow: View {
  let session: WorkoutSession
  let programName: String
  let completedCount: Int

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day()))
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
        Text(session.workoutName)
          .font(OneSetTypography.bodyStrong)
          .foregroundStyle(OneSetColors.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
        Text(programName)
          .font(OneSetTypography.label)
          .foregroundStyle(OneSetColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("\(completedCount) of \(session.exercises.count) exercises completed")
          .font(OneSetTypography.caption)
          .foregroundStyle(OneSetColors.textSecondary)
      }
      Spacer(minLength: 4)
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(OneSetColors.textSecondary)
        .accessibilityHidden(true)
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }

  static func accessibilityLabel(for session: WorkoutSession, programName: String, completedCount: Int) -> String {
    "\(session.startedAt.formatted(date: .complete, time: .omitted)), \(session.workoutName), \(programName), \(completedCount) of \(session.exercises.count) exercises completed"
  }
}

private struct HistorySessionDetailScreen: View {
  let session: WorkoutSession
  let programName: String
  let displayWeight: (WorkoutSession.SetEntry) -> String?
  let completedCount: Int
  let duration: String

  var body: some View {
    List {
      Section("Workout") {
        LabeledContent("Program", value: programName)
        LabeledContent("Workout", value: session.workoutName)
        LabeledContent("Training", value: "Week \(session.week) · Day \(session.day)")
        LabeledContent("Completed", value: "\(completedCount) of \(session.exercises.count) exercises")
      }

      Section("Session") {
        LabeledContent("Started", value: session.startedAt.formatted(date: .complete, time: .shortened))
        LabeledContent("Duration", value: duration)
      }

      Section("Exercises") {
        ForEach(session.exercises.sorted { $0.order < $1.order }, id: \.slotID) { exercise in
          VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
              .font(OneSetTypography.bodyStrong)
              .foregroundStyle(OneSetColors.textPrimary)
            if let entry = completedEntry(for: exercise), let weight = displayWeight(entry) {
              Text(resultLabel(weight: weight, repsInput: entry.repsInput, scope: exercise.repTarget.scope))
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
            } else {
              Text("Not performed")
                .font(OneSetTypography.body)
                .foregroundStyle(OneSetColors.textSecondary)
                .accessibilityIdentifier("history.exercise.notPerformed.\(exercise.slotID)")
            }
          }
          .padding(.vertical, 4)
          .accessibilityElement(children: .combine)
        }
      }

      if let note = session.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
        Section("Session note") {
          Text(note)
            .font(OneSetTypography.body)
            .foregroundStyle(OneSetColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("history.session.note")
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(OneSetColors.background)
    .navigationTitle(session.workoutName)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("history.detail")
  }

  private func completedEntry(for exercise: WorkoutSession.Exercise) -> WorkoutSession.SetEntry? {
    guard let entry = session.setEntries[exercise.slotID], entry.completedAt != nil,
          Double(entry.weightInput.trimmingCharacters(in: .whitespacesAndNewlines)) != nil,
          let reps = Int(entry.repsInput.trimmingCharacters(in: .whitespacesAndNewlines)), reps > 0 else { return nil }
    return entry
  }

  private func resultLabel(weight: String, repsInput: String, scope: RepTarget.Scope) -> String {
    let scopeText: String
    switch scope {
    case .reps: scopeText = "reps"
    case .eachLeg: scopeText = "reps each leg"
    case .eachSide: scopeText = "reps each side"
    }
    return "\(weight) · \(repsInput) \(scopeText)"
  }
}
