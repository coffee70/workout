import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImportURL: URL?
    @State private var showImportConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(eyebrow: "Data", title: "Back up the full database")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local-first storage")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Data lives in Application Support and is exported as a full JSON snapshot.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Button("Export Backup") {
                    exporting = true
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Import Backup") {
                    importing = true
                }
                .buttonStyle(SecondaryButtonStyle())

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schema v\(store.appData.schemaVersion)")
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Updated \(store.appData.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: $exporting,
            document: store.exportDocument(),
            contentType: .json,
            defaultFilename: store.exportFilename()
        ) { _ in
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showImportConfirmation = true
            case .failure(let error):
                store.errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Replace current data?", isPresented: $showImportConfirmation) {
            Button("Replace", role: .destructive) {
                if let pendingImportURL {
                    store.importBackup(from: pendingImportURL)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("Version 1 import replaces the current local database.")
        }
    }
}

