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

                Text("Tap an exercise to log sets.")
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
    @State private var isScrubbingMetric = false

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
            let labeledHistory = primaryHistory(from: store.history(for: session, entry: entry, locationId: location.id))
            return HistoryLocationDeckItem(location: location, title: labeledHistory.title, snapshot: labeledHistory.snapshot)
        }
    }

    var body: some View {
        if let session, let entry {
            let history = store.history(for: session, entry: entry)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(eyebrow: session.regimenDayNameSnapshot ?? "Workout", title: entry.performedMovementNameSnapshot)

                    TargetCard(entry: entry)

                    Text("Variation")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    RotatingSwipeDeck(items: variationDeckItems, onAdvance: { _ in
                        store.advanceVariation(sessionId: session.id, entryId: entry.id)
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
                    .frame(height: 170)

                    HistorySection(
                        items: historyDeckItems
                    ) {
                        store.advanceViewedHistoryLocation(sessionId: session.id, entryId: entry.id)
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
                                        startEditing(setId: set.id, field: .weight, initialValue: set.formattedWeight)
                                    } onScrubActiveChange: { isActive in
                                        isScrubbingMetric = isActive
                                    } onValueChange: { updatedWeight in
                                        store.updateSet(sessionId: session.id, entryId: entry.id, setId: set.id, weight: updatedWeight)
                                    }
                                    .frame(maxWidth: .infinity)
                                    LargeMetricButton(
                                        value: Double(set.reps),
                                        label: "Reps",
                                        configuration: .reps
                                    ) {
                                        startEditing(setId: set.id, field: .reps, initialValue: "\(set.reps)")
                                    } onScrubActiveChange: { isActive in
                                        isScrubbingMetric = isActive
                                    } onValueChange: { updatedReps in
                                        store.updateSet(sessionId: session.id, entryId: entry.id, setId: set.id, reps: Int(updatedReps))
                                    }
                                    .frame(maxWidth: .infinity)
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
            .scrollDisabled(isScrubbingMetric)
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
            }
        }
    }
}

private struct HistorySection: View {
    let items: [HistoryLocationDeckItem]
    let onAdvanceLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            RotatingSwipeDeck(items: items, onAdvance: { _ in
                onAdvanceLocation()
            }) { item in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.location.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(item.title)
                            .foregroundStyle(AppTheme.textSecondary)
                        if let snapshot = item.snapshot {
                            Text(snapshot.summary)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(snapshot.sessionDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(AppTheme.textMuted)
                        } else {
                            Text("No matching history yet.")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                }
            }
            .frame(height: 190)
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
