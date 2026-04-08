import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NavigationLink {
                    RegimenEditorView()
                } label: {
                    LibraryLandingCard(
                        title: "Regimens",
                        subtitle: "Workout days, planned movements, and target ranges.",
                        systemImage: "list.bullet.clipboard"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MovementListView()
                } label: {
                    LibraryLandingCard(
                        title: "Movements",
                        subtitle: "Exercises grouped by muscle group and variations.",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LocationListView()
                } label: {
                    LibraryLandingCard(
                        title: "Locations",
                        subtitle: "Gyms and training spaces for workout history.",
                        systemImage: "mappin.and.ellipse"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Library")
    }
}

private struct LibraryLandingCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }
}

struct MovementListView: View {
    @EnvironmentObject private var store: AppStore

    private let groupSections = [
        MuscleGroupSection(title: "Upper Body", groups: [.chest, .upperChest, .lats, .upperBack, .midBack, .traps, .frontDelts, .sideDelts, .rearDelts]),
        MuscleGroupSection(title: "Lower Body", groups: [.quadriceps, .hamstrings, .glutes, .calves, .adductors, .abductors, .spinalErectors]),
        MuscleGroupSection(title: "Arms", groups: [.biceps, .triceps, .forearms]),
        MuscleGroupSection(title: "Other", groups: [.abs])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(groupSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textMuted)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                            ForEach(section.groups, id: \.self) { group in
                                NavigationLink {
                                    MovementLibraryGroupView(group: group)
                                } label: {
                                    MuscleGroupTile(group: group, count: store.movements(for: group).count, isSelected: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Movements")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct MovementLibraryGroupView: View {
    @EnvironmentObject private var store: AppStore
    let group: MuscleGroup

    @State private var draft: MovementDraft?

    private var movements: [Movement] {
        store.movements(for: group)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(eyebrow: "Muscle Group", title: group.displayName)

                if movements.isEmpty {
                    ContentUnavailableView("No Movements", systemImage: "figure.strengthtraining.traditional", description: Text("Add your first \(group.displayName.lowercased()) movement."))
                } else {
                    ForEach(movements) { movement in
                        NavigationLink {
                            MovementDetailView(movementId: movement.id)
                        } label: {
                            MovementSelectionCard(movement: movement, isSelected: false)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draft = MovementDraft(primaryMuscleGroup: group)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(item: $draft) { currentDraft in
            NavigationStack {
                MovementEditView(
                    draft: currentDraft,
                    onCancel: { draft = nil },
                    onSave: { savedDraft in
                        draft = nil
                        store.upsertMovement(
                            id: savedDraft.movementId,
                            canonicalName: savedDraft.name,
                            aliases: savedDraft.aliasList,
                            primaryMuscleGroups: [savedDraft.primaryMuscleGroup],
                            notes: savedDraft.notes
                        )
                    }
                )
            }
        }
    }
}

private struct MovementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let movementId: UUID

    @State private var movementDraft: MovementDraft?
    @State private var draft: VariationDraft?
    @State private var movementToRemove: Movement?
    @State private var variationToRemove: Variation?

    private var movement: Movement? {
        store.movement(for: movementId)
    }

    var body: some View {
        List {
            if let movement {
                Section {
                    MovementSelectionCard(movement: movement, isSelected: false)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(AppTheme.background)
                    if let notes = movement.notes, !notes.isEmpty {
                        Text(notes)
                            .foregroundStyle(AppTheme.textSecondary)
                            .listRowBackground(AppTheme.surface)
                    }
                }

                Section("Variations") {
                    let variations = store.variations(for: movement.id)
                    if variations.isEmpty {
                        Text("No variations yet.")
                            .foregroundStyle(AppTheme.textMuted)
                            .listRowBackground(AppTheme.surface)
                    } else {
                        ForEach(variations) { variation in
                            VariationRow(
                                variation: variation,
                                onEdit: { draft = VariationDraft(variation: variation) },
                                onRemove: { variationToRemove = variation }
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView("Movement Not Found", systemImage: "figure.strengthtraining.traditional")
                    .listRowBackground(AppTheme.background)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(movement?.canonicalName ?? "Movement")
        .toolbar {
            if let movement {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Movement") {
                            movementDraft = MovementDraft(movement: movement)
                        }
                        Button("Remove Movement", role: .destructive) {
                            movementToRemove = movement
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(item: $movementDraft) { currentDraft in
            NavigationStack {
                MovementEditView(
                    draft: currentDraft,
                    onCancel: { movementDraft = nil },
                    onSave: { savedDraft in
                        movementDraft = nil
                        store.upsertMovement(
                            id: savedDraft.movementId,
                            canonicalName: savedDraft.name,
                            aliases: savedDraft.aliasList,
                            primaryMuscleGroups: [savedDraft.primaryMuscleGroup],
                            notes: savedDraft.notes
                        )
                    }
                )
            }
        }
        .sheet(item: $draft) { currentDraft in
            NavigationStack {
                VariationEditView(
                    draft: currentDraft,
                    movements: movement.map { [$0] } ?? [],
                    onCancel: { draft = nil },
                    onSave: { savedDraft in
                        draft = nil
                        store.upsertVariation(
                            id: savedDraft.variationId,
                            movementId: movementId,
                            name: savedDraft.name,
                            equipmentCategory: savedDraft.equipmentCategory,
                            notes: savedDraft.notes
                        )
                    }
                )
            }
        }
        .alert("Remove Variation?", isPresented: Binding(
            get: { variationToRemove != nil },
            set: { if !$0 { variationToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let variationToRemove {
                    store.archiveVariation(variationToRemove.id)
                }
                variationToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                variationToRemove = nil
            }
        } message: {
            Text("This hides the variation from future selection without deleting workout history.")
        }
        .alert("Remove Movement?", isPresented: Binding(
            get: { movementToRemove != nil },
            set: { if !$0 { movementToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let movementToRemove {
                    store.archiveMovement(movementToRemove.id)
                }
                movementToRemove = nil
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                movementToRemove = nil
            }
        } message: {
            Text("This hides the movement from future selection without deleting workout history.")
        }
        .safeAreaInset(edge: .bottom) {
            if movement != nil {
                Button {
                    draft = VariationDraft(defaultMovementId: movementId)
                } label: {
                    Label("Add Variation", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .background(AppTheme.background)
            }
        }
    }
}

private struct VariationRow: View {
    let variation: Variation
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(variation.name)
                .foregroundStyle(AppTheme.textPrimary)
            if let equipmentCategory = variation.equipmentCategory {
                Text(equipmentCategory.displayName)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .listRowBackground(AppTheme.surface)
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Remove", role: .destructive, action: onRemove)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .tint(AppTheme.danger)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .tint(AppTheme.accent)
        }
    }
}

struct LocationListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: LocationDraft?
    @State private var locationToRemove: Location?

    var body: some View {
        List {
            ForEach(store.activeLocations) { location in
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                    if let notes = location.notes {
                        Text(notes).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(AppTheme.surface)
                .contextMenu {
                    Button("Edit") {
                        draft = LocationDraft(location: location)
                    }
                    Button("Remove", role: .destructive) {
                        locationToRemove = location
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        locationToRemove = location
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(AppTheme.danger)

                    Button {
                        draft = LocationDraft(location: location)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(AppTheme.accent)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draft = LocationDraft()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(item: $draft) { currentDraft in
            NavigationStack {
                LocationEditView(
                    draft: currentDraft,
                    onCancel: { draft = nil },
                    onSave: { savedDraft in
                        draft = nil
                        store.upsertLocation(id: savedDraft.locationId, name: savedDraft.name, notes: savedDraft.notes)
                    }
                )
            }
        }
        .alert("Remove Location?", isPresented: Binding(
            get: { locationToRemove != nil },
            set: { if !$0 { locationToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let locationToRemove {
                    store.archiveLocation(locationToRemove.id)
                }
                locationToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                locationToRemove = nil
            }
        } message: {
            Text("This hides the location from future selection without deleting workout history.")
        }
    }
}

struct RegimenEditorView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: RegimenDraft?
    @State private var showArchived = false
    @State private var regimenToArchive: Regimen?

    private var visibleRegimens: [Regimen] {
        showArchived ? store.archivedRegimens : store.regimensByCurrentThenName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Toggle("Show Archived", isOn: $showArchived)
                    .tint(AppTheme.accent)
                    .foregroundStyle(AppTheme.textSecondary)

                ForEach(visibleRegimens) { regimen in
                    NavigationLink {
                        RegimenDetailView(regimenId: regimen.id)
                    } label: {
                        SurfaceCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(regimen.name)
                                        .font(.title2.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(regimen.days.count) days")
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if regimen.isArchived {
                                    StatusPill(title: "Archived", color: AppTheme.textMuted)
                                } else if regimen.id == store.currentRegimen?.id {
                                    StatusPill(title: "Active", color: AppTheme.accentSecondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if regimen.isArchived {
                            Button("Restore") {
                                store.restoreRegimen(regimen.id)
                            }
                        } else if regimen.id != store.currentRegimen?.id {
                            Button("Archive", role: .destructive) {
                                regimenToArchive = regimen
                            }
                        }
                    }
                }

                Button("New Regimen") {
                    draft = RegimenDraft()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Regimens")
        .sheet(item: $draft) { currentDraft in
            NavigationStack {
                RegimenEditView(
                    draft: currentDraft,
                    onCancel: { draft = nil },
                    onSave: { savedDraft in
                        draft = nil
                        store.createRegimen(named: savedDraft.name)
                    }
                )
            }
        }
        .alert("Archive Regimen?", isPresented: Binding(
            get: { regimenToArchive != nil },
            set: { if !$0 { regimenToArchive = nil } }
        )) {
            Button("Archive", role: .destructive) {
                if let regimenToArchive {
                    store.archiveRegimen(regimenToArchive.id)
                }
                regimenToArchive = nil
            }
            Button("Cancel", role: .cancel) {
                regimenToArchive = nil
            }
        } message: {
            Text("Archived regimens are hidden until Show Archived is enabled.")
        }
    }
}

private struct RegimenDetailView: View {
    @EnvironmentObject private var store: AppStore
    let regimenId: UUID

    @State private var regimenDraft: RegimenDraft?
    @State private var dayDraft: RegimenDayDraft?
    @State private var showNewDay = false
    @State private var newDayName = ""
    @State private var addItemTarget: AddRegimenItemTarget?
    @State private var itemDraft: RegimenItemDraft?
    @State private var regimenToArchive: Regimen?
    @State private var expandedDayIds: Set<UUID> = []

    private var regimen: Regimen? {
        store.regimen(regimenId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let regimen {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(regimen.name)
                                        .font(.title2.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(regimen.id == store.currentRegimen?.id ? "Active regimen" : "Inactive regimen")
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                PillActionButton(title: "Edit", systemImage: "pencil") {
                                    regimenDraft = RegimenDraft(regimen: regimen)
                                }
                            }

                            if regimen.isArchived {
                                Button("Restore") {
                                    store.restoreRegimen(regimen.id)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else if regimen.id != store.currentRegimen?.id {
                                Button("Make Active") {
                                    store.setCurrentRegimen(regimen.id)
                                }
                                .buttonStyle(SecondaryButtonStyle())

                                Button("Archive") {
                                    regimenToArchive = regimen
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(regimen.days.sorted(by: { $0.orderIndex < $1.orderIndex })) { day in
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    let isExpanded = expandedDayIds.contains(day.id)

                                    Button {
                                        if isExpanded {
                                            expandedDayIds.remove(day.id)
                                        } else {
                                            expandedDayIds.insert(day.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(day.name)
                                                    .font(.headline)
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text("\(day.items.count) movements")
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                                .font(.footnote.weight(.bold))
                                                .foregroundStyle(AppTheme.textMuted)
                                                .frame(width: 32, height: 32)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(day.name), \(day.items.count) movements")
                                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                                    if isExpanded {
                                        ForEach(day.items.sorted(by: { $0.orderIndex < $1.orderIndex })) { item in
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text(store.movementName(item.movementId))
                                                        .foregroundStyle(AppTheme.textPrimary)
                                                    Spacer()
                                                    if let muscleGroup = store.primaryMuscleGroupName(for: item.movementId) {
                                                        StatusPill(title: muscleGroup, color: AppTheme.accent)
                                                    }
                                                }
                                                Text(store.variationName(item.defaultVariationId))
                                                    .foregroundStyle(AppTheme.textSecondary)
                                                Text(item.targetSummary)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.accentSecondary)
                                            }
                                            .padding(.vertical, 4)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                itemDraft = RegimenItemDraft(regimenId: regimen.id, dayId: day.id, item: item)
                                            }
                                            .contextMenu {
                                                Button("Edit Target") {
                                                    itemDraft = RegimenItemDraft(regimenId: regimen.id, dayId: day.id, item: item)
                                                }
                                            }
                                        }

                                        HStack(spacing: 10) {
                                            Button {
                                                dayDraft = RegimenDayDraft(day: day, regimenId: regimen.id)
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .buttonStyle(CompactSecondaryButtonStyle())

                                            Button {
                                                addItemTarget = AddRegimenItemTarget(regimenId: regimen.id, dayId: day.id)
                                            } label: {
                                                Label("Add", systemImage: "plus")
                                            }
                                            .buttonStyle(CompactSecondaryButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Regimen Not Found", systemImage: "list.bullet.clipboard")
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(regimen?.name ?? "Regimen")
        .safeAreaInset(edge: .bottom) {
            if let regimen, !regimen.isArchived {
                HStack {
                    Spacer()
                    Button {
                        showNewDay = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Day")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(AppTheme.background.opacity(0.95))
            }
        }
        .sheet(item: $regimenDraft) { currentDraft in
            NavigationStack {
                RegimenEditView(
                    draft: currentDraft,
                    onCancel: { regimenDraft = nil },
                    onSave: { savedDraft in
                        regimenDraft = nil
                        if let regimenId = savedDraft.regimenId {
                            store.updateRegimen(id: regimenId, name: savedDraft.name, notes: savedDraft.notes)
                        }
                    }
                )
            }
        }
        .sheet(item: $dayDraft) { currentDraft in
            NavigationStack {
                RegimenDayEditView(
                    draft: currentDraft,
                    onCancel: { dayDraft = nil },
                    onSave: { savedDraft in
                        dayDraft = nil
                        store.updateRegimenDay(regimenId: savedDraft.regimenId, dayId: savedDraft.dayId, name: savedDraft.name, notes: savedDraft.notes)
                    }
                )
            }
        }
        .sheet(isPresented: $showNewDay) {
            NavigationStack {
                Form {
                    TextField("Day name", text: $newDayName)
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("New Day")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showNewDay = false
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            showNewDay = false
                            if let regimen {
                                store.addDay(to: regimen.id, name: newDayName)
                            }
                            newDayName = ""
                        }
                        .disabled(newDayName.trimmed.isEmpty)
                        .foregroundStyle(AppTheme.accent)
                    }
                }
            }
        }
        .sheet(item: $addItemTarget) { target in
            NavigationStack {
                AddRegimenItemView(regimenId: target.regimenId, dayId: target.dayId)
            }
            .environmentObject(store)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $itemDraft) { currentDraft in
            NavigationStack {
                RegimenItemEditView(
                    draft: currentDraft,
                    onCancel: { itemDraft = nil },
                    onSave: { savedDraft in
                        itemDraft = nil
                        store.updateRegimenItem(
                            regimenId: savedDraft.regimenId,
                            dayId: savedDraft.dayId,
                            itemId: savedDraft.itemId,
                            defaultVariationId: savedDraft.selectedNoDefault ? nil : savedDraft.defaultVariationId,
                            plannedSetCount: savedDraft.plannedSetCount,
                            plannedRepRange: savedDraft.repRange,
                            notes: savedDraft.notes
                        )
                    }
                )
            }
            .environmentObject(store)
        }
        .alert("Archive Regimen?", isPresented: Binding(
            get: { regimenToArchive != nil },
            set: { if !$0 { regimenToArchive = nil } }
        )) {
            Button("Archive", role: .destructive) {
                if let regimenToArchive {
                    store.archiveRegimen(regimenToArchive.id)
                }
                regimenToArchive = nil
            }
            Button("Cancel", role: .cancel) {
                regimenToArchive = nil
            }
        } message: {
            Text("Archived regimens are hidden until Show Archived is enabled.")
        }
    }
}

private struct AddRegimenItemTarget: Identifiable {
    let regimenId: UUID
    let dayId: UUID

    var id: UUID { dayId }
}

private struct AddRegimenItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let regimenId: UUID
    let dayId: UUID

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private let groupSections = [
        MuscleGroupSection(title: "Upper Body", groups: [.chest, .upperChest, .lats, .upperBack, .midBack, .traps, .frontDelts, .sideDelts, .rearDelts]),
        MuscleGroupSection(title: "Lower Body", groups: [.quadriceps, .hamstrings, .glutes, .calves, .adductors, .abductors, .spinalErectors]),
        MuscleGroupSection(title: "Arms", groups: [.biceps, .triceps, .forearms]),
        MuscleGroupSection(title: "Other", groups: [.abs])
    ]

    private var isSearching: Bool {
        !searchText.trimmed.isEmpty
    }

    private var searchResults: [Movement] {
        store.searchMovements(query: searchText)
    }

    private var floatingSearchBar: some View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose a muscle group, then select an exercise and variation.")
                    .foregroundStyle(AppTheme.textSecondary)

                if isSearching {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Movements")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        ForEach(searchResults) { movement in
                            NavigationLink {
                                RegimenMovementVariationView(
                                    regimenId: regimenId,
                                    dayId: dayId,
                                    movementId: movement.id,
                                    onAdd: { dismiss() }
                                )
                            } label: {
                                MovementSelectionCard(movement: movement, isSelected: false)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                searchFocused = false
                            })
                            .padding(.bottom, 6)
                        }

                        if searchResults.isEmpty {
                            Text("No matching movements.")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
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
                                                MovementGroupSelectionView(
                                                    regimenId: regimenId,
                                                    dayId: dayId,
                                                    group: group,
                                                    searchText: searchText,
                                                    onAdd: { dismiss() }
                                                )
                                            } label: {
                                                MuscleGroupTile(group: group, count: store.searchMovements(query: searchText, muscleGroup: group).count, isSelected: false)
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
            .padding()
            .padding(.bottom, 78)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Add Movement")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            floatingSearchBar
        }
    }
}

private struct MovementGroupSelectionView: View {
    @EnvironmentObject private var store: AppStore
    let regimenId: UUID
    let dayId: UUID
    let group: MuscleGroup
    let searchText: String
    let onAdd: () -> Void

    private var movements: [Movement] {
        store.searchMovements(query: searchText, muscleGroup: group)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(eyebrow: "Muscle Group", title: group.displayName)

                ForEach(movements) { movement in
                    NavigationLink {
                        RegimenMovementVariationView(
                            regimenId: regimenId,
                            dayId: dayId,
                            movementId: movement.id,
                            onAdd: onAdd
                        )
                    } label: {
                        MovementSelectionCard(movement: movement, isSelected: false)
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

private struct RegimenMovementVariationView: View {
    @EnvironmentObject private var store: AppStore
    let regimenId: UUID
    let dayId: UUID
    let movementId: UUID
    let onAdd: () -> Void

    @State private var selectedVariationId: UUID?
    @State private var selectedNoDefault = false
    @State private var plannedSetCount = 3
    @State private var plannedRepMin = 8
    @State private var plannedRepMax = 12

    private var movement: Movement? {
        store.movement(for: movementId)
    }

    private var variations: [Variation] {
        store.variations(for: movementId)
    }

    private var canAdd: Bool {
        (selectedNoDefault || selectedVariationId != nil || variations.isEmpty) && targetIsValid
    }

    private var targetIsValid: Bool {
        plannedSetCount > 0 && plannedRepMin > 0 && plannedRepMax >= plannedRepMin
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let movement {
                    MovementSelectionCard(movement: movement, isSelected: false)

                    if variations.isEmpty {
                        Button {
                            selectedNoDefault = true
                            selectedVariationId = nil
                        } label: {
                            VariationSelectionCard(title: "Add without default variation", subtitle: nil, isSelected: selectedNoDefault)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(variations) { variation in
                            Button {
                                selectedVariationId = variation.id
                                selectedNoDefault = false
                            } label: {
                                VariationSelectionCard(
                                    title: variation.name,
                                    subtitle: variation.equipmentCategory?.displayName,
                                    isSelected: selectedVariationId == variation.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TargetPickerCard(
                        plannedSetCount: $plannedSetCount,
                        plannedRepMin: $plannedRepMin,
                        plannedRepMax: $plannedRepMax
                    )
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
            if selectedVariationId == nil, !selectedNoDefault {
                selectedVariationId = variations.first?.id
                selectedNoDefault = variations.isEmpty
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Add to Day") {
                if let movement {
                    store.addRegimenItem(
                        to: regimenId,
                        dayId: dayId,
                        movementId: movement.id,
                        defaultVariationId: selectedNoDefault ? nil : selectedVariationId,
                        plannedSetCount: plannedSetCount,
                        plannedRepRange: RepRange(min: plannedRepMin, max: plannedRepMax)
                    )
                }
                onAdd()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canAdd || movement == nil)
            .opacity((canAdd && movement != nil) ? 1 : 0.45)
            .padding()
            .background(AppTheme.background)
        }
    }
}

private struct RegimenItemEditView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: RegimenItemDraft
    let onCancel: () -> Void
    let onSave: (RegimenItemDraft) -> Void

    init(draft: RegimenItemDraft, onCancel: @escaping () -> Void, onSave: @escaping (RegimenItemDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private var movement: Movement? {
        store.movement(for: draft.movementId)
    }

    private var variations: [Variation] {
        store.variations(for: draft.movementId)
    }

    private var canSave: Bool {
        draft.plannedSetCount > 0 && draft.plannedRepMin > 0 && draft.plannedRepMax >= draft.plannedRepMin
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let movement {
                    MovementSelectionCard(movement: movement, isSelected: false)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default Variation")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Button {
                            draft.selectedNoDefault = true
                            draft.defaultVariationId = nil
                        } label: {
                            VariationSelectionCard(title: "No default variation", subtitle: nil, isSelected: draft.selectedNoDefault)
                        }
                        .buttonStyle(.plain)

                        ForEach(variations) { variation in
                            Button {
                                draft.defaultVariationId = variation.id
                                draft.selectedNoDefault = false
                            } label: {
                                VariationSelectionCard(
                                    title: variation.name,
                                    subtitle: variation.equipmentCategory?.displayName,
                                    isSelected: draft.defaultVariationId == variation.id && !draft.selectedNoDefault
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TargetPickerCard(
                        plannedSetCount: $draft.plannedSetCount,
                        plannedRepMin: $draft.plannedRepMin,
                        plannedRepMax: $draft.plannedRepMax
                    )

                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .foregroundStyle(AppTheme.textPrimary)
                        .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ContentUnavailableView("Movement Not Found", systemImage: "figure.strengthtraining.traditional")
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Edit Target")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(!canSave)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private struct TargetPickerCard: View {
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

private struct MuscleGroupSection: Identifiable {
    let title: String
    let groups: [MuscleGroup]

    var id: String { title }
}

private struct MuscleGroupTile: View {
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

private struct MovementSelectionCard: View {
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

            FlowTagRow(tags: movementTags)
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

    private var movementTags: [String] {
        (movement.primaryMuscleGroups + movement.secondaryMuscleGroups).map(\.displayName)
    }
}

private struct VariationSelectionCard: View {
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

private struct FlowTagRow: View {
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

private struct PillActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CompactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(AppTheme.elevatedSurface)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}

private struct MovementDraft: Identifiable {
    let id = UUID()
    var movementId: UUID?
    var name = ""
    var aliases = ""
    var primaryMuscleGroup: MuscleGroup = .chest
    var notes = ""

    var aliasList: [String] {
        aliases.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
    }

    init(primaryMuscleGroup: MuscleGroup = .chest) {
        self.primaryMuscleGroup = primaryMuscleGroup
    }

    init(movement: Movement) {
        movementId = movement.id
        name = movement.canonicalName
        aliases = movement.aliases.joined(separator: ", ")
        primaryMuscleGroup = movement.primaryMuscleGroups.first ?? .chest
        notes = movement.notes ?? ""
    }
}

private struct VariationDraft: Identifiable {
    let id = UUID()
    var variationId: UUID?
    var movementId: UUID?
    var name = ""
    var equipmentCategory: EquipmentCategory = .dumbbell
    var notes = ""

    init(defaultMovementId: UUID?) {
        movementId = defaultMovementId
    }

    init(variation: Variation) {
        variationId = variation.id
        movementId = variation.movementId
        name = variation.name
        equipmentCategory = variation.equipmentCategory ?? .dumbbell
        notes = variation.notes ?? ""
    }
}

private struct LocationDraft: Identifiable {
    let id = UUID()
    var locationId: UUID?
    var name = ""
    var notes = ""

    init() {}

    init(location: Location) {
        locationId = location.id
        name = location.name
        notes = location.notes ?? ""
    }
}

private struct RegimenDraft: Identifiable {
    let id = UUID()
    var regimenId: UUID?
    var name = ""
    var notes = ""

    init() {}

    init(regimen: Regimen) {
        regimenId = regimen.id
        name = regimen.name
        notes = regimen.notes ?? ""
    }
}

private struct RegimenDayDraft: Identifiable {
    let id = UUID()
    let regimenId: UUID
    let dayId: UUID
    var name: String
    var notes: String

    init(day: RegimenDay, regimenId: UUID) {
        self.regimenId = regimenId
        dayId = day.id
        name = day.name
        notes = day.notes ?? ""
    }
}

private struct RegimenItemDraft: Identifiable {
    let id = UUID()
    let regimenId: UUID
    let dayId: UUID
    let itemId: UUID
    let movementId: UUID
    var defaultVariationId: UUID?
    var selectedNoDefault: Bool
    var plannedSetCount: Int
    var plannedRepMin: Int
    var plannedRepMax: Int
    var notes: String

    var repRange: RepRange {
        RepRange(min: plannedRepMin, max: plannedRepMax)
    }

    init(regimenId: UUID, dayId: UUID, item: RegimenItem) {
        self.regimenId = regimenId
        self.dayId = dayId
        itemId = item.id
        movementId = item.movementId
        defaultVariationId = item.defaultVariationId
        selectedNoDefault = item.defaultVariationId == nil
        plannedSetCount = item.plannedSetCount ?? 3
        plannedRepMin = item.plannedRepRange?.min ?? 8
        plannedRepMax = item.plannedRepRange?.max ?? 12
        notes = item.notes ?? ""
    }
}

private struct MovementEditView: View {
    @State private var draft: MovementDraft
    let onCancel: () -> Void
    let onSave: (MovementDraft) -> Void

    init(draft: MovementDraft, onCancel: @escaping () -> Void, onSave: @escaping (MovementDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Canonical name", text: $draft.name)
            TextField("Aliases, comma separated", text: $draft.aliases)
            Picker("Primary muscle", selection: $draft.primaryMuscleGroup) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Text(group.displayName).tag(group)
                }
            }
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(draft.movementId == nil ? "New Movement" : "Edit Movement")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(draft.name.trimmed.isEmpty)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private struct VariationEditView: View {
    @State private var draft: VariationDraft
    let movements: [Movement]
    let onCancel: () -> Void
    let onSave: (VariationDraft) -> Void

    init(draft: VariationDraft, movements: [Movement], onCancel: @escaping () -> Void, onSave: @escaping (VariationDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.movements = movements
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Variation name", text: $draft.name)
            Picker("Movement", selection: $draft.movementId) {
                ForEach(movements) { movement in
                    Text(movement.canonicalName).tag(Optional(movement.id))
                }
            }
            Picker("Equipment", selection: $draft.equipmentCategory) {
                ForEach(EquipmentCategory.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(draft.variationId == nil ? "New Variation" : "Edit Variation")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(draft.name.trimmed.isEmpty || draft.movementId == nil)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private struct LocationEditView: View {
    @State private var draft: LocationDraft
    let onCancel: () -> Void
    let onSave: (LocationDraft) -> Void

    init(draft: LocationDraft, onCancel: @escaping () -> Void, onSave: @escaping (LocationDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(draft.locationId == nil ? "New Location" : "Edit Location")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(draft.name.trimmed.isEmpty)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private struct RegimenEditView: View {
    @State private var draft: RegimenDraft
    let onCancel: () -> Void
    let onSave: (RegimenDraft) -> Void

    init(draft: RegimenDraft, onCancel: @escaping () -> Void, onSave: @escaping (RegimenDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(draft.regimenId == nil ? "New Regimen" : "Edit Regimen")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(draft.name.trimmed.isEmpty)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private struct RegimenDayEditView: View {
    @State private var draft: RegimenDayDraft
    let onCancel: () -> Void
    let onSave: (RegimenDayDraft) -> Void

    init(draft: RegimenDayDraft, onCancel: @escaping () -> Void, onSave: @escaping (RegimenDayDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Edit Day")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { onSave(draft) }
                    .disabled(draft.name.trimmed.isEmpty)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
