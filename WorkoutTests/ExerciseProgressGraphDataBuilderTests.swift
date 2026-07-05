import XCTest
@testable import Workout

final class ExerciseProgressGraphDataBuilderTests: XCTestCase {
    func testGraphSnapshotsFilterExactMovementVariationLocationAndExcludeCurrentSession() {
        let movementId = UUID()
        let variationId = UUID()
        let locationId = UUID()
        let excludedSessionId = UUID()

        let matchingSession = makeSession(
            movementId: movementId,
            variationId: variationId,
            locationId: locationId,
            date: date(daysFromStart: 1)
        )
        let activeSession = makeSession(
            id: excludedSessionId,
            movementId: movementId,
            variationId: variationId,
            locationId: locationId,
            date: date(daysFromStart: 2)
        )
        let wrongVariation = makeSession(
            movementId: movementId,
            variationId: UUID(),
            locationId: locationId,
            date: date(daysFromStart: 3)
        )
        let wrongLocation = makeSession(
            movementId: movementId,
            variationId: variationId,
            locationId: UUID(),
            date: date(daysFromStart: 4)
        )
        let wrongMovement = makeSession(
            movementId: UUID(),
            variationId: variationId,
            locationId: locationId,
            date: date(daysFromStart: 5)
        )

        let snapshots = HistoryQueryService().graphSnapshots(
            movementId: movementId,
            variationId: variationId,
            locationId: locationId,
            excluding: excludedSessionId,
            in: [matchingSession, activeSession, wrongVariation, wrongLocation, wrongMovement]
        )

        XCTAssertEqual(snapshots.map(\.sessionId), [matchingSession.id])
    }

    func testRepsSeriesGroupsBySetNumberSortsAscendingAndLeavesMissingSetsAsGaps() {
        let snapshots = [
            makeSnapshot(
                sessionId: UUID(),
                date: date(daysFromStart: 3),
                sets: [
                    makeSet(id: UUID(), setNumber: 1, reps: 10),
                    makeSet(id: UUID(), setNumber: 2, reps: 8)
                ]
            ),
            makeSnapshot(
                sessionId: UUID(),
                date: date(daysFromStart: 1),
                sets: [
                    makeSet(id: UUID(), setNumber: 1, reps: 6)
                ]
            ),
            makeSnapshot(
                sessionId: UUID(),
                date: date(daysFromStart: 2),
                sets: [
                    makeSet(id: UUID(), setNumber: 1, reps: 7),
                    makeSet(id: UUID(), setNumber: 3, reps: 5)
                ]
            )
        ]

        let series = ExerciseProgressGraphDataBuilder.series(from: snapshots, metric: .reps)

        XCTAssertEqual(series.map(\.setNumber), [1, 2, 3])
        XCTAssertEqual(series[0].points.map(\.value), [6, 7, 10])
        XCTAssertEqual(series[0].points.map(\.date), [date(daysFromStart: 1), date(daysFromStart: 2), date(daysFromStart: 3)])
        XCTAssertEqual(series[1].points.map(\.value), [8])
        XCTAssertEqual(series[2].points.map(\.value), [5])
    }

    func testWeightSeriesUsesSetWeightValues() {
        let snapshots = [
            makeSnapshot(
                sessionId: UUID(),
                date: date(daysFromStart: 1),
                sets: [
                    makeSet(id: UUID(), setNumber: 1, reps: 8, weight: 95),
                    makeSet(id: UUID(), setNumber: 2, reps: 6, weight: 100.5)
                ]
            )
        ]

        let series = ExerciseProgressGraphDataBuilder.series(from: snapshots, metric: .weight)

        XCTAssertEqual(series.map(\.setNumber), [1, 2])
        XCTAssertEqual(series[0].points.map(\.value), [95])
        XCTAssertEqual(series[1].points.map(\.value), [100.5])
    }

    func testSeriesPreservesMachineOverloadFlag() {
        let snapshots = [
            makeSnapshot(
                sessionId: UUID(),
                date: date(daysFromStart: 1),
                sets: [
                    makeSet(id: UUID(), setNumber: 1, reps: 8, usedMachineOverload: true),
                    makeSet(id: UUID(), setNumber: 2, reps: 6, usedMachineOverload: false)
                ]
            )
        ]

        let series = ExerciseProgressGraphDataBuilder.series(from: snapshots, metric: .reps)

        XCTAssertEqual(series[0].points.map(\.usedMachineOverload), [true])
        XCTAssertEqual(series[1].points.map(\.usedMachineOverload), [false])
    }

    private func makeSession(
        id: UUID = UUID(),
        movementId: UUID,
        variationId: UUID,
        locationId: UUID,
        date: Date
    ) -> WorkoutSession {
        WorkoutSession(
            id: id,
            regimenId: nil,
            regimenNameSnapshot: nil,
            regimenDayId: nil,
            regimenDayNameSnapshot: nil,
            locationId: locationId,
            locationNameSnapshot: "Gym",
            date: date,
            startedAt: date,
            endedAt: date,
            status: .completed,
            exerciseEntries: [
                WorkoutExerciseEntry(
                    id: UUID(),
                    orderIndex: 0,
                    sourceRegimenItemId: nil,
                    plannedMovementId: movementId,
                    plannedMovementNameSnapshot: "Press",
                    plannedVariationId: variationId,
                    plannedVariationNameSnapshot: "Incline",
                    plannedSetCount: nil,
                    plannedRepRange: nil,
                    performedMovementId: movementId,
                    performedMovementNameSnapshot: "Press",
                    performedVariationId: variationId,
                    performedVariationNameSnapshot: "Incline",
                    status: .completed,
                    viewedHistoryLocationId: locationId,
                    viewedHistoryLocationNameSnapshot: "Gym",
                    sets: [makeSet(id: UUID(), setNumber: 1, reps: 8)],
                    notes: nil
                )
            ],
            notes: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeSnapshot(sessionId: UUID, date: Date, sets: [SetEntry]) -> HistorySnapshot {
        HistorySnapshot(
            id: UUID(),
            sessionId: sessionId,
            sessionDate: date,
            locationId: UUID(),
            locationName: "Gym",
            movementId: UUID(),
            movementName: "Press",
            variationId: UUID(),
            variationName: "Incline",
            sets: sets
        )
    }

    private func makeSet(
        id: UUID,
        setNumber: Int,
        reps: Int,
        weight: Double = 100,
        usedMachineOverload: Bool = false
    ) -> SetEntry {
        SetEntry(
            id: id,
            setNumber: setNumber,
            reps: reps,
            weight: weight,
            weightUnit: .pounds,
            rpe: nil,
            note: nil,
            completed: true,
            usedMachineOverload: usedMachineOverload,
            createdAt: date(daysFromStart: 0),
            updatedAt: date(daysFromStart: 0)
        )
    }

    private func date(daysFromStart: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 1 + daysFromStart))!
    }
}
