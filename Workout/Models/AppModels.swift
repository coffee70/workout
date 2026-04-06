import Foundation

struct AppData: Codable {
    var schemaVersion: Int
    var currentRegimenId: UUID?
    var activeWorkoutSessionId: UUID?
    var preferredWeightUnit: WeightUnit

    var movements: [Movement]
    var variations: [Variation]
    var locations: [Location]
    var regimens: [Regimen]
    var workoutSessions: [WorkoutSession]

    var createdAt: Date
    var updatedAt: Date

    static let currentSchemaVersion = 1

    static func empty(now: Date = .now) -> AppData {
        AppData(
            schemaVersion: currentSchemaVersion,
            currentRegimenId: nil,
            activeWorkoutSessionId: nil,
            preferredWeightUnit: .pounds,
            movements: [],
            variations: [],
            locations: [],
            regimens: [],
            workoutSessions: [],
            createdAt: now,
            updatedAt: now
        )
    }
}

struct Movement: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: String?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct Variation: Codable, Identifiable, Hashable {
    var id: UUID
    var movementId: UUID
    var name: String
    var implementType: ImplementType?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum ImplementType: String, Codable, CaseIterable, Hashable {
    case barbell
    case dumbbell
    case cable
    case machine
    case smith
    case bodyweight
    case plateLoaded
    case selectorized
    case other

    var displayName: String {
        switch self {
        case .plateLoaded: return "Plate Loaded"
        case .selectorized: return "Selectorized"
        default: return rawValue.capitalized
        }
    }
}

struct Location: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct Regimen: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isCurrent: Bool
    var days: [RegimenDay]
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

struct RegimenDay: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var orderIndex: Int
    var items: [RegimenItem]
    var notes: String?
}

struct RegimenItem: Codable, Identifiable, Hashable {
    var id: UUID
    var orderIndex: Int
    var movementId: UUID
    var defaultVariationId: UUID?
    var plannedSetCount: Int?
    var plannedRepRange: RepRange?
    var notes: String?
}

struct RepRange: Codable, Hashable {
    var min: Int
    var max: Int

    var displayText: String {
        "\(min)-\(max)"
    }
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: UUID
    var regimenId: UUID?
    var regimenNameSnapshot: String?
    var regimenDayId: UUID?
    var regimenDayNameSnapshot: String?
    var locationId: UUID
    var locationNameSnapshot: String
    var date: Date
    var startedAt: Date
    var endedAt: Date?
    var status: WorkoutSessionStatus
    var exerciseEntries: [WorkoutExerciseEntry]
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

enum WorkoutSessionStatus: String, Codable, Hashable {
    case active
    case completed
    case abandoned
}

struct WorkoutExerciseEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var orderIndex: Int
    var sourceRegimenItemId: UUID?

    var plannedMovementId: UUID?
    var plannedMovementNameSnapshot: String?
    var plannedVariationId: UUID?
    var plannedVariationNameSnapshot: String?

    var performedMovementId: UUID
    var performedMovementNameSnapshot: String
    var performedVariationId: UUID
    var performedVariationNameSnapshot: String

    var status: WorkoutExerciseStatus
    var viewedHistoryLocationId: UUID?
    var viewedHistoryLocationNameSnapshot: String?
    var sets: [SetEntry]
    var notes: String?
}

enum WorkoutExerciseStatus: String, Codable, Hashable {
    case notStarted
    case inProgress
    case completed
    case skipped
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var weightUnit: WeightUnit
    var rpe: Double?
    var note: String?
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum WeightUnit: String, Codable, CaseIterable, Hashable {
    case pounds
    case kilograms
    case machineUnits

    var displayName: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        case .machineUnits: return "units"
        }
    }
}

struct HistorySnapshot: Identifiable, Hashable {
    let id: UUID
    let sessionId: UUID
    let sessionDate: Date
    let locationId: UUID
    let locationName: String
    let movementName: String
    let variationId: UUID
    let variationName: String
    let sets: [SetEntry]

    var summary: String {
        let renderedSets = sets.sorted { $0.setNumber < $1.setNumber }.prefix(3).map {
            "\($0.formattedWeight) x \($0.reps)"
        }
        return renderedSets.joined(separator: " • ")
    }
}

extension SetEntry {
    var formattedWeight: String {
        if weight.rounded(.towardZero) == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }
}

enum HistoryScope: String, CaseIterable, Identifiable {
    case exact
    case variationAnywhere
    case movement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exact: return "Variation + Gym"
        case .variationAnywhere: return "Variation Anywhere"
        case .movement: return "Movement History"
        }
    }
}

