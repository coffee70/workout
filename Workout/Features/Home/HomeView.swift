import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showStartWorkout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(eyebrow: "Workout", title: "Train")

                if let active = store.activeWorkoutSession {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resume Active Workout")
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(active.regimenDayNameSnapshot ?? "Workout")
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(active.locationNameSnapshot)
                                .foregroundStyle(AppTheme.textMuted)
                            Button("Resume Workout") {
                                store.presentWorkout(sessionId: active.id)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(store.currentRegimen?.name ?? "No current regimen")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Choose a day, choose a gym, and move through the workout like a checklist.")
                            .foregroundStyle(AppTheme.textSecondary)
                        Button("Start Workout") {
                            showStartWorkout = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }

                if let regimen = store.currentRegimen {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                        ForEach(regimen.days.sorted(by: { $0.orderIndex < $1.orderIndex })) { day in
                            SurfaceCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(day.name)
                                            .font(.title3.bold())
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(day.items.count) planned movements")
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStartWorkout) {
            NavigationStack {
                StartWorkoutView()
            }
            .environmentObject(store)
        }
    }
}

struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var selectedDayId: UUID?
    @State private var selectedLocationIndex = 0

    var regimen: Regimen? { store.currentRegimen }
    var orderedLocations: [Location] {
        guard !store.activeLocations.isEmpty else { return [] }
        return store.activeLocations.rotated(startingAt: selectedLocationIndex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionTitle(eyebrow: "Start", title: "Pick your day and gym")

                if let regimen {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout Day")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                        ForEach(regimen.days.sorted(by: { $0.orderIndex < $1.orderIndex })) { day in
                            DaySelectionCard(
                                title: day.name,
                                movementCount: day.items.count,
                                isSelected: selectedDayId == day.id
                            )
                            .onTapGesture {
                                selectedDayId = day.id
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No Regimen", systemImage: "list.bullet.clipboard", description: Text("Create a regimen in Library before starting a workout."))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Location")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if store.activeLocations.isEmpty {
                        ContentUnavailableView("No Locations", systemImage: "mappin.and.ellipse", description: Text("Add a location in Library before starting a workout."))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.activeLocations.count > 1 ? "Swipe a card away to cycle gyms." : "Your workout will use this gym.")
                                .foregroundStyle(AppTheme.textMuted)

                            RotatingSwipeDeck(items: orderedLocations, onAdvance: { _ in
                                guard !store.activeLocations.isEmpty else { return }
                                selectedLocationIndex = (selectedLocationIndex + 1) % store.activeLocations.count
                            }) { location in
                                SurfaceCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(location.name)
                                            .font(.largeTitle.bold())
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(location.notes ?? "Use this location to set the workout context.")
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                                }
                                .padding(.horizontal, 4)
                            }
                            .frame(height: 220)
                        }
                    }
                }

                Button("Start Workout") {
                    let defaultDayId = selectedDayId ?? regimen?.days.first?.id
                    guard let defaultDayId,
                          let day = regimen?.days.first(where: { $0.id == defaultDayId }),
                          !store.activeLocations.isEmpty else { return }
                    let location = store.activeLocations[selectedLocationIndex]
                    store.startWorkout(day: day, location: location)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(regimen?.days.isEmpty != false || store.activeLocations.isEmpty)
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .onAppear {
            if selectedDayId == nil {
                selectedDayId = regimen?.days.sorted(by: { $0.orderIndex < $1.orderIndex }).first?.id
            }
        }
    }
}

private struct DaySelectionCard: View {
    let title: String
    let movementCount: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(movementCount) movements")
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title2)
            }
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
