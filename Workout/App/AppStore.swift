import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var appData: AppData = .empty()
    @Published var presentedWorkoutSessionID: UUID?
    @Published var errorMessage: String?

    private let persistence = PersistenceService()
    private let sessionFactory = WorkoutSessionFactory()
    private let historyService = HistoryQueryService()

    init() {
        load()
    }

    var currentRegimen: Regimen? {
        appData.regimens.first(where: { $0.id == appData.currentRegimenId && !$0.isArchived }) ?? appData.regimens.first { $0.isCurrent && !$0.isArchived }
    }

    var activeWorkoutSession: WorkoutSession? {
        guard let id = appData.activeWorkoutSessionId else { return nil }
        return appData.workoutSessions.first(where: { $0.id == id })
    }

    var activeLocations: [Location] {
        appData.locations.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    var activeMovements: [Movement] {
        appData.movements.filter { !$0.isArchived }.sorted { $0.canonicalName < $1.canonicalName }
    }

    var activeVariations: [Variation] {
        appData.variations.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    var recentSessions: [WorkoutSession] {
        appData.workoutSessions.sorted { $0.startedAt > $1.startedAt }
    }

    var regimensByCurrentThenName: [Regimen] {
        activeRegimens.sorted {
            if $0.id == appData.currentRegimenId { return true }
            if $1.id == appData.currentRegimenId { return false }
            if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
            return $0.name < $1.name
        }
    }

    var activeRegimens: [Regimen] {
        appData.regimens.filter { !$0.isArchived }
    }

    var archivedRegimens: [Regimen] {
        appData.regimens.filter(\.isArchived).sorted { $0.name < $1.name }
    }

    func variations(for movementId: UUID) -> [Variation] {
        activeVariations.filter { $0.movementId == movementId }
    }

    func movements(for muscleGroup: MuscleGroup) -> [Movement] {
        activeMovements.filter { movement in
            movement.primaryMuscleGroups.contains(muscleGroup) || movement.secondaryMuscleGroups.contains(muscleGroup)
        }
    }

    func searchMovements(query: String, muscleGroup: MuscleGroup? = nil) -> [Movement] {
        let baseMovements = muscleGroup.map(movements(for:)) ?? activeMovements
        guard !query.trimmed.isEmpty else { return baseMovements }
        return baseMovements.filter { movementMatchesSearch($0, query: query) }
    }

    func movementMatchesSearch(_ movement: Movement, query: String) -> Bool {
        let normalizedQuery = query.normalizedSearchText
        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        guard !normalizedQuery.isEmpty else { return true }

        let searchableValues = [movement.canonicalName] + movement.aliases
        return searchableValues.contains { value in
            let normalizedValue = value.normalizedSearchText
            let compactValue = normalizedValue.replacingOccurrences(of: " ", with: "")
            return normalizedValue.contains(normalizedQuery) || compactValue.contains(compactQuery)
        }
    }

    func canonicalMovement(for query: String) -> Movement? {
        let normalizedQuery = query.normalizedSearchText
        guard !normalizedQuery.isEmpty else { return nil }
        return activeMovements.first { movement in
            ([movement.canonicalName] + movement.aliases).contains { $0.normalizedSearchText == normalizedQuery }
        } ?? searchMovements(query: query).first
    }

    func movement(for id: UUID?) -> Movement? {
        appData.movements.first(where: { $0.id == id })
    }

    func movementName(_ id: UUID?) -> String {
        movement(for: id)?.canonicalName ?? "Unknown Movement"
    }

    func primaryMuscleGroupName(for movementId: UUID?) -> String? {
        movement(for: movementId)?.primaryMuscleGroups.first?.displayName
    }

    func regimen(_ id: UUID?) -> Regimen? {
        appData.regimens.first(where: { $0.id == id })
    }

    func variationName(_ id: UUID?) -> String {
        appData.variations.first(where: { $0.id == id })?.name ?? "Select Variation"
    }

    func locationName(_ id: UUID?) -> String {
        appData.locations.first(where: { $0.id == id })?.name ?? "Unknown Gym"
    }

    func history(for session: WorkoutSession, entry: WorkoutExerciseEntry) -> HistoryResult {
        let lookupLocation = entry.viewedHistoryLocationId ?? session.locationId
        return history(for: session, entry: entry, locationId: lookupLocation)
    }

    func history(for session: WorkoutSession, entry: WorkoutExerciseEntry, locationId: UUID) -> HistoryResult {
        return historyService.lookup(
            variationId: entry.performedVariationId,
            movementId: entry.performedMovementId,
            currentLocationId: locationId,
            excluding: session.id,
            in: appData.workoutSessions
        )
    }

    func load() {
        do {
            appData = try persistence.load()
        } catch {
            appData = SeedData.make()
            errorMessage = "Failed to load saved data. Movement catalog was restored."
            save()
        }
    }

    func replaceAllData(with newData: AppData) {
        appData = newData
        save()
    }

    func startWorkout(day: RegimenDay, location: Location) {
        let session = sessionFactory.makeSession(
            regimen: currentRegimen,
            day: day,
            location: location,
            movements: appData.movements,
            variations: appData.variations
        )
        appData.workoutSessions.insert(session, at: 0)
        appData.activeWorkoutSessionId = session.id
        presentedWorkoutSessionID = session.id
        touch()
        Haptics.success()
    }

    func presentWorkout(sessionId: UUID) {
        presentedWorkoutSessionID = sessionId
    }

    func dismissPresentedWorkout() {
        presentedWorkoutSessionID = nil
    }

    func finishWorkout(sessionId: UUID) {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        appData.workoutSessions[sessionIndex].status = .completed
        appData.workoutSessions[sessionIndex].endedAt = .now
        appData.workoutSessions[sessionIndex].updatedAt = .now
        if appData.activeWorkoutSessionId == sessionId {
            appData.activeWorkoutSessionId = nil
        }
        if presentedWorkoutSessionID == sessionId {
            presentedWorkoutSessionID = nil
        }
        touch()
        Haptics.success()
    }

    func abandonWorkout(sessionId: UUID) {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        appData.workoutSessions[sessionIndex].status = .abandoned
        appData.workoutSessions[sessionIndex].endedAt = .now
        appData.workoutSessions[sessionIndex].updatedAt = .now
        if appData.activeWorkoutSessionId == sessionId {
            appData.activeWorkoutSessionId = nil
        }
        if presentedWorkoutSessionID == sessionId {
            presentedWorkoutSessionID = nil
        }
        touch()
    }

    func updateViewedHistoryLocation(sessionId: UUID, entryId: UUID, locationId: UUID) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            entry.viewedHistoryLocationId = locationId
            entry.viewedHistoryLocationNameSnapshot = locationName(locationId)
        }
        Haptics.light()
    }

    func cycleVariation(sessionId: UUID, entryId: UUID, direction: Int) {
        guard let entry = workoutEntry(sessionId: sessionId, entryId: entryId) else { return }
        let allVariations = variations(for: entry.performedMovementId)
        guard !allVariations.isEmpty else { return }
        guard let currentIndex = allVariations.firstIndex(where: { $0.id == entry.performedVariationId }) else {
            setVariation(sessionId: sessionId, entryId: entryId, variation: allVariations[0])
            return
        }
        let nextIndex = (currentIndex + direction + allVariations.count) % allVariations.count
        setVariation(sessionId: sessionId, entryId: entryId, variation: allVariations[nextIndex])
    }

    func advanceVariation(sessionId: UUID, entryId: UUID) {
        guard let entry = workoutEntry(sessionId: sessionId, entryId: entryId) else { return }
        let allVariations = variations(for: entry.performedMovementId)
        guard !allVariations.isEmpty else { return }
        guard let currentIndex = allVariations.firstIndex(where: { $0.id == entry.performedVariationId }) else {
            setVariation(sessionId: sessionId, entryId: entryId, variation: allVariations[0])
            return
        }

        let nextIndex = (currentIndex + 1) % allVariations.count
        guard allVariations[nextIndex].id != entry.performedVariationId else { return }
        setVariation(sessionId: sessionId, entryId: entryId, variation: allVariations[nextIndex])
    }

    func advanceViewedHistoryLocation(sessionId: UUID, entryId: UUID) {
        guard let session = appData.workoutSessions.first(where: { $0.id == sessionId }),
              let entry = session.exerciseEntries.first(where: { $0.id == entryId }) else { return }

        let locations = activeLocations
        guard !locations.isEmpty else { return }

        let currentId = entry.viewedHistoryLocationId ?? session.locationId
        guard let currentIndex = locations.firstIndex(where: { $0.id == currentId }) else {
            updateViewedHistoryLocation(sessionId: sessionId, entryId: entryId, locationId: locations[0].id)
            return
        }

        let nextIndex = (currentIndex + 1) % locations.count
        guard locations[nextIndex].id != currentId else { return }
        updateViewedHistoryLocation(sessionId: sessionId, entryId: entryId, locationId: locations[nextIndex].id)
    }

    func setVariation(sessionId: UUID, entryId: UUID, variation: Variation) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            entry.performedVariationId = variation.id
            entry.performedVariationNameSnapshot = variation.name
            entry.performedMovementId = variation.movementId
            entry.performedMovementNameSnapshot = movementName(variation.movementId)
        }
        Haptics.medium()
    }

    func addSet(sessionId: UUID, entryId: UUID) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            let previous = entry.sets.sorted { $0.setNumber < $1.setNumber }.last
            let setNumber = (previous?.setNumber ?? 0) + 1
            let now = Date()
            entry.sets.append(
                SetEntry(
                    id: UUID(),
                    setNumber: setNumber,
                    reps: previous?.reps ?? 8,
                    weight: previous?.weight ?? 0,
                    weightUnit: previous?.weightUnit ?? appData.preferredWeightUnit,
                    rpe: previous?.rpe,
                    note: previous?.note,
                    completed: true,
                    usedMachineOverload: previous?.usedMachineOverload ?? false,
                    perSide: previous?.perSide ?? false,
                    createdAt: now,
                    updatedAt: now
                )
            )
            entry.status = .inProgress
        }
        Haptics.light()
    }

    func updateSet(
        sessionId: UUID,
        entryId: UUID,
        setId: UUID,
        reps: Int? = nil,
        weight: Double? = nil,
        usedMachineOverload: Bool? = nil,
        perSide: Bool? = nil
    ) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            guard let index = entry.sets.firstIndex(where: { $0.id == setId }) else { return }
            if let reps {
                entry.sets[index].reps = reps
            }
            if let weight {
                entry.sets[index].weight = weight
            }
            if let usedMachineOverload {
                entry.sets[index].usedMachineOverload = usedMachineOverload
            }
            if let perSide {
                entry.sets[index].perSide = perSide
            }
            entry.sets[index].updatedAt = .now
            entry.status = .inProgress
        }
    }

    func deleteSet(sessionId: UUID, entryId: UUID, setId: UUID) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            entry.sets.removeAll { $0.id == setId }
            for index in entry.sets.indices {
                entry.sets[index].setNumber = index + 1
            }
            entry.status = entry.sets.isEmpty ? .notStarted : .inProgress
        }
    }

    func deleteWorkoutSession(_ sessionId: UUID) {
        appData.workoutSessions.removeAll { $0.id == sessionId }
        if appData.activeWorkoutSessionId == sessionId {
            appData.activeWorkoutSessionId = nil
        }
        if presentedWorkoutSessionID == sessionId {
            presentedWorkoutSessionID = nil
        }
        touch()
        Haptics.medium()
    }

    func discardActiveWorkout(sessionId: UUID) {
        guard appData.workoutSessions.first(where: { $0.id == sessionId })?.status == .active else { return }
        deleteWorkoutSession(sessionId)
    }

    func markExerciseComplete(sessionId: UUID, entryId: UUID) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            entry.status = .completed
        }
        Haptics.success()
    }

    func skipExercise(sessionId: UUID, entryId: UUID) {
        mutateEntry(sessionId: sessionId, entryId: entryId) { entry in
            entry.status = .skipped
        }
        Haptics.medium()
    }

    @discardableResult
    func replaceExercise(
        sessionId: UUID,
        entryId: UUID,
        movementId: UUID,
        variationId: UUID?,
        plannedSetCount: Int?,
        plannedRepRange: RepRange?
    ) -> UUID? {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }),
              let entryIndex = appData.workoutSessions[sessionIndex].exerciseEntries.firstIndex(where: { $0.id == entryId }) else { return nil }

        let session = appData.workoutSessions[sessionIndex]
        let existingEntry = session.exerciseEntries[entryIndex]
        guard let replacementEntry = makeSessionExerciseEntry(
            session: session,
            movementId: movementId,
            variationId: variationId,
            plannedSetCount: plannedSetCount,
            plannedRepRange: plannedRepRange,
            entryId: existingEntry.id,
            orderIndex: existingEntry.orderIndex,
            sourceRegimenItemId: existingEntry.sourceRegimenItemId,
            notes: existingEntry.notes
        ) else { return nil }

        appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex] = replacementEntry
        appData.workoutSessions[sessionIndex].updatedAt = .now
        touch()
        Haptics.medium()
        return replacementEntry.id
    }

    @discardableResult
    func insertExerciseAfter(
        sessionId: UUID,
        afterEntryId: UUID,
        movementId: UUID,
        variationId: UUID?,
        plannedSetCount: Int?,
        plannedRepRange: RepRange?
    ) -> UUID? {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }),
              let entryIndex = appData.workoutSessions[sessionIndex].exerciseEntries.firstIndex(where: { $0.id == afterEntryId }) else { return nil }

        let session = appData.workoutSessions[sessionIndex]
        guard let newEntry = makeSessionExerciseEntry(
            session: session,
            movementId: movementId,
            variationId: variationId,
            plannedSetCount: plannedSetCount,
            plannedRepRange: plannedRepRange,
            entryId: UUID(),
            orderIndex: entryIndex + 1,
            sourceRegimenItemId: nil,
            notes: nil
        ) else { return nil }

        appData.workoutSessions[sessionIndex].exerciseEntries.insert(newEntry, at: entryIndex + 1)
        reindexEntries(in: sessionIndex)
        appData.workoutSessions[sessionIndex].updatedAt = .now
        touch()
        Haptics.light()
        return newEntry.id
    }

    @discardableResult
    func appendExercise(
        sessionId: UUID,
        movementId: UUID,
        variationId: UUID?,
        plannedSetCount: Int?,
        plannedRepRange: RepRange?
    ) -> UUID? {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }) else { return nil }

        let session = appData.workoutSessions[sessionIndex]
        guard let newEntry = makeSessionExerciseEntry(
            session: session,
            movementId: movementId,
            variationId: variationId,
            plannedSetCount: plannedSetCount,
            plannedRepRange: plannedRepRange,
            entryId: UUID(),
            orderIndex: session.exerciseEntries.count,
            sourceRegimenItemId: nil,
            notes: nil
        ) else { return nil }

        appData.workoutSessions[sessionIndex].exerciseEntries.append(newEntry)
        reindexEntries(in: sessionIndex)
        appData.workoutSessions[sessionIndex].updatedAt = .now
        touch()
        Haptics.light()
        return newEntry.id
    }

    func moveExercise(sessionId: UUID, entryId: UUID, toIndex: Int) {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }),
              let sourceIndex = appData.workoutSessions[sessionIndex].exerciseEntries.firstIndex(where: { $0.id == entryId }) else { return }

        let maxIndex = appData.workoutSessions[sessionIndex].exerciseEntries.count
        let clampedIndex = max(0, min(toIndex, maxIndex))
        guard sourceIndex != clampedIndex else { return }

        var entries = appData.workoutSessions[sessionIndex].exerciseEntries
        let movedEntry = entries.remove(at: sourceIndex)
        let adjustedIndex = sourceIndex < clampedIndex ? clampedIndex - 1 : clampedIndex
        entries.insert(movedEntry, at: max(0, min(adjustedIndex, entries.count)))
        appData.workoutSessions[sessionIndex].exerciseEntries = entries
        reindexEntries(in: sessionIndex)
        appData.workoutSessions[sessionIndex].updatedAt = .now
        touch()
        Haptics.light()
    }

    func upsertMovement(
        id: UUID? = nil,
        canonicalName: String,
        aliases: [String] = [],
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup] = [],
        movementPattern: MovementPattern? = nil,
        notes: String?
    ) {
        let now = Date()
        if let id, let index = appData.movements.firstIndex(where: { $0.id == id }) {
            appData.movements[index].canonicalName = canonicalName
            appData.movements[index].aliases = aliases
            appData.movements[index].primaryMuscleGroups = primaryMuscleGroups
            appData.movements[index].secondaryMuscleGroups = secondaryMuscleGroups
            appData.movements[index].movementPattern = movementPattern
            appData.movements[index].notes = notes?.nilIfBlank
            appData.movements[index].updatedAt = now
        } else {
            appData.movements.append(
                Movement(
                    id: UUID(),
                    canonicalName: canonicalName,
                    aliases: aliases,
                    primaryMuscleGroups: primaryMuscleGroups,
                    secondaryMuscleGroups: secondaryMuscleGroups,
                    movementPattern: movementPattern,
                    notes: notes?.nilIfBlank,
                    isArchived: false,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        touch()
    }

    func archiveMovement(_ id: UUID) {
        guard let index = appData.movements.firstIndex(where: { $0.id == id }) else { return }
        appData.movements[index].isArchived = true
        appData.movements[index].updatedAt = .now
        touch()
    }

    func upsertVariation(id: UUID? = nil, movementId: UUID, name: String, equipmentCategory: EquipmentCategory?, notes: String? = nil) {
        let now = Date()
        if let id, let index = appData.variations.firstIndex(where: { $0.id == id }) {
            appData.variations[index].movementId = movementId
            appData.variations[index].name = name
            appData.variations[index].equipmentCategory = equipmentCategory
            appData.variations[index].notes = notes?.nilIfBlank
            appData.variations[index].updatedAt = now
        } else {
            appData.variations.append(Variation(id: UUID(), movementId: movementId, name: name, equipmentCategory: equipmentCategory, notes: notes?.nilIfBlank, isArchived: false, createdAt: now, updatedAt: now))
        }
        touch()
    }

    func archiveVariation(_ id: UUID) {
        guard let index = appData.variations.firstIndex(where: { $0.id == id }) else { return }
        appData.variations[index].isArchived = true
        appData.variations[index].updatedAt = .now
        touch()
    }

    func upsertLocation(id: UUID? = nil, name: String, notes: String?) {
        let now = Date()
        if let id, let index = appData.locations.firstIndex(where: { $0.id == id }) {
            appData.locations[index].name = name
            appData.locations[index].notes = notes?.nilIfBlank
            appData.locations[index].updatedAt = now
        } else {
            appData.locations.append(Location(id: UUID(), name: name, notes: notes?.nilIfBlank, isArchived: false, createdAt: now, updatedAt: now))
        }
        touch()
    }

    func archiveLocation(_ id: UUID) {
        guard let index = appData.locations.firstIndex(where: { $0.id == id }) else { return }
        appData.locations[index].isArchived = true
        appData.locations[index].updatedAt = .now
        touch()
    }

    func setCurrentRegimen(_ regimenId: UUID) {
        for index in appData.regimens.indices {
            appData.regimens[index].isCurrent = appData.regimens[index].id == regimenId
        }
        appData.currentRegimenId = regimenId
        touch()
    }

    func createRegimen(named name: String) {
        let now = Date()
        for index in appData.regimens.indices {
            appData.regimens[index].isCurrent = false
        }
        let regimen = Regimen(id: UUID(), name: name, isCurrent: true, days: [], notes: nil, isArchived: false, createdAt: now, updatedAt: now)
        appData.regimens.append(regimen)
        appData.currentRegimenId = regimen.id
        touch()
    }

    func updateRegimen(id: UUID, name: String, notes: String?) {
        guard let index = appData.regimens.firstIndex(where: { $0.id == id }) else { return }
        appData.regimens[index].name = name
        appData.regimens[index].notes = notes?.nilIfBlank
        appData.regimens[index].updatedAt = .now
        touch()
    }

    func updateRegimenDay(regimenId: UUID, dayId: UUID, name: String, notes: String?) {
        guard let regimenIndex = appData.regimens.firstIndex(where: { $0.id == regimenId }),
              let dayIndex = appData.regimens[regimenIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        appData.regimens[regimenIndex].days[dayIndex].name = name
        appData.regimens[regimenIndex].days[dayIndex].notes = notes?.nilIfBlank
        appData.regimens[regimenIndex].updatedAt = .now
        touch()
    }

    func archiveRegimen(_ id: UUID) {
        guard let index = appData.regimens.firstIndex(where: { $0.id == id }),
              appData.regimens[index].id != currentRegimen?.id else { return }
        appData.regimens[index].isArchived = true
        appData.regimens[index].isCurrent = false
        appData.regimens[index].updatedAt = .now
        touch()
    }

    func restoreRegimen(_ id: UUID) {
        guard let index = appData.regimens.firstIndex(where: { $0.id == id }) else { return }
        appData.regimens[index].isArchived = false
        appData.regimens[index].updatedAt = .now
        touch()
    }

    func addDay(to regimenId: UUID, name: String) {
        guard let regimenIndex = appData.regimens.firstIndex(where: { $0.id == regimenId }) else { return }
        let nextIndex = appData.regimens[regimenIndex].days.count
        appData.regimens[regimenIndex].days.append(RegimenDay(id: UUID(), name: name, orderIndex: nextIndex, items: [], notes: nil))
        appData.regimens[regimenIndex].updatedAt = .now
        touch()
    }

    func addRegimenItem(to regimenId: UUID, dayId: UUID, movementId: UUID, defaultVariationId: UUID?, plannedSetCount: Int? = 3, plannedRepRange: RepRange? = RepRange(min: 8, max: 12)) {
        guard let regimenIndex = appData.regimens.firstIndex(where: { $0.id == regimenId }),
              let dayIndex = appData.regimens[regimenIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        let nextIndex = appData.regimens[regimenIndex].days[dayIndex].items.count
        appData.regimens[regimenIndex].days[dayIndex].items.append(
            RegimenItem(
                id: UUID(),
                orderIndex: nextIndex,
                movementId: movementId,
                defaultVariationId: defaultVariationId,
                plannedSetCount: plannedSetCount,
                plannedRepRange: plannedRepRange,
                notes: nil
            )
        )
        appData.regimens[regimenIndex].updatedAt = .now
        touch()
    }

    func updateRegimenItem(regimenId: UUID, dayId: UUID, itemId: UUID, defaultVariationId: UUID?, plannedSetCount: Int?, plannedRepRange: RepRange?, notes: String?) {
        guard let regimenIndex = appData.regimens.firstIndex(where: { $0.id == regimenId }),
              let dayIndex = appData.regimens[regimenIndex].days.firstIndex(where: { $0.id == dayId }),
              let itemIndex = appData.regimens[regimenIndex].days[dayIndex].items.firstIndex(where: { $0.id == itemId }) else { return }

        let oldItem = appData.regimens[regimenIndex].days[dayIndex].items[itemIndex]
        let oldResolvedVariation = WorkoutSessionFactory.resolvedVariation(for: oldItem, variations: appData.variations)

        appData.regimens[regimenIndex].days[dayIndex].items[itemIndex].defaultVariationId = defaultVariationId
        appData.regimens[regimenIndex].days[dayIndex].items[itemIndex].plannedSetCount = plannedSetCount
        appData.regimens[regimenIndex].days[dayIndex].items[itemIndex].plannedRepRange = plannedRepRange
        appData.regimens[regimenIndex].days[dayIndex].items[itemIndex].notes = notes?.nilIfBlank

        let newItem = appData.regimens[regimenIndex].days[dayIndex].items[itemIndex]
        let newResolvedVariation = WorkoutSessionFactory.resolvedVariation(for: newItem, variations: appData.variations)
        syncActiveWorkoutEntriesFromRegimenItem(
            itemId: itemId,
            newItem: newItem,
            oldResolvedVariation: oldResolvedVariation,
            newResolvedVariation: newResolvedVariation
        )

        appData.regimens[regimenIndex].updatedAt = .now
        touch()
    }

    func exportDocument() -> BackupDocument {
        BackupDocument(appData: appData)
    }

    func exportFilename() -> String {
        persistence.exportFilename()
    }

    func importBackup(from url: URL) {
        do {
            let imported = try persistence.importData(from: url)
            appData = imported
            save()
            Haptics.success()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func syncActiveWorkoutEntriesFromRegimenItem(
        itemId: UUID,
        newItem: RegimenItem,
        oldResolvedVariation: Variation?,
        newResolvedVariation: Variation?
    ) {
        let now = Date()
        for sessionIndex in appData.workoutSessions.indices {
            guard appData.workoutSessions[sessionIndex].status == .active else { continue }
            var sessionUpdated = false
            for entryIndex in appData.workoutSessions[sessionIndex].exerciseEntries.indices {
                guard appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].sourceRegimenItemId == itemId else { continue }
                sessionUpdated = true
                appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].plannedSetCount = newItem.plannedSetCount
                appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].plannedRepRange = newItem.plannedRepRange
                appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].notes = newItem.notes
                appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].plannedVariationId = newItem.defaultVariationId
                appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].plannedVariationNameSnapshot = newResolvedVariation?.name

                if let oldResolvedVariation, let newResolvedVariation,
                   appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].performedVariationId == oldResolvedVariation.id {
                    appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].performedVariationId = newResolvedVariation.id
                    appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].performedVariationNameSnapshot = newResolvedVariation.name
                    appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].performedMovementId = newResolvedVariation.movementId
                    appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex].performedMovementNameSnapshot = movementName(newResolvedVariation.movementId)
                }
            }
            if sessionUpdated {
                appData.workoutSessions[sessionIndex].updatedAt = now
            }
        }
    }

    private func mutateEntry(sessionId: UUID, entryId: UUID, mutate: (inout WorkoutExerciseEntry) -> Void) {
        guard let sessionIndex = appData.workoutSessions.firstIndex(where: { $0.id == sessionId }),
              let entryIndex = appData.workoutSessions[sessionIndex].exerciseEntries.firstIndex(where: { $0.id == entryId }) else { return }
        mutate(&appData.workoutSessions[sessionIndex].exerciseEntries[entryIndex])
        appData.workoutSessions[sessionIndex].updatedAt = .now
        touch()
    }

    private func makeSessionExerciseEntry(
        session: WorkoutSession,
        movementId: UUID,
        variationId: UUID?,
        plannedSetCount: Int?,
        plannedRepRange: RepRange?,
        entryId: UUID,
        orderIndex: Int,
        sourceRegimenItemId: UUID?,
        notes: String?
    ) -> WorkoutExerciseEntry? {
        guard let movement = movement(for: movementId) else { return nil }
        let variation = appData.variations.first(where: { $0.id == variationId })

        return WorkoutExerciseEntry(
            id: entryId,
            orderIndex: orderIndex,
            sourceRegimenItemId: sourceRegimenItemId,
            plannedMovementId: movement.id,
            plannedMovementNameSnapshot: movement.canonicalName,
            plannedVariationId: variation?.id,
            plannedVariationNameSnapshot: variation?.name,
            plannedSetCount: plannedSetCount,
            plannedRepRange: plannedRepRange,
            performedMovementId: movement.id,
            performedMovementNameSnapshot: movement.canonicalName,
            performedVariationId: variation?.id ?? UUID(),
            performedVariationNameSnapshot: variation?.name ?? "Select Variation",
            status: .notStarted,
            viewedHistoryLocationId: session.locationId,
            viewedHistoryLocationNameSnapshot: session.locationNameSnapshot,
            sets: [],
            notes: notes
        )
    }

    private func reindexEntries(in sessionIndex: Int) {
        for index in appData.workoutSessions[sessionIndex].exerciseEntries.indices {
            appData.workoutSessions[sessionIndex].exerciseEntries[index].orderIndex = index
        }
    }

    private func workoutEntry(sessionId: UUID, entryId: UUID) -> WorkoutExerciseEntry? {
        appData.workoutSessions.first(where: { $0.id == sessionId })?.exerciseEntries.first(where: { $0.id == entryId })
    }

    private func touch() {
        appData.updatedAt = .now
        save()
    }

    private func save() {
        do {
            try persistence.save(appData)
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmed.isEmpty ? nil : trimmed
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSearchText: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
