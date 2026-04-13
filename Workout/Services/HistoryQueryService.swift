import Foundation

struct HistoryResult {
    var exact: HistorySnapshot?
    var variationAnywhere: HistorySnapshot?
    var movementMatches: [HistorySnapshot]
}

struct HistoryQueryService {
    func lookup(
        variationId: UUID,
        movementId: UUID,
        currentLocationId: UUID,
        excluding sessionId: UUID?,
        in sessions: [WorkoutSession]
    ) -> HistoryResult {
        let snapshots = sessions
            .filter { $0.id != sessionId }
            .filter { $0.status == .completed }
            .flatMap { session in
                session.exerciseEntries.compactMap { entry -> HistorySnapshot? in
                    guard !entry.sets.isEmpty else { return nil }
                    return HistorySnapshot(
                        id: entry.id,
                        sessionId: session.id,
                        sessionDate: session.date,
                        locationId: session.locationId,
                        locationName: session.locationNameSnapshot,
                        movementName: entry.performedMovementNameSnapshot,
                        variationId: entry.performedVariationId,
                        variationName: entry.performedVariationNameSnapshot,
                        sets: entry.sets
                    )
                }
            }
            .sorted { $0.sessionDate > $1.sessionDate }

        let exact = snapshots.first { $0.variationId == variationId && $0.locationId == currentLocationId }
        let variationAnywhere = snapshots.first { $0.variationId == variationId }
        let movementMatches = snapshots.filter { $0.variationId != variationId && sessionMovementId(for: $0, in: sessions) == movementId }

        return HistoryResult(exact: exact, variationAnywhere: variationAnywhere, movementMatches: Array(movementMatches.prefix(3)))
    }

    private func sessionMovementId(for snapshot: HistorySnapshot, in sessions: [WorkoutSession]) -> UUID? {
        sessions.first(where: { $0.id == snapshot.sessionId })?
            .exerciseEntries.first(where: { $0.id == snapshot.id })?
            .plannedMovementId ??
        sessions.first(where: { $0.id == snapshot.sessionId })?
            .exerciseEntries.first(where: { $0.id == snapshot.id })?
            .performedMovementId
    }
}

