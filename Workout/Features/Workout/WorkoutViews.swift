import SwiftUI
import UniformTypeIdentifiers

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

    @State private var isAddMovementPresented = false
    @State private var showDiscardWorkoutConfirmation = false
    @State private var activeDraggedEntryID: UUID?
    @State private var proposedDropIndex: Int?
    @State private var rowFrames: [UUID: CGRect] = [:]

    private var sortedEntries: [WorkoutExerciseEntry] {
        session.exerciseEntries.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var sourceIndex: Int? {
        guard let activeDraggedEntryID else { return nil }
        return sortedEntries.firstIndex(where: { $0.id == activeDraggedEntryID })
    }

    private var visibleEntries: [WorkoutExerciseEntry] {
        guard let activeDraggedEntryID else { return sortedEntries }
        return sortedEntries.filter { $0.id != activeDraggedEntryID }
    }

    private var effectiveDropIndex: Int? {
        guard let sourceIndex else { return nil }
        return max(0, min(proposedDropIndex ?? sourceIndex, visibleEntries.count))
    }

    private var renderedOverviewItems: [WorkoutOverviewRenderItem] {
        guard let effectiveDropIndex else {
            return sortedEntries.map(WorkoutOverviewRenderItem.entry)
        }

        var items: [WorkoutOverviewRenderItem] = []
        for index in 0...visibleEntries.count {
            if index == effectiveDropIndex {
                items.append(.placeholder(index))
            }
            if index < visibleEntries.count {
                items.append(.entry(visibleEntries[index]))
            }
        }
        return items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(eyebrow: session.locationNameSnapshot, title: session.regimenDayNameSnapshot ?? "Workout")

                Text("Tap an exercise to log sets.")
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(renderedOverviewItems) { item in
                        switch item {
                        case .entry(let entry):
                            WorkoutOverviewEntryRow(
                                session: session,
                                entry: entry,
                                onDragStarted: { draggedEntryID in
                                    beginReorder(for: draggedEntryID)
                                }
                            )
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: WorkoutOverviewRowFramePreferenceKey.self,
                                        value: [entry.id: proxy.frame(in: .named(WorkoutOverviewReorderCoordinateSpace.name))]
                                    )
                                }
                            )
                        case .placeholder:
                            WorkoutOverviewDropPlaceholder()
                        }
                    }
                }
                .coordinateSpace(name: WorkoutOverviewReorderCoordinateSpace.name)
                .contentShape(Rectangle())
                .onPreferenceChange(WorkoutOverviewRowFramePreferenceKey.self) { rowFrames = $0 }
                .onDrop(
                    of: [UTType.text],
                    delegate: WorkoutOverviewReorderDropDelegate(
                        sortedEntries: sortedEntries,
                        visibleEntries: visibleEntries,
                        rowFrames: rowFrames,
                        activeDraggedEntryID: $activeDraggedEntryID,
                        proposedDropIndex: $proposedDropIndex,
                        onCommitMove: { draggedEntryID, targetIndex in
                            store.moveExercise(sessionId: session.id, entryId: draggedEntryID, toIndex: targetIndex)
                        },
                        onReset: resetReorderState
                    )
                )
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.84), value: renderedOverviewItems)
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.84), value: activeDraggedEntryID)

                Button("Add Movement") {
                    isAddMovementPresented = true
                }
                .buttonStyle(SecondaryButtonStyle())

                HStack(spacing: 12) {
                    Button("Finish Workout") {
                        store.finishWorkout(sessionId: session.id)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("Cancel Workout") {
                        showDiscardWorkoutConfirmation = true
                    }
                    .buttonStyle(DestructiveSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $showDiscardWorkoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) {
                store.discardActiveWorkout(sessionId: session.id)
            }
            Button("Keep Workout", role: .cancel) {}
        } message: {
            Text("Nothing will be saved and this session will not appear in History.")
        }
        .sheet(isPresented: $isAddMovementPresented) {
            NavigationStack {
                ActiveWorkoutMovementPickerView(
                    mode: .add,
                    session: session,
                    sourceEntry: nil,
                    onConfirm: { selection in
                        _ = store.appendExercise(
                            sessionId: session.id,
                            movementId: selection.movementId,
                            variationId: selection.variationId,
                            plannedSetCount: selection.plannedSetCount,
                            plannedRepRange: selection.plannedRepRange
                        )
                        isAddMovementPresented = false
                    }
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func beginReorder(for entryID: UUID) {
        activeDraggedEntryID = entryID
        if let sourceIndex = sortedEntries.firstIndex(where: { $0.id == entryID }) {
            proposedDropIndex = sourceIndex
        }
    }

    private func resetReorderState() {
        activeDraggedEntryID = nil
        proposedDropIndex = nil
    }
}

struct WorkoutEntryCard: View {
    let entry: WorkoutExerciseEntry

    var body: some View {
        SurfaceCard {
            WorkoutEntryCardContent(entry: entry, pillColor: pillColor)
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

private struct WorkoutEntryCardContent: View {
    let entry: WorkoutExerciseEntry
    let pillColor: Color

    var body: some View {
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
    }
}

private enum ExerciseLoggingTab: String, CaseIterable, Identifiable {
    case log
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .log: return "Log"
        case .history: return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .log: return "square.and.pencil"
        case .history: return "clock.arrow.circlepath"
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
    @State private var isScrubbingMetric = false
    @State private var isReplaceSheetPresented = false
    @State private var selectedTab: ExerciseLoggingTab = .log

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

    private var variationDeckItems: [VariationDeckCardItem] {
        guard let entry else { return [] }
        let variations = store.variations(for: entry.performedMovementId)
        guard !variations.isEmpty else { return [] }

        let order = orderedIDs(
            currentIDs: variations.map(\.id),
            preferredOrder: [],
            fallbackCurrentID: entry.performedVariationId
        )
        let variationsByID = Dictionary(uniqueKeysWithValues: variations.map { ($0.id, $0) })
        return order.compactMap { id in
            variationsByID[id].map(VariationDeckCardItem.init)
        }
    }

    private var historyDeckItems: [HistoryLocationDeckItem] {
        guard let session, let entry else { return [] }
        let locations = store.activeLocations
        guard !locations.isEmpty else { return [] }

        let currentLocationId = entry.viewedHistoryLocationId ?? session.locationId
        let order = orderedIDs(
            currentIDs: locations.map(\.id),
            preferredOrder: [],
            fallbackCurrentID: currentLocationId
        )
        let locationsByID = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })

        return order.compactMap { locationID in
            guard let location = locationsByID[locationID] else { return nil }
            let labeledHistory = primaryHistoryForLocationDeck(
                from: store.history(for: session, entry: entry, locationId: location.id)
            )
            return HistoryLocationDeckItem(location: location, title: labeledHistory.title, snapshot: labeledHistory.snapshot)
        }
    }

    var body: some View {
        if let session, let entry {
            let history = store.history(for: session, entry: entry)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(eyebrow: session.regimenDayNameSnapshot ?? "Workout", title: entry.performedMovementNameSnapshot)

                    ExerciseLoggingTabSelector(selectedTab: $selectedTab)

                    switch selectedTab {
                    case .log:
                        ExerciseLogTabContent(
                            session: session,
                            entry: entry,
                            variationDeckItems: variationDeckItems,
                            onVariationAdvance: {
                                store.advanceVariation(sessionId: session.id, entryId: entry.id)
                            },
                            onStartEditingSet: { setId, field, initialValue in
                                startEditing(setId: setId, field: field, initialValue: initialValue)
                            },
                            onScrubActiveChange: { isActive in
                                isScrubbingMetric = isActive
                            },
                            onUpdateSetWeight: { setId, updatedWeight in
                                store.updateSet(sessionId: session.id, entryId: entry.id, setId: setId, weight: updatedWeight)
                            },
                            onUpdateSetReps: { setId, updatedReps in
                                store.updateSet(sessionId: session.id, entryId: entry.id, setId: setId, reps: updatedReps)
                            },
                            onToggleOverloaded: { setId, currentValue in
                                Haptics.light()
                                store.updateSet(
                                    sessionId: session.id,
                                    entryId: entry.id,
                                    setId: setId,
                                    usedMachineOverload: !currentValue
                                )
                            },
                            onTogglePerSide: { setId, currentValue in
                                Haptics.light()
                                store.updateSet(
                                    sessionId: session.id,
                                    entryId: entry.id,
                                    setId: setId,
                                    perSide: !currentValue
                                )
                            },
                            onDeleteSet: { setId in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.deleteSet(sessionId: session.id, entryId: entry.id, setId: setId)
                                }
                            },
                            onAddSet: {
                                store.addSet(sessionId: session.id, entryId: entry.id)
                            },
                            onSkip: {
                                store.skipExercise(sessionId: session.id, entryId: entry.id)
                                dismiss()
                            },
                            onReplace: {
                                isReplaceSheetPresented = true
                            },
                            onComplete: {
                                store.markExerciseComplete(sessionId: session.id, entryId: entry.id)
                                dismiss()
                            }
                        )
                    case .history:
                        ExerciseHistoryTabContent(
                            history: history,
                            historyDeckItems: historyDeckItems,
                            onAdvanceHistoryLocation: {
                                store.advanceViewedHistoryLocation(sessionId: session.id, entryId: entry.id)
                            }
                        )
                    }
                }
                .padding()
            }
            .scrollDisabled(selectedTab == .log && isScrubbingMetric)
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
            .sheet(isPresented: $isReplaceSheetPresented) {
                NavigationStack {
                    ActiveWorkoutMovementPickerView(
                        mode: .replace,
                        session: session,
                        sourceEntry: entry,
                        onConfirm: { selection in
                            _ = store.replaceExercise(
                                sessionId: session.id,
                                entryId: entry.id,
                                movementId: selection.movementId,
                                variationId: selection.variationId,
                                plannedSetCount: selection.plannedSetCount,
                                plannedRepRange: selection.plannedRepRange
                            )
                            isReplaceSheetPresented = false
                        }
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        } else {
            ContentUnavailableView("Exercise Not Found", systemImage: "figure.strengthtraining.traditional")
        }
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

private struct ExerciseLoggingTabSelector: View {
    @Binding var selectedTab: ExerciseLoggingTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ExerciseLoggingTab.allCases) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    Haptics.light()
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                    }
                    .font(.headline.weight(selectedTab == tab ? .bold : .semibold))
                    .foregroundStyle(selectedTab == tab ? .black : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedTab == tab ? AppTheme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct ExerciseLogTabContent: View {
    let session: WorkoutSession
    let entry: WorkoutExerciseEntry
    let variationDeckItems: [VariationDeckCardItem]
    let onVariationAdvance: () -> Void
    let onStartEditingSet: (UUID, ExerciseLoggingView.EditingField, String) -> Void
    let onScrubActiveChange: (Bool) -> Void
    let onUpdateSetWeight: (UUID, Double) -> Void
    let onUpdateSetReps: (UUID, Int) -> Void
    let onToggleOverloaded: (UUID, Bool) -> Void
    let onTogglePerSide: (UUID, Bool) -> Void
    let onDeleteSet: (UUID) -> Void
    let onAddSet: () -> Void
    let onSkip: () -> Void
    let onReplace: () -> Void
    let onComplete: () -> Void

    private var statusPillColor: Color {
        switch entry.status {
        case .notStarted: return AppTheme.textMuted
        case .inProgress: return AppTheme.accent
        case .completed: return AppTheme.accentSecondary
        case .skipped: return AppTheme.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    StatusPill(title: entry.status.displayName, color: statusPillColor)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Target")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(entry.targetSummary)
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.accentSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("Variation")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(entry.performedVariationNameSnapshot)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                Text("Swipe to change variation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textMuted)

                RotatingSwipeDeck(items: variationDeckItems, onAdvance: { _ in
                    onVariationAdvance()
                }) { item in
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text(item.variation.name)
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if item.variation.id == entry.plannedVariationId {
                                    StatusPill(title: "Planned", color: AppTheme.accentSecondary)
                                }
                            }
                            if let equipmentCategory = item.variation.equipmentCategory {
                                Text(equipmentCategory.displayName)
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                Text(entry.performedMovementNameSnapshot)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    }
                }
                .frame(height: 150)
            }

            ExerciseSetsSection(
                session: session,
                entry: entry,
                onStartEditingSet: onStartEditingSet,
                onScrubActiveChange: onScrubActiveChange,
                onUpdateSetWeight: onUpdateSetWeight,
                onUpdateSetReps: onUpdateSetReps,
                onToggleOverloaded: onToggleOverloaded,
                onTogglePerSide: onTogglePerSide,
                onDeleteSet: onDeleteSet
            )

            Button {
                onAddSet()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                    Text("Add Set")
                }
            }
            .buttonStyle(AddSetButtonStyle())

            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    Button("Skip", action: onSkip)
                        .buttonStyle(SecondaryButtonStyle())

                    Button("Replace", action: onReplace)
                        .buttonStyle(SecondaryButtonStyle())
                }

                Button("Complete", action: onComplete)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 8)
        }
    }
}

private struct ExerciseSetsSection: View {
    let session: WorkoutSession
    let entry: WorkoutExerciseEntry
    let onStartEditingSet: (UUID, ExerciseLoggingView.EditingField, String) -> Void
    let onScrubActiveChange: (Bool) -> Void
    let onUpdateSetWeight: (UUID, Double) -> Void
    let onUpdateSetReps: (UUID, Int) -> Void
    let onToggleOverloaded: (UUID, Bool) -> Void
    let onTogglePerSide: (UUID, Bool) -> Void
    let onDeleteSet: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sets")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Tap a number to type. Drag vertically to scrub.")
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)

            if entry.sets.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No sets logged yet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Add your first set to start tracking this movement.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Set \(set.setNumber)")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(set.weightUnit.displayName)
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                                LargeMetricButton(
                                    value: set.weight,
                                    label: "Weight",
                                    configuration: .weight
                                ) {
                                    onStartEditingSet(set.id, .weight, set.formattedWeight)
                                } onScrubActiveChange: { isActive in
                                    onScrubActiveChange(isActive)
                                } onValueChange: { value in
                                    onUpdateSetWeight(set.id, value)
                                }
                                .frame(maxWidth: .infinity)
                                LargeMetricButton(
                                    value: Double(set.reps),
                                    label: "Reps",
                                    configuration: .reps
                                ) {
                                    onStartEditingSet(set.id, .reps, "\(set.reps)")
                                } onScrubActiveChange: { isActive in
                                    onScrubActiveChange(isActive)
                                } onValueChange: { value in
                                    onUpdateSetReps(set.id, Int(value))
                                }
                                .frame(maxWidth: .infinity)
                                Button(role: .destructive) {
                                    onDeleteSet(set.id)
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
                            SetRecordingFlagsRow(
                                isOverloaded: set.usedMachineOverload,
                                isPerSide: set.perSide,
                                onToggleOverloaded: {
                                    onToggleOverloaded(set.id, set.usedMachineOverload)
                                },
                                onTogglePerSide: {
                                    onTogglePerSide(set.id, set.perSide)
                                }
                            )
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: entry.sets.map(\.id))
            }
        }
    }
}

