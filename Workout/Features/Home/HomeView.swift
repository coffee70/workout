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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(Array(store.recentSessions.prefix(5))) { session in
                        SwipeToDeleteSessionCard {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.deleteWorkoutSession(session.id)
                            }
                        } content: {
                            RecentSessionCard(session: session)
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

private struct RecentSessionCard: View {
    let session: WorkoutSession

    var body: some View {
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

private struct SwipeToDeleteSessionCard<Content: View>: View {
    let onDelete: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false

    private let revealWidth: CGFloat = 86
    private let deleteButtonSize: CGFloat = 52

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                        offsetX = 0
                    }
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: deleteButtonSize, height: deleteButtonSize)
                        .background(
                            Circle()
                                .fill(AppTheme.danger)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
                .accessibilityLabel("Delete Workout Session")
            }

            content
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .allowsHitTesting(offsetX == 0)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { gesture in
                            if !isDragging {
                                dragStartOffset = offsetX
                                isDragging = true
                            }
                            offsetX = min(max(dragStartOffset + gesture.translation.width, -revealWidth), 0)
                        }
                        .onEnded { gesture in
                            let projectedOffset = min(max(dragStartOffset + gesture.translation.width, -revealWidth), 0)
                            let shouldReveal = projectedOffset < -(revealWidth * 0.45)
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                offsetX = shouldReveal ? -revealWidth : 0
                            }
                            dragStartOffset = offsetX
                            isDragging = false
                        }
                )
        }
        .clipped()
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
