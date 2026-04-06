import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "square.stack.3d.up.fill")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(item: Binding(
            get: { store.presentedWorkoutSessionID.map(WorkoutPresentation.init(id:)) },
            set: { store.presentedWorkoutSessionID = $0?.id }
        )) { presentation in
            WorkoutFlowView(sessionID: presentation.id)
                .environmentObject(store)
        }
        .alert("App Notice", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { _ in store.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct WorkoutPresentation: Identifiable {
    let id: UUID
}
