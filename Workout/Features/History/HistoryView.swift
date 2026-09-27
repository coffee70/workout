import SwiftUI

private enum HistoryTab: String, CaseIterable, Identifiable {
    case explorer
    case sessions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer: return "Explorer"
        case .sessions: return "Sessions"
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab: HistoryTab = .explorer

    var body: some View {
        List {
            Section {
                HistoryTabSelector(selectedTab: $selectedTab)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            switch selectedTab {
            case .explorer:
                Section {
                    HistoryMovementGraphExplorer()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 16, trailing: 8))
                        .listRowBackground(Color.clear)
                }
            case .sessions:
                Section {
                    ForEach(store.recentSessions.filter { $0.status == .completed }) { session in
                        NavigationLink {
                            HistoryDetailView(sessionID: session.id)
                        } label: {
                            HistorySessionRow(session: session)
                        }
                        .listRowBackground(AppTheme.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.deleteWorkoutSession(session.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(AppTheme.danger)
                        }
                    }
                } header: {
                    Text("Sessions")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("History")
    }
}

private struct HistoryTabSelector: View {
    @Binding var selectedTab: HistoryTab

    var body: some View {
        LargeHistoryTabPicker(selectedTab: $selectedTab)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
    }
}

private final class HistorySegmentPickerHostView: UIView {
    let segmentedControl: UISegmentedControl
    private var enforcedHeight: CGFloat = 52

    init(segmentedControl: UISegmentedControl) {
        self.segmentedControl = segmentedControl
        super.init(frame: .zero)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setEnforcedHeight(_ height: CGFloat) {
        let rounded = ceil(height)
        guard enforcedHeight != rounded else { return }
        enforcedHeight = rounded
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: enforcedHeight)
    }

    static func minHeight(for font: UIFont) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .title3)
        let paddedLine = ceil(font.lineHeight + metrics.scaledValue(for: 18))
        let floor = metrics.scaledValue(for: 52)
        return max(floor, paddedLine)
    }
}

private struct LargeHistoryTabPicker: UIViewRepresentable {
    @Binding var selectedTab: HistoryTab

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: LargeHistoryTabPicker

        init(_ parent: LargeHistoryTabPicker) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            let cases = Array(HistoryTab.allCases)
            let idx = sender.selectedSegmentIndex
            guard idx >= 0, idx < cases.count else { return }
            let next = cases[idx]
            guard parent.selectedTab != next else { return }
            parent.selectedTab = next
        }
    }

    private static func titleFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: 20, weight: .semibold)
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: base)
    }

    private static func applyTitleFont(to control: UISegmentedControl) {
        let font = titleFont()
        control.setTitleTextAttributes([.font: font], for: .normal)
        control.setTitleTextAttributes([.font: font], for: .selected)
    }

    func makeUIView(context: Context) -> HistorySegmentPickerHostView {
        let control = UISegmentedControl(items: HistoryTab.allCases.map(\.title))
        Self.applyTitleFont(to: control)

        control.selectedSegmentIndex = HistoryTab.allCases.firstIndex(of: selectedTab) ?? 0
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        control.accessibilityLabel = "History Explorer or Sessions"

        let font = Self.titleFont()
        let host = HistorySegmentPickerHostView(segmentedControl: control)
        host.setEnforcedHeight(HistorySegmentPickerHostView.minHeight(for: font))
        return host
    }

    func updateUIView(_ host: HistorySegmentPickerHostView, context: Context) {
        Self.applyTitleFont(to: host.segmentedControl)

        let font = Self.titleFont()
        host.setEnforcedHeight(HistorySegmentPickerHostView.minHeight(for: font))

        let idx = HistoryTab.allCases.firstIndex(of: selectedTab) ?? 0
        if host.segmentedControl.selectedSegmentIndex != idx {
            host.segmentedControl.selectedSegmentIndex = idx
        }
    }
}

