import SwiftUI

struct WorkoutFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let sessionID: UUID

    var session: WorkoutSession? {
        store.appData.workoutSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        NavigationStack {
            if let session {
                WorkoutChecklistView(session: session)
            } else {
                ContentUnavailableView("Workout Not Found", systemImage: "bolt.slash")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.dismissPresentedWorkout()
                    dismiss()
                }
            }
        }
    }
}

struct WorkoutChecklistView: View {
    @EnvironmentObject private var store: AppStore
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(eyebrow: session.locationNameSnapshot, title: session.regimenDayNameSnapshot ?? "Workout")

                Text("Swipe inside each exercise to change variation or history gym. Tap to log sets.")
                    .foregroundStyle(AppTheme.textSecondary)

                ForEach(session.exerciseEntries.sorted(by: { $0.orderIndex < $1.orderIndex })) { entry in
                    NavigationLink {
                        ExerciseLoggingView(sessionID: session.id, entryID: entry.id)
                    } label: {
                        WorkoutEntryCard(session: session, entry: entry)
                    }
                    .buttonStyle(.plain)
                }

                Button("Finish Workout") {
                    store.finishWorkout(sessionId: session.id)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutEntryCard: View {
    @EnvironmentObject private var store: AppStore
    let session: WorkoutSession
    let entry: WorkoutExerciseEntry

    var history: HistoryResult {
        store.history(for: session, entry: entry)
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.performedMovementNameSnapshot)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(entry.performedVariationNameSnapshot)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    StatusPill(title: entry.status.rawValue, color: pillColor)
                }

                Text("History gym: \(entry.viewedHistoryLocationNameSnapshot ?? session.locationNameSnapshot)")
                    .foregroundStyle(AppTheme.textMuted)

                if let primary = history.exact ?? history.variationAnywhere ?? history.movementMatches.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text(primary.variationName)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(primary.locationName) • \(primary.summary)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    Text("No history yet for this context.")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        let direction = value.translation.width < 0 ? 1 : -1
                        store.cycleVariation(sessionId: session.id, entryId: entry.id, direction: direction)
                    } else {
                        cycleLocation(translation: value.translation.height)
                    }
                }
        )
    }

    private func cycleLocation(translation: CGFloat) {
        let locations = store.activeLocations
        guard !locations.isEmpty else { return }
        let currentId = entry.viewedHistoryLocationId ?? session.locationId
        guard let index = locations.firstIndex(where: { $0.id == currentId }) else { return }
        let delta = translation < 0 ? 1 : -1
        let nextIndex = (index + delta + locations.count) % locations.count
        store.updateViewedHistoryLocation(sessionId: session.id, entryId: entry.id, locationId: locations[nextIndex].id)
    }

    private var pillColor: Color {
        switch entry.status {
        case .notStarted: return AppTheme.textMuted
        case .inProgress: return AppTheme.accent
        case .completed: return AppTheme.accentSecondary
        case .skipped: return AppTheme.warning
        }
    }
}

struct ExerciseLoggingView: View {
    @EnvironmentObject private var store: AppStore

    let sessionID: UUID
    let entryID: UUID

    @State private var editingSetID: UUID?
    @State private var editingField: EditingField = .weight
    @State private var numericInput = ""

    enum EditingField {
        case weight
        case reps
    }

    var session: WorkoutSession? {
        store.appData.workoutSessions.first(where: { $0.id == sessionID })
    }

    var entry: WorkoutExerciseEntry? {
        session?.exerciseEntries.first(where: { $0.id == entryID })
    }

