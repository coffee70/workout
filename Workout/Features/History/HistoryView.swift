import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            ForEach(store.recentSessions.filter { $0.status == .completed || $0.status == .active }) { session in
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
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("History")
    }
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
                                    Text("Set \(set.setNumber): \(set.formattedWeight) \(set.weightUnit.displayName) x \(set.reps)")
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
