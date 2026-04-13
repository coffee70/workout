import Foundation

struct WorkoutSessionFactory {
    /// Explicit default variation if set, otherwise first non-archived variation for the movement.
    static func resolvedVariation(for item: RegimenItem, variations: [Variation]) -> Variation? {
        variations.first(where: { $0.id == item.defaultVariationId })
            ?? variations.first(where: { $0.movementId == item.movementId && !$0.isArchived })
    }

    func makeSession(regimen: Regimen?, day: RegimenDay, location: Location, movements: [Movement], variations: [Variation], now: Date = .now) -> WorkoutSession {
        let entries = day.items.sorted { $0.orderIndex < $1.orderIndex }.map { item in
            let movement = movements.first(where: { $0.id == item.movementId })
            let variation = Self.resolvedVariation(for: item, variations: variations)
            return WorkoutExerciseEntry(
                id: UUID(),
                orderIndex: item.orderIndex,
                sourceRegimenItemId: item.id,
                plannedMovementId: movement?.id,
                plannedMovementNameSnapshot: movement?.canonicalName,
                plannedVariationId: item.defaultVariationId,
                plannedVariationNameSnapshot: variation?.name,
                plannedSetCount: item.plannedSetCount,
                plannedRepRange: item.plannedRepRange,
                performedMovementId: movement?.id ?? item.movementId,
                performedMovementNameSnapshot: movement?.canonicalName ?? "Unknown Movement",
                performedVariationId: variation?.id ?? UUID(),
                performedVariationNameSnapshot: variation?.name ?? "Select Variation",
                status: .notStarted,
                viewedHistoryLocationId: location.id,
                viewedHistoryLocationNameSnapshot: location.name,
                sets: [],
                notes: item.notes
            )
        }

        return WorkoutSession(
            id: UUID(),
            regimenId: regimen?.id,
            regimenNameSnapshot: regimen?.name,
            regimenDayId: day.id,
            regimenDayNameSnapshot: day.name,
            locationId: location.id,
            locationNameSnapshot: location.name,
            date: now,
            startedAt: now,
            endedAt: nil,
            status: .active,
            exerciseEntries: entries,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
