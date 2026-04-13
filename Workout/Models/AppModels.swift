import Foundation

nonisolated struct AppData: Codable {
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

    static let currentSchemaVersion = 5

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

nonisolated struct Movement: Codable, Identifiable, Hashable {
    var id: UUID
    var canonicalName: String
    var aliases: [String]
    var primaryMuscleGroups: [MuscleGroup]
    var secondaryMuscleGroups: [MuscleGroup]
    var movementPattern: MovementPattern?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct Variation: Codable, Identifiable, Hashable {
    var id: UUID
    var movementId: UUID
    var name: String
    var equipmentCategory: EquipmentCategory?
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

nonisolated enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case quadriceps
    case hamstrings
    case glutes
    case calves
    case adductors
    case abductors
    case chest
    case upperChest
    case frontDelts
    case sideDelts
    case rearDelts
    case triceps
    case lats
    case upperBack
    case midBack
    case traps
    case biceps
    case forearms
    case spinalErectors
    case abs

    var displayName: String {
        switch self {
        case .quadriceps: return "Quadriceps"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .adductors: return "Adductors"
        case .abductors: return "Abductors"
        case .chest: return "Chest"
        case .upperChest: return "Upper Chest"
        case .frontDelts: return "Front Delts"
        case .sideDelts: return "Side Delts"
        case .rearDelts: return "Rear Delts"
        case .triceps: return "Triceps"
        case .lats: return "Lats"
        case .upperBack: return "Upper Back"
        case .midBack: return "Mid Back"
        case .traps: return "Traps"
        case .biceps: return "Biceps"
        case .forearms: return "Forearms"
        case .spinalErectors: return "Spinal Erectors"
        case .abs: return "Abs"
        }
    }
}

nonisolated enum EquipmentCategory: String, Codable, CaseIterable, Hashable {
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

nonisolated enum MovementPattern: String, Codable, CaseIterable, Hashable {
    case squat
    case hinge
    case horizontalPress
    case verticalPress
    case fly
    case horizontalRow
    case verticalPull
    case curl
    case extensionMovement = "extension"
    case raise
    case calfRaise
    case adduction
    case abduction

    var displayName: String {
        switch self {
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .horizontalPress: return "Horizontal Press"
        case .verticalPress: return "Vertical Press"
        case .fly: return "Fly"
        case .horizontalRow: return "Horizontal Row"
        case .verticalPull: return "Vertical Pull"
        case .curl: return "Curl"
        case .extensionMovement: return "Extension"
        case .raise: return "Raise"
        case .calfRaise: return "Calf Raise"
        case .adduction: return "Adduction"
        case .abduction: return "Abduction"
        }
    }
}

nonisolated struct Location: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct Regimen: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var isCurrent: Bool
    var days: [RegimenDay]
    var notes: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct RegimenDay: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var orderIndex: Int
    var items: [RegimenItem]
    var notes: String?
}

nonisolated struct RegimenItem: Codable, Identifiable, Hashable {
    var id: UUID
    var orderIndex: Int
    var movementId: UUID
    var defaultVariationId: UUID?
    var plannedSetCount: Int?
    var plannedRepRange: RepRange?
    var notes: String?
}

nonisolated struct RepRange: Codable, Hashable {
    var min: Int
    var max: Int

    var displayText: String {
        "\(min)-\(max)"
    }
}

nonisolated struct WorkoutSession: Codable, Identifiable, Hashable {
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

nonisolated enum WorkoutSessionStatus: String, Codable, Hashable {
    case active
    case completed
    case abandoned
}

nonisolated struct WorkoutExerciseEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var orderIndex: Int
    var sourceRegimenItemId: UUID?

    var plannedMovementId: UUID?
    var plannedMovementNameSnapshot: String?
    var plannedVariationId: UUID?
    var plannedVariationNameSnapshot: String?
    var plannedSetCount: Int?
    var plannedRepRange: RepRange?

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

nonisolated enum WorkoutExerciseStatus: String, Codable, Hashable {
    case notStarted
    case inProgress
    case completed
    case skipped

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }
}

nonisolated struct SetEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var weightUnit: WeightUnit
    var rpe: Double?
    var note: String?
    var completed: Bool
    /// Fractional stack / micro-load pin used.
    var usedMachineOverload: Bool
    /// Logged weight is per side (e.g. each dumbbell) when true.
    var perSide: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, setNumber, reps, weight, weightUnit, rpe, note, completed
        case usedMachineOverload, perSide
        case weightScope
        case createdAt, updatedAt
    }

    init(
        id: UUID,
        setNumber: Int,
        reps: Int,
        weight: Double,
        weightUnit: WeightUnit,
        rpe: Double?,
        note: String?,
        completed: Bool,
        usedMachineOverload: Bool = false,
        perSide: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.weightUnit = weightUnit
        self.rpe = rpe
        self.note = note
        self.completed = completed
        self.usedMachineOverload = usedMachineOverload
        self.perSide = perSide
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        setNumber = try c.decode(Int.self, forKey: .setNumber)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        weightUnit = try c.decode(WeightUnit.self, forKey: .weightUnit)
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        completed = try c.decode(Bool.self, forKey: .completed)
        usedMachineOverload = try c.decodeIfPresent(Bool.self, forKey: .usedMachineOverload) ?? false
        if let decoded = try c.decodeIfPresent(Bool.self, forKey: .perSide) {
            perSide = decoded
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .weightScope) {
            perSide = legacy == "perSide"
        } else {
            perSide = false
        }
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(setNumber, forKey: .setNumber)
        try c.encode(reps, forKey: .reps)
        try c.encode(weight, forKey: .weight)
        try c.encode(weightUnit, forKey: .weightUnit)
        try c.encodeIfPresent(rpe, forKey: .rpe)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(completed, forKey: .completed)
        try c.encode(usedMachineOverload, forKey: .usedMachineOverload)
        try c.encode(perSide, forKey: .perSide)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

nonisolated enum WeightUnit: String, Codable, CaseIterable, Hashable {
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

nonisolated struct HistorySnapshot: Identifiable, Hashable {
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
            "\($0.formattedWeight) x \($0.reps)\($0.historyFlagSuffix)"
        }
        return renderedSets.joined(separator: " • ")
    }
}

extension SetEntry {
    nonisolated var formattedWeight: String {
        if weight.rounded(.towardZero) == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }

    /// Suffix for history strings when overload or per-side flags are set (empty if neither).
    nonisolated var historyFlagSuffix: String {
        var parts: [String] = []
        if usedMachineOverload { parts.append("Overloaded") }
        if perSide { parts.append("Per Side") }
        guard !parts.isEmpty else { return "" }
        return " · " + parts.joined(separator: " · ")
    }
}

extension RegimenItem {
    nonisolated var targetSummary: String {
        ExerciseTargetSummary.text(setCount: plannedSetCount, repRange: plannedRepRange)
    }
}

extension WorkoutExerciseEntry {
    nonisolated var targetSummary: String {
        ExerciseTargetSummary.text(setCount: plannedSetCount, repRange: plannedRepRange)
    }
}

nonisolated enum ExerciseTargetSummary {
    static func text(setCount: Int?, repRange: RepRange?) -> String {
        switch (setCount, repRange) {
        case let (.some(setCount), .some(repRange)):
            return "\(setCount) sets • \(repRange.displayText) reps"
        case let (.some(setCount), .none):
            return "\(setCount) sets"
        case let (.none, .some(repRange)):
            return "\(repRange.displayText) reps"
        case (.none, .none):
            return "No target set"
        }
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