    var body: some View {
        if let session, let entry {
            let history = store.history(for: session, entry: entry)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(eyebrow: entry.viewedHistoryLocationNameSnapshot ?? session.locationNameSnapshot, title: entry.performedMovementNameSnapshot)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.performedVariationNameSnapshot)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Swipe left or right to change variation. Swipe up or down to inspect another gym’s history.")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 18)
                            .onEnded { value in
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    let direction = value.translation.width < 0 ? 1 : -1
                                    store.cycleVariation(sessionId: session.id, entryId: entry.id, direction: direction)
                                } else {
                                    cycleLocation(currentEntry: entry, currentSession: session, translation: value.translation.height)
                                }
                            }
                    )

                    HistorySection(title: "Most Relevant", snapshot: history.exact ?? history.variationAnywhere)

                    if !history.movementMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Other \(entry.performedMovementNameSnapshot) history")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textSecondary)
                            ForEach(history.movementMatches) { snapshot in
                                HistoryCard(snapshot: snapshot)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sets")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                            SurfaceCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Set \(set.setNumber)")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(set.weightUnit.displayName)
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    LargeMetricButton(value: set.formattedWeight, label: "Weight") {
                                        startEditing(setId: set.id, field: .weight, initialValue: set.formattedWeight)
                                    }
                                    LargeMetricButton(value: "\(set.reps)", label: "Reps") {
                                        startEditing(setId: set.id, field: .reps, initialValue: "\(set.reps)")
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Delete Set", role: .destructive) {
                                    store.deleteSet(sessionId: session.id, entryId: entry.id, setId: set.id)
                                }
                            }
                        }
                    }

                    Button("Add Set") {
                        store.addSet(sessionId: session.id, entryId: entry.id)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    HStack(spacing: 12) {
                        Button("Complete") {
                            store.markExerciseComplete(sessionId: session.id, entryId: entry.id)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Skip") {
                            store.skipExercise(sessionId: session.id, entryId: entry.id)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .sheet(isPresented: Binding(
                get: { editingSetID != nil },
                set: { if !$0 { editingSetID = nil } }
            )) {
                NumericPadSheet(
                    title: editingField == .weight ? "Edit Weight" : "Edit Reps",
                    value: $numericInput,
                    onSave: saveEditing
                )
            }
        } else {
            ContentUnavailableView("Exercise Not Found", systemImage: "figure.strengthtraining.traditional")
        }
    }

    private func cycleLocation(currentEntry: WorkoutExerciseEntry, currentSession: WorkoutSession, translation: CGFloat) {
        let locations = store.activeLocations
        guard !locations.isEmpty else { return }
        let currentId = currentEntry.viewedHistoryLocationId ?? currentSession.locationId
        guard let index = locations.firstIndex(where: { $0.id == currentId }) else { return }
        let delta = translation < 0 ? 1 : -1
        let nextIndex = (index + delta + locations.count) % locations.count
        store.updateViewedHistoryLocation(sessionId: currentSession.id, entryId: currentEntry.id, locationId: locations[nextIndex].id)
    }

    private func startEditing(setId: UUID, field: EditingField, initialValue: String) {
        editingSetID = setId
        editingField = field
        numericInput = initialValue
    }

    private func saveEditing() {
        guard let session, let editingSetID else { return }
        let reps = editingField == .reps ? Int(numericInput) : nil
        let weight = editingField == .weight ? Double(numericInput) : nil
        store.updateSet(sessionId: session.id, entryId: entryID, setId: editingSetID, reps: reps, weight: weight)
        self.editingSetID = nil
    }
}

private struct HistorySection: View {
    let title: String
    let snapshot: HistorySnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            if let snapshot {
                HistoryCard(snapshot: snapshot)
            } else {
                SurfaceCard {
                    Text("No matching history yet.")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }
}

private struct HistoryCard: View {
    let snapshot: HistorySnapshot

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.variationName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(snapshot.locationName) • \(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(AppTheme.textSecondary)
                Text(snapshot.summary)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }
}

private struct LargeMetricButton: View {
    let value: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(value)
                    .font(.title.bold())
                Text(label)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 92, height: 92)
            .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct NumericPadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var value: String
    let onSave: () -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(value.isEmpty ? "0" : value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { symbol in
                        Button {
                            handle(symbol)
                        } label: {
                            Text(symbol)
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                }
            }

            Button("Save") {
                onSave()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .presentationDetents([.fraction(0.7)])
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func handle(_ symbol: String) {
        switch symbol {
        case "⌫":
            guard !value.isEmpty else { return }
            value.removeLast()
        case ".":
            guard !value.contains(".") else { return }
            value += symbol
        default:
            value += symbol
        }
    }
}
