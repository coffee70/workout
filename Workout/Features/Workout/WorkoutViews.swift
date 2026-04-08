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

                Text("Swipe inside each exercise to change variation. Tap to log sets.")
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
                        Text("Target: \(entry.targetSummary)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                    Spacer()
                    StatusPill(title: entry.status.displayName, color: pillColor)
                }

                let primary = primaryHistory(from: history)
                if let snapshot = primary.snapshot {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primary.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text(snapshot.variationName)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(snapshot.locationName) • \(snapshot.summary)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    Text("No history yet for this context.")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
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
    @Environment(\.dismiss) private var dismiss
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
            let viewedHistoryLocationName = entry.viewedHistoryLocationNameSnapshot ?? session.locationNameSnapshot
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(eyebrow: session.regimenDayNameSnapshot ?? "Workout", title: entry.performedMovementNameSnapshot)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.performedVariationNameSnapshot)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Swipe left or right to change variation.")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 18)
                            .onEnded { value in
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    let direction = value.translation.width < 0 ? 1 : -1
                                    store.cycleVariation(sessionId: session.id, entryId: entry.id, direction: direction)
                                }
                            }
                    )

                    TargetCard(entry: entry)

                    let primary = primaryHistory(from: history)
                    HistorySection(
                        title: primary.title,
                        selectedLocationName: viewedHistoryLocationName,
                        snapshot: primary.snapshot
                    ) { direction in
                        cycleLocation(currentEntry: entry, currentSession: session, direction: direction)
                    }

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
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            store.deleteSet(sessionId: session.id, entryId: entry.id, setId: set.id)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.danger)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(AppTheme.danger.opacity(0.18))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete Set \(set.setNumber)")
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: entry.sets.map(\.id))

                    Button {
                        store.addSet(sessionId: session.id, entryId: entry.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                            Text("Add Set")
                        }
                    }
                    .buttonStyle(AddSetButtonStyle())

                    HStack(spacing: 12) {
                        Button("Complete") {
                            store.markExerciseComplete(sessionId: session.id, entryId: entry.id)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Skip") {
                            store.skipExercise(sessionId: session.id, entryId: entry.id)
                            dismiss()
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

    private func cycleLocation(currentEntry: WorkoutExerciseEntry, currentSession: WorkoutSession, direction: Int) {
        let locations = store.activeLocations
        guard !locations.isEmpty else { return }
        let currentId = currentEntry.viewedHistoryLocationId ?? currentSession.locationId
        guard let index = locations.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (index + direction + locations.count) % locations.count
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

private struct LabeledHistory {
    let title: String
    let snapshot: HistorySnapshot?
}

private func primaryHistory(from history: HistoryResult) -> LabeledHistory {
    if let snapshot = history.exact {
        return LabeledHistory(title: "Last at this gym", snapshot: snapshot)
    }
    if let snapshot = history.variationAnywhere {
        return LabeledHistory(title: "Last with this variation", snapshot: snapshot)
    }
    if let snapshot = history.movementMatches.first {
        return LabeledHistory(title: "Other movement history", snapshot: snapshot)
    }
    return LabeledHistory(title: "Most Relevant", snapshot: nil)
}

private struct TargetCard: View {
    let entry: WorkoutExerciseEntry

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(entry.targetSummary)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.accentSecondary)
                if let plannedVariationNameSnapshot = entry.plannedVariationNameSnapshot,
                   plannedVariationNameSnapshot != entry.performedVariationNameSnapshot {
                    Text("Planned variation: \(plannedVariationNameSnapshot)")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }
}

private struct HistorySection: View {
    let title: String
    let selectedLocationName: String
    let snapshot: HistorySnapshot?
    let onCycleLocation: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Viewing \(selectedLocationName). Swipe left or right to change gyms.")
                    .foregroundStyle(AppTheme.textMuted)
            }
            if let snapshot {
                HistoryCard(snapshot: snapshot)
            } else {
                SurfaceCard {
                    Text("No matching history yet.")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let direction = value.translation.width < 0 ? 1 : -1
                    onCycleLocation(direction)
                }
        )
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

private struct AddSetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct NumericPadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shouldReplaceOnNextInput = true

    let title: String
    @Binding var value: String
    let onSave: () -> Void

    private let sheetHeight: CGFloat = 620

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
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.horizontal)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.background)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            shouldReplaceOnNextInput = true
        }
    }

    private func handle(_ symbol: String) {
        switch symbol {
        case "⌫":
            if shouldReplaceOnNextInput {
                value = ""
                shouldReplaceOnNextInput = false
                return
            }
            guard !value.isEmpty else { return }
            value.removeLast()
        case ".":
            guard !value.contains(".") else { return }
            if shouldReplaceOnNextInput {
                value = "0."
                shouldReplaceOnNextInput = false
            } else {
                value += symbol
            }
        default:
            if shouldReplaceOnNextInput {
                value = symbol
                shouldReplaceOnNextInput = false
            } else {
                value += symbol
            }
        }
    }
}