private struct HistoryMovementGraphExplorer: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedMovementId: UUID?
    @State private var selectedVariationId: UUID?
    @State private var selectedLocationId: UUID?
    @State private var selectedMetric: ExerciseProgressMetric = .reps
    @State private var isMovementPickerPresented = false

    private var effectiveMovement: Movement? {
        store.activeMovements.first { $0.id == selectedMovementId } ??
        preferredMovementId().flatMap { id in store.activeMovements.first { $0.id == id } }
    }

    private var effectiveVariationId: UUID? {
        guard let movementId = effectiveMovement?.id else { return nil }
        if let selectedVariationId, store.variations(for: movementId).contains(where: { $0.id == selectedVariationId }) {
            return selectedVariationId
        }
        return preferredVariationId(for: movementId)
    }

    private var effectiveLocationId: UUID? {
        guard let movementId = effectiveMovement?.id else { return nil }
        if let selectedLocationId, store.activeLocations.contains(where: { $0.id == selectedLocationId }) {
            return selectedLocationId
        }
        return preferredLocationId(for: movementId, variationId: effectiveVariationId)
    }

    private var graphSeries: [ExerciseProgressGraphSeries] {
        guard let movementId = effectiveMovement?.id, let variationId = effectiveVariationId, let locationId = effectiveLocationId else {
            return []
        }
        return ExerciseProgressGraphDataBuilder.series(
            from: store.progressGraphSnapshots(
                movementId: movementId,
                variationId: variationId,
                locationId: locationId,
                excluding: nil
            ),
            metric: selectedMetric
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Movement Graph")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            if let movement = effectiveMovement {
                MovementGraphSelector(
                    movement: movement,
                    onChooseMovement: {
                        isMovementPickerPresented = true
                    }
                )

                WorkoutExerciseGraphTabContent(
                    movementName: movement.canonicalName,
                    variationName: store.variationName(effectiveVariationId),
                    locationName: store.locationName(effectiveLocationId),
                    variationItems: variationItems(for: movement.id),
                    locationItems: locationItems(),
                    selectedVariationId: effectiveVariationId ?? UUID(),
                    selectedLocationId: effectiveLocationId ?? UUID(),
                    selectedMetric: $selectedMetric,
                    graphSeries: graphSeries,
                    graphEmptyMessage: "No graph history for this movement, variation, and gym yet.",
                    onSelectVariation: { variationId in
                        selectVariation(movementId: movement.id, variationId: variationId)
                    },
                    onSelectLocation: { locationId in
                        selectedLocationId = locationId
                    }
                )
            } else {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No movements yet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Add movements from Library to start building graph history.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: ensureValidSelection)
        .onChange(of: store.activeMovements.map(\.id)) { _, _ in ensureValidSelection() }
        .onChange(of: store.activeVariations.map(\.id)) { _, _ in ensureValidSelection() }
        .onChange(of: store.activeLocations.map(\.id)) { _, _ in ensureValidSelection() }
        .sheet(isPresented: $isMovementPickerPresented) {
            NavigationStack {
                HistoryMovementPickerView { movement in
                    selectedMovementId = movement.id
                    resetFilters(for: movement.id)
                    isMovementPickerPresented = false
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func ensureValidSelection() {
        guard !store.activeMovements.isEmpty else {
            selectedMovementId = nil
            selectedVariationId = nil
            selectedLocationId = nil
            return
        }

        if selectedMovementId == nil || !store.activeMovements.contains(where: { $0.id == selectedMovementId }) {
            let movementId = preferredMovementId()
            selectedMovementId = movementId
            resetFilters(for: movementId)
            return
        }

        guard let movementId = selectedMovementId else { return }
        if selectedVariationId == nil || !store.variations(for: movementId).contains(where: { $0.id == selectedVariationId }) {
            selectedVariationId = preferredVariationId(for: movementId)
        }
        if selectedLocationId == nil || !store.activeLocations.contains(where: { $0.id == selectedLocationId }) {
            selectedLocationId = preferredLocationId(for: movementId, variationId: selectedVariationId)
        }
    }

    private func resetFilters(for movementId: UUID?) {
        selectedVariationId = movementId.flatMap(preferredVariationId)
        selectedLocationId = movementId.flatMap { preferredLocationId(for: $0, variationId: selectedVariationId) }
    }

    private func variationItems(for movementId: UUID) -> [VariationDeckCardItem] {
        let variations = store.variations(for: movementId)
        guard let variationId = effectiveVariationId else { return [] }
        let order = orderedIDs(
            currentIDs: variations.map(\.id),
            preferredOrder: [],
            fallbackCurrentID: variationId
        )
        let variationsByID = Dictionary(uniqueKeysWithValues: variations.map { ($0.id, $0) })
        return order.compactMap { id in
            variationsByID[id].map(VariationDeckCardItem.init)
        }
    }

    private func locationItems() -> [LocationHistorySelectorItem] {
        guard let locationId = effectiveLocationId else { return [] }
        let locations = store.activeLocations
        let order = orderedIDs(
            currentIDs: locations.map(\.id),
            preferredOrder: [],
            fallbackCurrentID: locationId
        )
        let locationsByID = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
        return order.compactMap { id in
            locationsByID[id].map(LocationHistorySelectorItem.init)
        }
    }

    private func selectVariation(movementId: UUID, variationId: UUID) {
        selectedVariationId = variationId
        selectedLocationId = preferredLocationId(for: movementId, variationId: selectedVariationId)
    }

    private func preferredMovementId() -> UUID? {
        store.activeMovements.first { movement in
            dataBearingCombination(for: movement.id) != nil
        }?.id ?? store.activeMovements.first?.id
    }

    private func preferredVariationId(for movementId: UUID) -> UUID? {
        dataBearingCombination(for: movementId)?.variationId ?? store.variations(for: movementId).first?.id
    }

    private func preferredLocationId(for movementId: UUID, variationId: UUID?) -> UUID? {
        guard let variationId else { return store.activeLocations.first?.id }
        return store.activeLocations.first { location in
            hasGraphHistory(movementId: movementId, variationId: variationId, locationId: location.id)
        }?.id ?? store.activeLocations.first?.id
    }

    private func dataBearingCombination(for movementId: UUID) -> (variationId: UUID, locationId: UUID)? {
        for variation in store.variations(for: movementId) {
            for location in store.activeLocations where hasGraphHistory(
                movementId: movementId,
                variationId: variation.id,
                locationId: location.id
            ) {
                return (variation.id, location.id)
            }
        }
        return nil
    }

    private func hasGraphHistory(movementId: UUID, variationId: UUID, locationId: UUID) -> Bool {
        !store.progressGraphSnapshots(
            movementId: movementId,
            variationId: variationId,
            locationId: locationId,
            excluding: nil
        ).isEmpty
    }
}

private struct MovementGraphSelector: View {
    let movement: Movement
    let onChooseMovement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movement")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)

            Button(action: onChooseMovement) {
                SurfaceCard {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movement.canonicalName)
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let group = movement.primaryMuscleGroups.first {
                                Text(group.displayName)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose Movement")
            .accessibilityValue(movement.canonicalName)
        }
    }
}

private struct HistoryMovementPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let onSelect: (Movement) -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private let groupSections = [
        HistoryMuscleGroupSection(title: "Upper Body", groups: [.chest, .upperChest, .lats, .upperBack, .midBack, .traps, .frontDelts, .sideDelts, .rearDelts]),
        HistoryMuscleGroupSection(title: "Lower Body", groups: [.quadriceps, .hamstrings, .glutes, .calves, .adductors, .abductors, .spinalErectors]),
        HistoryMuscleGroupSection(title: "Arms", groups: [.biceps, .triceps, .forearms]),
        HistoryMuscleGroupSection(title: "Other", groups: [.abs])
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
                    movementList(searchResults, emptyMessage: "No matching movements.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Muscle Group")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        ForEach(groupSections) { section in
                            let groups = section.groups.filter { !store.searchMovements(query: searchText, muscleGroup: $0).isEmpty }
                            if !groups.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.textMuted)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                                        ForEach(groups, id: \.self) { group in
                                            NavigationLink {
                                                HistoryMovementGroupView(
                                                    group: group,
                                                    searchText: searchText,
                                                    onSelect: selectMovement
                                                )
                                            } label: {
                                                HistoryMuscleGroupTile(
                                                    group: group,
                                                    count: store.searchMovements(query: searchText, muscleGroup: group).count
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        if searchResults.isEmpty {
                            Text("No movements available. Add movements from Library first.")
                                .foregroundStyle(AppTheme.textMuted)
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
        .navigationTitle("Choose Movement")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HistoryMovementSearchBar(searchText: $searchText, searchFocused: _searchFocused)
        }
    }

    private func movementList(_ movements: [Movement], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movements")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(movements) { movement in
                Button {
                    selectMovement(movement)
                } label: {
                    HistoryMovementSelectionCard(movement: movement)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    searchFocused = false
                })
                .padding(.bottom, 6)
            }

            if movements.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private func selectMovement(_ movement: Movement) {
        onSelect(movement)
        dismiss()
    }
}

private struct HistoryMovementGroupView: View {
    @EnvironmentObject private var store: AppStore

    let group: MuscleGroup
    let searchText: String
    let onSelect: (Movement) -> Void

    private var movements: [Movement] {
        store.searchMovements(query: searchText, muscleGroup: group)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(eyebrow: "Muscle Group", title: group.displayName)

                ForEach(movements) { movement in
                    Button {
                        onSelect(movement)
                    } label: {
                        HistoryMovementSelectionCard(movement: movement)
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

private struct HistoryMovementSearchBar: View {
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

private struct HistoryMovementSelectionCard: View {
    let movement: Movement

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(movement.canonicalName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if !movement.aliases.isEmpty {
                    Text("Aliases: \(movement.aliases.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(2)
                }
                HistoryFlowTagRow(tags: movementTags)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var movementTags: [String] {
        (movement.primaryMuscleGroups + movement.secondaryMuscleGroups).map(\.displayName)
    }
}

private struct HistoryFlowTagRow: View {
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

private struct HistoryMuscleGroupTile: View {
    let group: MuscleGroup
    let count: Int

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(count) movement\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        }
    }
}

private struct HistoryMuscleGroupSection: Identifiable {
    let title: String
    let groups: [MuscleGroup]

    var id: String { title }
}

private struct HistorySessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.regimenDayNameSnapshot ?? "Workout")
                .font(.headline)
            Text(session.locationNameSnapshot)
                .foregroundStyle(.secondary)
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
        }
    }
}

private struct HistoryDetailView: View {
    @EnvironmentObject private var store: AppStore
    let sessionID: UUID

    var session: WorkoutSession? {
        store.appData.workoutSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        ScrollView {
            if let session {
                VStack(alignment: .leading, spacing: 16) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.regimenDayNameSnapshot ?? "Workout")
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(session.locationNameSnapshot)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }

                    ForEach(session.exerciseEntries.sorted(by: { $0.orderIndex < $1.orderIndex })) { entry in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.performedMovementNameSnapshot)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(entry.performedVariationNameSnapshot)
                                    .foregroundStyle(AppTheme.textSecondary)
                                ForEach(entry.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                                    Text("Set \(set.setNumber): \(set.formattedWeight) \(set.weightUnit.displayName) x \(set.reps)\(set.historyFlagSuffix)")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Session")
    }
}
