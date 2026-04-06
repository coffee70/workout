import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showStartWorkout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(eyebrow: "Workout", title: "Train the current block")

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
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .onTapGesture {
                                showStartWorkout = true
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(Array(store.recentSessions.prefix(5))) { session in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.regimenDayNameSnapshot ?? "Workout")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(session.locationNameSnapshot)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(AppTheme.textMuted)
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
                            SurfaceCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(day.name)
                                            .font(.title3.bold())
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("\(day.items.count) movements")
                                            .foregroundStyle(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    if selectedDayId == day.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.accentSecondary)
                                            .font(.title2)
                                    }
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(selectedDayId == day.id ? AppTheme.accent : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedDayId = day.id
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Location")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)

                    TabView(selection: $selectedLocationIndex) {
                        ForEach(Array(store.activeLocations.enumerated()), id: \.offset) { index, location in
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(location.name)
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(location.notes ?? "Swipe between gyms to set the session context.")
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                            }
                            .tag(index)
                            .padding(.horizontal, 4)
                        }
                    }
                    .frame(height: 220)
                    .tabViewStyle(.page(indexDisplayMode: .always))
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
