import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum PersistenceError: Error {
    case unsupportedSchemaVersion(Int)
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var appData: AppData

    init(appData: AppData) {
        self.appData = appData
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.appData = try PersistenceService.makeDecoder().decode(AppData.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoded = try PersistenceService.makeEncoder().encode(appData)
        return .init(regularFileWithContents: encoded)
    }
}

struct PersistenceService {
    private let fileManager = FileManager.default
    private let fileName = "appData.json"
    private let backupFileName = "appData.backup.json"

    func load() throws -> AppData {
        let url = try dataURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return SeedData.make()
        }

        do {
            let data = try Data(contentsOf: url)
            return try decode(data)
        } catch {
            let backupURL = try backupURL()
            if fileManager.fileExists(atPath: backupURL.path) {
                let data = try Data(contentsOf: backupURL)
                return try decode(data)
            }
            throw error
        }
    }

    func save(_ appData: AppData) throws {
        let primaryURL = try dataURL()
        let backupURL = try backupURL()
        let encoded = try Self.makeEncoder().encode(appData)
        try fileManager.createDirectory(at: primaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: primaryURL.path) {
            let current = try Data(contentsOf: primaryURL)
            try current.write(to: backupURL, options: .atomic)
        }
        try encoded.write(to: primaryURL, options: .atomic)
    }

    func exportFilename(date: Date = .now) -> String {
        "WorkoutTrackerBackup-\(Self.fileStampFormatter.string(from: date)).json"
    }

    func importData(from url: URL) throws -> AppData {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    private func decode(_ data: Data) throws -> AppData {
        let decoded = try Self.makeDecoder().decode(AppData.self, from: data)
        guard decoded.schemaVersion == AppData.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }

    private func dataURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(fileName)
    }

    private func backupURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent(backupFileName)
    }

    private func applicationSupportDirectory() throws -> URL {
        try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return formatter
    }()
}
