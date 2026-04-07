import Foundation

enum SeedData {
    static func make(now: Date = .now) -> AppData {
        var movements: [Movement] = []
        var variations: [Variation] = []

        func addMovement(
            _ canonicalName: String,
            aliases: [String] = [],
            primary: [MuscleGroup],
            secondary: [MuscleGroup] = [],
            equipment: EquipmentCategory? = nil,
            pattern: MovementPattern? = nil,
            variationNames: [String]? = nil
        ) {
            let movement = Movement(
                id: UUID(),
                canonicalName: canonicalName,
                aliases: aliases,
                primaryMuscleGroups: primary,
                secondaryMuscleGroups: secondary,
                equipmentCategory: equipment,
                movementPattern: pattern,
                notes: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
            movements.append(movement)

            for variationName in variationNames ?? [canonicalName] {
                variations.append(
                    Variation(
                        id: UUID(),
                        movementId: movement.id,
                        name: variationName,
                        equipmentCategory: equipment,
                        notes: nil,
                        isArchived: false,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
        }

        addMovement("Back Squat", primary: [.quadriceps, .glutes], secondary: [.hamstrings, .spinalErectors], equipment: .barbell, pattern: .squat)
        addMovement("Hack Squat", primary: [.quadriceps], secondary: [.glutes], equipment: .machine, pattern: .squat)
        addMovement("Leg Press", primary: [.quadriceps, .glutes], secondary: [.hamstrings], equipment: .machine, pattern: .squat)
        addMovement("Bulgarian Split Squat", primary: [.quadriceps, .glutes], secondary: [.hamstrings], equipment: .dumbbell, pattern: .squat)
        addMovement("Walking Lunge", primary: [.quadriceps, .glutes], secondary: [.hamstrings], equipment: .dumbbell, pattern: .squat)
        addMovement("Leg Extension", primary: [.quadriceps], equipment: .machine, pattern: .extensionMovement)
        addMovement("Romanian Deadlift", aliases: ["RDL"], primary: [.hamstrings, .glutes], secondary: [.spinalErectors], equipment: .barbell, pattern: .hinge)
        addMovement("Seated Leg Curl", aliases: ["Leg Curl", "Hamstring Curl"], primary: [.hamstrings], equipment: .machine, pattern: .curl)
        addMovement("Lying Leg Curl", primary: [.hamstrings], equipment: .machine, pattern: .curl)
        addMovement("Back Extension", primary: [.spinalErectors, .glutes], secondary: [.hamstrings], equipment: .machine, pattern: .hinge)
        addMovement("Hip Adduction", primary: [.adductors], equipment: .machine, pattern: .adduction)
        addMovement("Hip Abduction", primary: [.abductors, .glutes], equipment: .machine, pattern: .abduction)
        addMovement("Standing Calf Raise", aliases: ["Calf Raise", "Calf Raises"], primary: [.calves], equipment: .machine, pattern: .calfRaise)
        addMovement("Seated Calf Raise", primary: [.calves], equipment: .machine, pattern: .calfRaise)

        addMovement("Dumbbell Bench Press", aliases: ["DB Bench", "Flat DB Bench"], primary: [.chest], secondary: [.frontDelts, .triceps], equipment: .dumbbell, pattern: .horizontalPress, variationNames: ["Flat Dumbbell Bench Press"])
        addMovement("Incline Dumbbell Press", primary: [.upperChest, .chest], secondary: [.frontDelts, .triceps], equipment: .dumbbell, pattern: .horizontalPress)
        addMovement("Pec Deck Fly", aliases: ["Pec Fly", "Machine Fly"], primary: [.chest], secondary: [.frontDelts], equipment: .machine, pattern: .fly)
        addMovement("Cable Fly", primary: [.chest], equipment: .cable, pattern: .fly)
        addMovement("Chest Press Machine", primary: [.chest], secondary: [.frontDelts, .triceps], equipment: .machine, pattern: .horizontalPress)

        addMovement("Seated Overhead Press", aliases: ["Military Press", "Shoulder Press"], primary: [.frontDelts, .sideDelts], secondary: [.triceps], equipment: .dumbbell, pattern: .verticalPress)
        addMovement("Dumbbell Lateral Raise", primary: [.sideDelts], equipment: .dumbbell, pattern: .raise)
        addMovement("Rear Delt Fly", aliases: ["Reverse Fly"], primary: [.rearDelts], secondary: [.upperBack], equipment: .dumbbell, pattern: .fly)
        addMovement("Face Pull", aliases: ["Face Pulls"], primary: [.rearDelts, .upperBack], secondary: [.traps], equipment: .cable, pattern: .horizontalRow)
        addMovement("Cable Y Raise", primary: [.sideDelts, .rearDelts], secondary: [.traps], equipment: .cable, pattern: .raise)

        addMovement("Overhead Triceps Extension", aliases: ["Tricep Extension", "OH Tricep Extension"], primary: [.triceps], equipment: .cable, pattern: .extensionMovement)
        addMovement("Cable Pressdown", primary: [.triceps], equipment: .cable, pattern: .extensionMovement, variationNames: ["Rope Pressdown"])
        addMovement("Dip", primary: [.triceps, .chest], secondary: [.frontDelts], equipment: .bodyweight, pattern: .horizontalPress)
        addMovement("Skullcrusher", primary: [.triceps], equipment: .barbell, pattern: .extensionMovement)

        addMovement("Lat Pulldown", primary: [.lats], secondary: [.biceps, .upperBack], equipment: .cable, pattern: .verticalPull)
        addMovement("Pull-Up", aliases: ["Pull Ups", "Pullup"], primary: [.lats], secondary: [.biceps, .upperBack], equipment: .bodyweight, pattern: .verticalPull)
        addMovement("Chest-Supported Wide Row", aliases: ["Wide Row"], primary: [.upperBack, .midBack], secondary: [.rearDelts, .biceps], equipment: .plateLoaded, pattern: .horizontalRow)
        addMovement("Chest-Supported Neutral-Grip Row", aliases: ["Narrow Row", "Neutral Row"], primary: [.lats, .midBack], secondary: [.biceps, .rearDelts], equipment: .plateLoaded, pattern: .horizontalRow)
        addMovement("Single-Arm Cable Row", primary: [.lats, .midBack], secondary: [.biceps], equipment: .cable, pattern: .horizontalRow)
        addMovement("Straight-Arm Pulldown", primary: [.lats], equipment: .cable, pattern: .verticalPull)
        addMovement("T-Bar Row", primary: [.upperBack, .midBack], secondary: [.lats, .biceps], equipment: .plateLoaded, pattern: .horizontalRow)

        addMovement("Spider Curl", primary: [.biceps], equipment: .dumbbell, pattern: .curl)
        addMovement("Hammer Curl", primary: [.biceps], secondary: [.forearms], equipment: .dumbbell, pattern: .curl)
        addMovement("Incline Dumbbell Curl", primary: [.biceps], equipment: .dumbbell, pattern: .curl)
        addMovement("Preacher Curl", primary: [.biceps], equipment: .machine, pattern: .curl)
        addMovement("Cable Curl", primary: [.biceps], equipment: .cable, pattern: .curl)

        return AppData(
            schemaVersion: AppData.currentSchemaVersion,
            currentRegimenId: nil,
            activeWorkoutSessionId: nil,
            preferredWeightUnit: .pounds,
            movements: movements,
            variations: variations,
            locations: [],
            regimens: [],
            workoutSessions: [],
            createdAt: now,
            updatedAt: now
        )
    }
}
