import Foundation

enum SeedData {
    static func make(now: Date = .now) -> AppData {
        let inclinePress = Movement(id: UUID(), name: "Incline Press", category: "Chest", notes: nil, isArchived: false, createdAt: now, updatedAt: now)
        let lateralRaise = Movement(id: UUID(), name: "Lateral Raise", category: "Shoulders", notes: nil, isArchived: false, createdAt: now, updatedAt: now)
        let tricepPress = Movement(id: UUID(), name: "Tricep Pressdown", category: "Triceps", notes: nil, isArchived: false, createdAt: now, updatedAt: now)
        let row = Movement(id: UUID(), name: "Chest Supported Row", category: "Back", notes: nil, isArchived: false, createdAt: now, updatedAt: now)

        let variations = [
            Variation(id: UUID(), movementId: inclinePress.id, name: "Incline Dumbbell Press", implementType: .dumbbell, notes: nil, isArchived: false, createdAt: now, updatedAt: now),
            Variation(id: UUID(), movementId: inclinePress.id, name: "Incline Machine Press", implementType: .machine, notes: nil, isArchived: false, createdAt: now, updatedAt: now),
            Variation(id: UUID(), movementId: lateralRaise.id, name: "Cable Lateral Raise", implementType: .cable, notes: nil, isArchived: false, createdAt: now, updatedAt: now),
            Variation(id: UUID(), movementId: tricepPress.id, name: "Rope Pushdown", implementType: .cable, notes: nil, isArchived: false, createdAt: now, updatedAt: now),
            Variation(id: UUID(), movementId: row.id, name: "Chest Supported T-Bar Row", implementType: .plateLoaded, notes: nil, isArchived: false, createdAt: now, updatedAt: now)
        ]

        let gym1 = Location(id: UUID(), name: "Gym 1", notes: "Main cable stack", isArchived: false, createdAt: now, updatedAt: now)
        let gym2 = Location(id: UUID(), name: "Gym 2", notes: "Different machine feel", isArchived: false, createdAt: now, updatedAt: now)

        let pushDay = RegimenDay(
            id: UUID(),
            name: "Push A",
            orderIndex: 0,
            items: [
                RegimenItem(id: UUID(), orderIndex: 0, movementId: inclinePress.id, defaultVariationId: variations.first(where: { $0.name == "Incline Dumbbell Press" })?.id, plannedSetCount: 3, plannedRepRange: RepRange(min: 6, max: 10), notes: nil),
                RegimenItem(id: UUID(), orderIndex: 1, movementId: lateralRaise.id, defaultVariationId: variations.first(where: { $0.name == "Cable Lateral Raise" })?.id, plannedSetCount: 3, plannedRepRange: RepRange(min: 10, max: 15), notes: nil),
                RegimenItem(id: UUID(), orderIndex: 2, movementId: tricepPress.id, defaultVariationId: variations.first(where: { $0.name == "Rope Pushdown" })?.id, plannedSetCount: 3, plannedRepRange: RepRange(min: 8, max: 12), notes: nil)
            ],
            notes: nil
        )

        let pullDay = RegimenDay(
            id: UUID(),
            name: "Pull A",
            orderIndex: 1,
            items: [
                RegimenItem(id: UUID(), orderIndex: 0, movementId: row.id, defaultVariationId: variations.first(where: { $0.name == "Chest Supported T-Bar Row" })?.id, plannedSetCount: 3, plannedRepRange: RepRange(min: 8, max: 12), notes: nil)
            ],
            notes: nil
        )

        let regimen = Regimen(id: UUID(), name: "Current Block", isCurrent: true, days: [pushDay, pullDay], notes: nil, createdAt: now, updatedAt: now)

        return AppData(
            schemaVersion: AppData.currentSchemaVersion,
            currentRegimenId: regimen.id,
            activeWorkoutSessionId: nil,
            preferredWeightUnit: .pounds,
            movements: [inclinePress, lateralRaise, tricepPress, row],
            variations: variations,
            locations: [gym1, gym2],
            regimens: [regimen],
            workoutSessions: [],
            createdAt: now,
            updatedAt: now
        )
    }
}