private struct ExerciseHistoryTabContent: View {
    let history: HistoryResult
    let historyDeckItems: [HistoryLocationDeckItem]
    let onAdvanceHistoryLocation: () -> Void

    private var isHistoryEmpty: Bool {
        history.exact == nil && history.variationAnywhere == nil && history.movementMatches.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isHistoryEmpty {
                HistoryEmptyStateCard()
            } else {
                HistoryOverviewGrid(history: history)

                GymHistoryDeckSection(items: historyDeckItems, onAdvanceLocation: onAdvanceHistoryLocation)

                if let exact = history.exact {
                    DetailedHistorySnapshotCard(title: "Last exact match", snapshot: exact)
                }

                if let anywhere = history.variationAnywhere,
                   anywhere.id != history.exact?.id {
                    DetailedHistorySnapshotCard(title: "Last variation anywhere", snapshot: anywhere)
                }

                if !history.movementMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Other Variations")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Recent sessions for this movement using a different variation.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textMuted)

                        ForEach(history.movementMatches) { snapshot in
                            MovementHistoryCard(snapshot: snapshot)
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryOverviewGrid: View {
    let history: HistoryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 12) {
                HistoryOverviewMetricCard(title: "This Gym", snapshot: history.exact)
                HistoryOverviewMetricCard(title: "Any Gym", snapshot: history.variationAnywhere)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HistoryOverviewMetricCard: View {
    let title: String
    let snapshot: HistorySnapshot?

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)

                if let snapshot {
                    Text(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(snapshot.summary.isEmpty ? "—" : snapshot.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                } else {
                    Text("No match")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HistoryEmptyStateCard: View {
    var body: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title)
                    .foregroundStyle(AppTheme.textMuted)

                Text("No history yet")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Complete this movement once and your previous sets will appear here.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

private struct DetailedHistorySnapshotCard: View {
    let title: String
    let snapshot: HistorySnapshot?

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)

                if let snapshot {
                    Text(snapshot.variationName)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(snapshot.locationName)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                            HistorySetRow(set: set)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HistorySetRow: View {
    let set: SetEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Set \(set.setNumber)")
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text("\(set.formattedWeight) x \(set.reps)\(set.historyFlagSuffix)")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

private struct MovementHistoryCard: View {
    let snapshot: HistorySnapshot

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.variationName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(snapshot.locationName) • \(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(snapshot.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VariationDeckCardItem: Identifiable, Equatable {
    let variation: Variation

    var id: UUID { variation.id }
}

private struct HistoryLocationDeckItem: Identifiable, Equatable {
    let location: Location
    let title: String
    let snapshot: HistorySnapshot?

    var id: UUID { location.id }
}

private struct LabeledHistory {
    let title: String
    let snapshot: HistorySnapshot?
}

private func orderedIDs(
    currentIDs: [UUID],
    preferredOrder: [UUID],
    fallbackCurrentID: UUID
) -> [UUID] {
    guard !currentIDs.isEmpty else { return [] }

    let currentIDSet = Set(currentIDs)
    let filteredPreferred = preferredOrder.filter { currentIDSet.contains($0) }
    let missingIDs = currentIDs.filter { !filteredPreferred.contains($0) }
    let merged = filteredPreferred + missingIDs

    if let currentIndex = merged.firstIndex(of: fallbackCurrentID) {
        return merged.rotated(startingAt: currentIndex)
    }

    return merged
}

/// Swipe deck has one card per gym; only `exact` (same variation at that gym) should appear on that card.
private func primaryHistoryForLocationDeck(from history: HistoryResult) -> LabeledHistory {
    if let snapshot = history.exact {
        return LabeledHistory(title: "Last at this gym", snapshot: snapshot)
    }
    return LabeledHistory(title: "Last at this gym", snapshot: nil)
}

private struct GymHistoryDeckSection: View {
    let items: [HistoryLocationDeckItem]
    let onAdvanceLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gym History")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            RotatingSwipeDeck(items: items, onAdvance: { _ in
                onAdvanceLocation()
            }) { item in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.location.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)

                        if let snapshot = item.snapshot {
                            HStack(alignment: .center, spacing: 8) {
                                Text(snapshot.variationName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .lineLimit(2)
                                Spacer(minLength: 8)
                                StatusPill(title: "Exact Match", color: AppTheme.accentSecondary)
                            }
                            Text(snapshot.summary)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(4)
                            Text(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(AppTheme.textMuted)
                        } else {
                            Text("No matching history yet.")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                }
            }
            .frame(height: 200)
        }
    }
}

private struct SetRecordingFlagsRow: View {
    let isOverloaded: Bool
    let isPerSide: Bool
    let onToggleOverloaded: () -> Void
    let onTogglePerSide: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            flagButton(title: "Overloaded", isActive: isOverloaded, action: onToggleOverloaded)
            flagButton(title: "Per Side", isActive: isPerSide, action: onTogglePerSide)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flagButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textMuted)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isActive ? AppTheme.accent.opacity(0.55) : Color.white.opacity(0.06),
                        lineWidth: isActive ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "On" : "Off")
    }
}

private struct LargeMetricButton: View {
    let value: Double
    let label: String
    let configuration: MetricScrubConfiguration
    let action: () -> Void
    let onScrubActiveChange: (Bool) -> Void
    let onValueChange: (Double) -> Void

    @State private var previewValue: Double?
    @State private var scrubSession: MetricScrubSession?

    private var displayedValue: Double {
        previewValue ?? value
    }

    var body: some View {
        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged(handleDragChanged(_:))
            .onEnded(handleDragEnded(_:))

        VStack(spacing: 6) {
            Text(configuration.displayText(for: displayedValue))
                .font(.title.bold())
            Text(label)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(backgroundStyle)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .highPriorityGesture(dragGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(label)
        .accessibilityValue(configuration.displayText(for: displayedValue))
    }

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(scrubSession?.isActive == true ? AppTheme.accent.opacity(0.22) : AppTheme.elevatedSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(scrubSession?.isActive == true ? AppTheme.accent.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private func handleDragChanged(_ drag: DragGesture.Value) {
        if scrubSession == nil {
            scrubSession = MetricScrubSession(
                startingValue: value,
                lastLocation: drag.location,
                lastTimestamp: drag.time,
                rawValue: value,
                lastHapticBucket: configuration.hapticBucket(for: value)
            )
        }

        guard var session = scrubSession else { return }
        let verticalTravel = abs(drag.translation.height)

        if !session.isActive {
            session.lastLocation = drag.location
            session.lastTimestamp = drag.time

            if verticalTravel >= configuration.activationThreshold {
                session.isActive = true
                onScrubActiveChange(true)
            } else {
                scrubSession = session
                return
            }
        }

        let elapsed = max(drag.time.timeIntervalSince(session.lastTimestamp), 0.016)
        let deltaY = session.lastLocation.y - drag.location.y
        let speed = abs(deltaY) / CGFloat(elapsed)
        let multiplier = configuration.speedMultiplier(for: speed)
        let valueDelta = Double(deltaY / configuration.pointsPerUnit) * multiplier
        let nextRawValue = configuration.clamp(session.rawValue + valueDelta)
        let snappedValue = configuration.snap(nextRawValue)

        session.rawValue = nextRawValue
        session.lastLocation = drag.location
        session.lastTimestamp = drag.time

        if snappedValue != displayedValue {
            previewValue = snappedValue
            onValueChange(snappedValue)
        }

        let hapticBucket = configuration.hapticBucket(for: snappedValue)
        if hapticBucket != session.lastHapticBucket {
            Haptics.light()
            session.lastHapticBucket = hapticBucket
        }

        scrubSession = session
    }

    private func handleDragEnded(_ drag: DragGesture.Value) {
        defer {
            previewValue = nil
            scrubSession = nil
            onScrubActiveChange(false)
        }

        guard let session = scrubSession else {
            action()
            return
        }

        if !session.isActive && abs(drag.translation.height) < configuration.activationThreshold {
            action()
        }
    }
}

private struct MetricScrubSession {
    let startingValue: Double
    var lastLocation: CGPoint
    var lastTimestamp: Date
    var rawValue: Double
    var lastHapticBucket: Int
    var isActive = false
}

private struct MetricScrubConfiguration {
    let activationThreshold: CGFloat
    let pointsPerUnit: CGFloat
    let minValue: Double
    let maxValue: Double
    let snapStep: Double
    let hapticStep: Double
    let speedBands: [(maxSpeed: CGFloat, multiplier: Double)]
    let display: (Double) -> String

    static let weight = MetricScrubConfiguration(
        activationThreshold: 10,
        pointsPerUnit: 18,
        minValue: 0,
        maxValue: 999.9,
        snapStep: 0.1,
        hapticStep: 1,
        speedBands: [
            (maxSpeed: 140, multiplier: 0.35),
            (maxSpeed: 320, multiplier: 0.8),
            (maxSpeed: 620, multiplier: 1.8),
            (maxSpeed: .greatestFiniteMagnitude, multiplier: 3.4)
        ],
        display: { value in
            if value.rounded(.towardZero) == value {
                return String(Int(value))
            }
            return String(format: "%.1f", value)
        }
    )

    static let reps = MetricScrubConfiguration(
        activationThreshold: 10,
        pointsPerUnit: 34,
        minValue: 0,
        maxValue: 99,
        snapStep: 1,
        hapticStep: 1,
        speedBands: [
            (maxSpeed: 140, multiplier: 0.45),
            (maxSpeed: 320, multiplier: 0.9),
            (maxSpeed: 620, multiplier: 1.8),
            (maxSpeed: .greatestFiniteMagnitude, multiplier: 3)
        ],
        display: { value in
            String(Int(value))
        }
    )

    func clamp(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    func snap(_ value: Double) -> Double {
        let stepped = (value / snapStep).rounded() * snapStep
        let clamped = clamp(stepped)
        let precision = max(0, Int(round(-log10(snapStep))))
        let scale = pow(10.0, Double(precision))
        return (clamped * scale).rounded() / scale
    }

    func hapticBucket(for value: Double) -> Int {
        Int((clamp(value) / hapticStep).rounded(.towardZero))
    }

    func speedMultiplier(for speed: CGFloat) -> Double {
        speedBands.first(where: { speed <= $0.maxSpeed })?.multiplier ?? 1
    }

    func displayText(for value: Double) -> String {
        display(clamp(value))
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

private struct WorkoutOverviewEntryRow: View {
    let session: WorkoutSession
    let entry: WorkoutExerciseEntry
    let onDragStarted: (UUID) -> Void

    var body: some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: 14) {
                WorkoutOverviewDragHandle()
                    .onDrag {
                        onDragStarted(entry.id)
                        return NSItemProvider(object: entry.id.uuidString as NSString)
                    } preview: {
                        WorkoutOverviewDraggedCardPreview(
                            entry: entry,
                            pillColor: pillColor
                        )
                    }

                NavigationLink {
                    ExerciseLoggingView(sessionID: session.id, entryID: entry.id)
                } label: {
                    WorkoutEntryCardContent(
                        entry: entry,
                        pillColor: pillColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

private enum WorkoutOverviewRenderItem: Identifiable, Equatable {
    case entry(WorkoutExerciseEntry)
    case placeholder(Int)

    var id: String {
        switch self {
        case .entry(let entry):
            return entry.id.uuidString
        case .placeholder(let index):
            return "placeholder-\(index)"
        }
    }
}

private enum WorkoutOverviewReorderCoordinateSpace {
    static let name = "WorkoutOverviewReorderList"
}

private struct WorkoutOverviewRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct WorkoutOverviewDropPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppTheme.accent.opacity(0.14))
            .frame(height: 102)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
            )
            .overlay(alignment: .leading) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3.weight(.semibold))
                    Text("Drop movement here")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 18)
            }
            .transition(.asymmetric(insertion: .scale(scale: 0.98).combined(with: .opacity), removal: .opacity))
    }
}

private struct WorkoutOverviewDraggedCardPreview: View {
    let entry: WorkoutExerciseEntry
    let pillColor: Color

    var body: some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: 14) {
                WorkoutOverviewDragHandle()

                WorkoutEntryCardContent(entry: entry, pillColor: pillColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scaleEffect(1.03)
        .opacity(0.96)
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 12)
        .padding(.horizontal, 4)
    }
}

private struct WorkoutOverviewReorderDropDelegate: DropDelegate {
    let sortedEntries: [WorkoutExerciseEntry]
    let visibleEntries: [WorkoutExerciseEntry]
    let rowFrames: [UUID: CGRect]
    @Binding var activeDraggedEntryID: UUID?
    @Binding var proposedDropIndex: Int?
    let onCommitMove: (UUID, Int) -> Void
    let onReset: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        updateDropIndex(with: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropIndex(with: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        proposedDropIndex = sourceIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedEntryID = activeDraggedEntryID,
              let sourceIndex else {
            onReset()
            return false
        }

        let visibleDropIndex = resolvedDropIndex(for: info.location)
        let targetIndex = visibleDropIndex > sourceIndex ? visibleDropIndex + 1 : visibleDropIndex
        onCommitMove(draggedEntryID, targetIndex)
        onReset()
        return true
    }

    private var sourceIndex: Int? {
        guard let activeDraggedEntryID else { return nil }
        return sortedEntries.firstIndex(where: { $0.id == activeDraggedEntryID })
    }

    private func updateDropIndex(with location: CGPoint) {
        proposedDropIndex = resolvedDropIndex(for: location)
    }

    private func resolvedDropIndex(for location: CGPoint) -> Int {
        guard !visibleEntries.isEmpty else { return 0 }

        for (index, entry) in visibleEntries.enumerated() {
            guard let frame = rowFrames[entry.id] else { continue }
            if location.y < frame.midY {
                return index
            }
        }

        return visibleEntries.count
    }
}

private struct WorkoutOverviewDragHandle: View {
    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                gripDot
                gripDot
                gripDot
            }

            VStack(spacing: 4) {
                gripDot
                gripDot
                gripDot
            }
        }
        .frame(width: 34, height: 34)
        .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var gripDot: some View {
        Circle()
            .fill(AppTheme.textMuted)
            .frame(width: 4, height: 4)
    }
}

private struct ActiveWorkoutMovementPickerView: View {
    @EnvironmentObject private var store: AppStore

    let mode: ActiveWorkoutMovementPickerMode
    let session: WorkoutSession
    let sourceEntry: WorkoutExerciseEntry?
    let onConfirm: (ActiveWorkoutEntrySelection) -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private let groupSections = [
        WorkoutMuscleGroupSection(title: "Upper Body", groups: [.chest, .upperChest, .lats, .upperBack, .midBack, .traps, .frontDelts, .sideDelts, .rearDelts]),
        WorkoutMuscleGroupSection(title: "Lower Body", groups: [.quadriceps, .hamstrings, .glutes, .calves, .adductors, .abductors, .spinalErectors]),
        WorkoutMuscleGroupSection(title: "Arms", groups: [.biceps, .triceps, .forearms]),
        WorkoutMuscleGroupSection(title: "Other", groups: [.abs])
    ]

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [Movement] {
        store.searchMovements(query: searchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isSearching {
                    if searchResults.isEmpty {
                        ContentUnavailableView(
                            "No Matching Movements",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different search term, or clear the search field to browse by muscle group.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Movements")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            ForEach(searchResults) { movement in
                                NavigationLink {
                                    ActiveWorkoutMovementDetailView(
                                        mode: mode,
                                        session: session,
                                        sourceEntry: sourceEntry,
                                        movementId: movement.id,
                                        onConfirm: onConfirm
                                    )
                                } label: {
                                    WorkoutMovementSelectionCard(movement: movement, isSelected: false)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    searchFocused = false
                                })
                            }
                        }
                    }
                } else {
                    ForEach(groupSections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textMuted)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                                ForEach(section.groups, id: \.self) { group in
                                    NavigationLink {
                                        ActiveWorkoutMovementGroupView(
                                            mode: mode,
                                            session: session,
                                            sourceEntry: sourceEntry,
                                            group: group,
                                            searchText: searchText,
                                            onConfirm: onConfirm
                                        )
                                    } label: {
                                        WorkoutMuscleGroupTile(group: group, count: store.movements(for: group).count, isSelected: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.bottom, 78)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            WorkoutMovementSearchBar(searchText: $searchText, searchFocused: _searchFocused)
        }
    }
}

private struct ActiveWorkoutMovementGroupView: View {
    @EnvironmentObject private var store: AppStore

    let mode: ActiveWorkoutMovementPickerMode
    let session: WorkoutSession
    let sourceEntry: WorkoutExerciseEntry?
    let group: MuscleGroup
    let searchText: String
    let onConfirm: (ActiveWorkoutEntrySelection) -> Void

    private var movements: [Movement] {
        store.searchMovements(query: searchText, muscleGroup: group)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(eyebrow: "Muscle Group", title: group.displayName)

                ForEach(movements) { movement in
                    NavigationLink {
                        ActiveWorkoutMovementDetailView(
                            mode: mode,
                            session: session,
                            sourceEntry: sourceEntry,
                            movementId: movement.id,
                            onConfirm: onConfirm
                        )
                    } label: {
                        WorkoutMovementSelectionCard(movement: movement, isSelected: false)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }

                if movements.isEmpty {
                    Text("No matching movements.")
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActiveWorkoutMovementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let mode: ActiveWorkoutMovementPickerMode
    let session: WorkoutSession
    let sourceEntry: WorkoutExerciseEntry?
    let movementId: UUID
    let onConfirm: (ActiveWorkoutEntrySelection) -> Void

    @State private var selectedVariationId: UUID?
    @State private var selectedNoVariation = false
    @State private var plannedSetCount: Int
    @State private var plannedRepMin: Int
    @State private var plannedRepMax: Int

    init(
        mode: ActiveWorkoutMovementPickerMode,
        session: WorkoutSession,
        sourceEntry: WorkoutExerciseEntry?,
        movementId: UUID,
        onConfirm: @escaping (ActiveWorkoutEntrySelection) -> Void
    ) {
        self.mode = mode
        self.session = session
        self.sourceEntry = sourceEntry
        self.movementId = movementId
        self.onConfirm = onConfirm

        let defaultRepRange = sourceEntry?.plannedRepRange ?? RepRange(min: 8, max: 12)
        let defaultSetCount = sourceEntry?.plannedSetCount ?? 3

        switch mode {
        case .replace:
            _plannedSetCount = State(initialValue: defaultSetCount)
            _plannedRepMin = State(initialValue: defaultRepRange.min)
            _plannedRepMax = State(initialValue: defaultRepRange.max)
        case .add:
            _plannedSetCount = State(initialValue: 3)
            _plannedRepMin = State(initialValue: 8)
            _plannedRepMax = State(initialValue: 12)
        }
    }

    private var movement: Movement? {
        store.movement(for: movementId)
    }

    private var variations: [Variation] {
        store.variations(for: movementId)
    }

    private var canConfirm: Bool {
        (selectedNoVariation || selectedVariationId != nil || variations.isEmpty) &&
        plannedSetCount > 0 &&
        plannedRepMin > 0 &&
        plannedRepMax >= plannedRepMin
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let movement {
                    WorkoutMovementSelectionCard(movement: movement, isSelected: false)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Variation")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        if variations.isEmpty {
                            Button {
                                selectedNoVariation = true
                                selectedVariationId = nil
                            } label: {
                                WorkoutVariationSelectionCard(title: "Continue without a variation", subtitle: nil, isSelected: selectedNoVariation)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(variations) { variation in
                                Button {
                                    selectedVariationId = variation.id
                                    selectedNoVariation = false
                                } label: {
                                    WorkoutVariationSelectionCard(
                                        title: variation.name,
                                        subtitle: variation.equipmentCategory?.displayName,
                                        isSelected: selectedVariationId == variation.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    WorkoutTargetPickerCard(
                        plannedSetCount: $plannedSetCount,
                        plannedRepMin: $plannedRepMin,
                        plannedRepMax: $plannedRepMax
                    )

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Applies To")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(session.regimenDayNameSnapshot ?? "Workout")
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(mode == .replace ? "This replaces the current movement in the active workout only." : "This adds a new movement to the end of the active workout only. You can drag it into place after adding it.")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                } else {
                    ContentUnavailableView("Movement Not Found", systemImage: "figure.strengthtraining.traditional")
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(movement?.canonicalName ?? "Movement")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard selectedVariationId == nil, !selectedNoVariation else { return }

            if let sourceEntry,
               let currentVariationId = sourceEntry.performedMovementId == movementId ? sourceEntry.performedVariationId : nil,
               variations.contains(where: { $0.id == currentVariationId }) {
                selectedVariationId = currentVariationId
            } else {
                selectedVariationId = variations.first?.id
                selectedNoVariation = variations.isEmpty
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(mode.confirmButtonTitle) {
                onConfirm(
                    ActiveWorkoutEntrySelection(
                        movementId: movementId,
                        variationId: selectedNoVariation ? nil : selectedVariationId,
                        plannedSetCount: plannedSetCount,
                        plannedRepRange: RepRange(min: plannedRepMin, max: plannedRepMax)
                    )
                )
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canConfirm || movement == nil)
            .opacity((canConfirm && movement != nil) ? 1 : 0.45)
            .padding()
            .background(AppTheme.background)
        }
    }
}

private enum ActiveWorkoutMovementPickerMode {
    case replace
    case add

    var navigationTitle: String {
        switch self {
        case .replace: return "Replace Movement"
        case .add: return "Add Movement"
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .replace: return "Replace in Workout"
        case .add: return "Add to Workout"
        }
    }
}

private struct ActiveWorkoutEntrySelection {
    let movementId: UUID
    let variationId: UUID?
    let plannedSetCount: Int
    let plannedRepRange: RepRange
}

private struct WorkoutMuscleGroupSection: Identifiable {
    let title: String
    let groups: [MuscleGroup]

    var id: String { title }
}

private struct WorkoutMovementSearchBar: View {
    @Binding var searchText: String
    @FocusState var searchFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Search exercises or aliases", text: $searchText)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit {
                        searchFocused = false
                    }
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(searchFocused ? AppTheme.accent.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )

            if searchFocused {
                Button {
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 52, height: 52)
                        .background(AppTheme.elevatedSurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss keyboard")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .animation(.snappy, value: searchFocused)
    }
}

private struct WorkoutMuscleGroupTile: View {
    let group: MuscleGroup
    let count: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayName)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(count) exercises")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.22) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? AppTheme.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}

private struct WorkoutMovementSelectionCard: View {
    let movement: Movement
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(movement.canonicalName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    if !movement.aliases.isEmpty {
                        Text("Aliases: \(movement.aliases.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }

            WorkoutFlowTagRow(tags: (movement.primaryMuscleGroups + movement.secondaryMuscleGroups).map(\.displayName))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.16) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? AppTheme.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}

private struct WorkoutVariationSelectionCard: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.accent.opacity(0.16) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? AppTheme.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                )
        )
    }
}

private struct WorkoutFlowTagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.14), in: Capsule())
                }
            }
        }
    }
}

private struct WorkoutTargetPickerCard: View {
    @Binding var plannedSetCount: Int
    @Binding var plannedRepMin: Int
    @Binding var plannedRepMax: Int

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Target")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Stepper("Sets: \(plannedSetCount)", value: $plannedSetCount, in: 1...20)
                    .foregroundStyle(AppTheme.textPrimary)

                Stepper("Minimum reps: \(plannedRepMin)", value: $plannedRepMin, in: 1...100)
                    .foregroundStyle(AppTheme.textPrimary)

                Stepper("Maximum reps: \(plannedRepMax)", value: $plannedRepMax, in: 1...100)
                    .foregroundStyle(AppTheme.textPrimary)

                if plannedRepMax < plannedRepMin {
                    Text("Maximum reps must be at least the minimum.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                } else {
                    Text("\(plannedSetCount) sets • \(RepRange(min: plannedRepMin, max: plannedRepMax).displayText) reps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
        }
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
