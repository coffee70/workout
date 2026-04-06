import SwiftUI

struct LibraryView: View {
    var body: some View {
        List {
            NavigationLink("Regimen", destination: RegimenEditorView())
            NavigationLink("Movements", destination: MovementListView())
            NavigationLink("Variations", destination: VariationListView())
            NavigationLink("Locations", destination: LocationListView())
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Library")
    }
}

struct MovementListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var name = ""
    @State private var category = ""

    var body: some View {
        List {
            ForEach(store.activeMovements) { movement in
                VStack(alignment: .leading, spacing: 4) {
                    Text(movement.name)
                    if let category = movement.category {
                        Text(category).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(AppTheme.surface)
                .contextMenu {
                    Button("Archive", role: .destructive) {
                        store.archiveMovement(movement.id)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Movements")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { showAdd = true }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .alert("New Movement", isPresented: $showAdd) {
            TextField("Name", text: $name)
            TextField("Category", text: $category)
            Button("Save") {
                store.upsertMovement(name: name, category: category, notes: nil)
                name = ""
                category = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct VariationListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var name = ""
    @State private var selectedMovementId: UUID?
    @State private var implementType: ImplementType = .dumbbell

    var body: some View {
        List {
            ForEach(store.activeMovements) { movement in
                Section(movement.name) {
                    ForEach(store.variations(for: movement.id)) { variation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(variation.name)
                            if let implementType = variation.implementType {
                                Text(implementType.displayName).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(AppTheme.surface)
                        .contextMenu {
                            Button("Archive", role: .destructive) {
                                store.archiveVariation(variation.id)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Variations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { showAdd = true }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Variation name", text: $name)
                    Picker("Movement", selection: $selectedMovementId) {
                        ForEach(store.activeMovements) { movement in
                            Text(movement.name).tag(Optional(movement.id))
                        }
                    }
                    Picker("Implement", selection: $implementType) {
                        ForEach(ImplementType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle("New Variation")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showAdd = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            if let movementId = selectedMovementId {
                                store.upsertVariation(movementId: movementId, name: name, implementType: implementType)
                            }
                            showAdd = false
                            name = ""
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedMovementId = selectedMovementId ?? store.activeMovements.first?.id
        }
    }
}

struct LocationListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var name = ""
    @State private var notes = ""

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
                    Button("Archive", role: .destructive) {
                        store.archiveLocation(location.id)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { showAdd = true }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .alert("New Location", isPresented: $showAdd) {
            TextField("Name", text: $name)
            TextField("Notes", text: $notes)
            Button("Save") {
                store.upsertLocation(name: name, notes: notes)
                name = ""
                notes = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct RegimenEditorView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showNewRegimen = false
    @State private var showNewDay = false
    @State private var showNewItem = false
    @State private var regimenName = ""
    @State private var dayName = ""
    @State private var selectedDayId: UUID?
    @State private var selectedMovementId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let regimen = store.currentRegimen {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(regimen.name)
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Current regimen")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(regimen.days.sorted(by: { $0.orderIndex < $1.orderIndex })) { day in
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(day.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Button("Add Movement") {
                                            selectedDayId = day.id
                                            selectedMovementId = store.activeMovements.first?.id
                                            showNewItem = true
                                        }
                                        .foregroundStyle(AppTheme.accent)
                                    }
                                    ForEach(day.items.sorted(by: { $0.orderIndex < $1.orderIndex })) { item in
                                        Text(store.movementName(item.movementId) + " • " + store.variationName(item.defaultVariationId))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    Button("Add Day") {
                        showNewDay = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("New Regimen") {
                    showNewRegimen = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Regimen")
        .alert("New Regimen", isPresented: $showNewRegimen) {
            TextField("Regimen name", text: $regimenName)
            Button("Save") {
                store.createRegimen(named: regimenName)
                regimenName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("New Day", isPresented: $showNewDay) {
            TextField("Day name", text: $dayName)
            Button("Save") {
                if let regimenId = store.currentRegimen?.id {
                    store.addDay(to: regimenId, name: dayName)
                }
                dayName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showNewItem) {
            NavigationStack {
                AddRegimenItemView(dayId: selectedDayId)
            }
            .environmentObject(store)
        }
    }
}

private struct AddRegimenItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let dayId: UUID?

    @State private var movementId: UUID?
    @State private var variationId: UUID?

    var body: some View {
        Form {
            Picker("Movement", selection: $movementId) {
                ForEach(store.activeMovements) { movement in
                    Text(movement.name).tag(Optional(movement.id))
                }
            }
            Picker("Default Variation", selection: $variationId) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(store.variations(for: movementId ?? store.activeMovements.first?.id ?? UUID())) { variation in
                    Text(variation.name).tag(Optional(variation.id))
                }
            }
        }
        .navigationTitle("Add Movement")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let regimenId = store.currentRegimen?.id, let dayId, let movementId {
                        store.addRegimenItem(to: regimenId, dayId: dayId, movementId: movementId, defaultVariationId: variationId)
                    }
                    dismiss()
                }
            }
        }
        .onAppear {
            movementId = movementId ?? store.activeMovements.first?.id
        }
        .onChange(of: movementId) {
            variationId = store.variations(for: movementId ?? UUID()).first?.id
        }
    }
}

