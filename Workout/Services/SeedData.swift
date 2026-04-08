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
            variationNames: [String]? = nil,
            variations variationSpecs: [(name: String, equipment: EquipmentCategory?)]? = nil
        ) {
            let movement = Movement(
                id: UUID(),
                canonicalName: canonicalName,
                aliases: aliases,
                primaryMuscleGroups: primary,
                secondaryMuscleGroups: secondary,
                movementPattern: pattern,
                notes: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
            movements.append(movement)

            let resolvedVariations = variationSpecs ?? (variationNames ?? [canonicalName]).map { (name: $0, equipment: equipment) }
            for variation in resolvedVariations {
                variations.append(
                    Variation(
                        id: UUID(),
                        movementId: movement.id,
                        name: variation.name,
                        equipmentCategory: variation.equipment,
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
        addMovement(
            "Leg Curl",
            aliases: ["Hamstring Curl", "Seated Leg Curl", "Lying Leg Curl"],
            primary: [.hamstrings],
            equipment: .machine,
            pattern: .curl,
            variationNames: ["Seated Leg Curl", "Lying Leg Curl"]
        )
        addMovement("Back Extension", primary: [.spinalErectors, .glutes], secondary: [.hamstrings], equipment: .machine, pattern: .hinge)
        addMovement("Hip Adduction", primary: [.adductors], equipment: .machine, pattern: .adduction)
        addMovement("Hip Abduction", primary: [.abductors, .glutes], equipment: .machine, pattern: .abduction)
        addMovement("Standing Calf Raise", aliases: ["Calf Raise", "Calf Raises"], primary: [.calves], equipment: .machine, pattern: .calfRaise)
        addMovement("Seated Calf Raise", primary: [.calves], equipment: .machine, pattern: .calfRaise)

        addMovement("Bench Press", aliases: ["Dumbbell Bench Press", "DB Bench", "Flat DB Bench"], primary: [.chest], secondary: [.frontDelts, .triceps], equipment: .dumbbell, pattern: .horizontalPress, variationNames: ["Flat Dumbbell Bench Press"])
        addMovement("Incline Press", aliases: ["Incline Dumbbell Press"], primary: [.upperChest, .chest], secondary: [.frontDelts, .triceps], equipment: .dumbbell, pattern: .horizontalPress, variationNames: ["Incline Dumbbell Press"])
        addMovement(
            "Chest Fly",
            aliases: ["Pec Deck Fly", "Pec Fly", "Machine Fly", "Cable Fly"],
            primary: [.chest],
            secondary: [.frontDelts],
            pattern: .fly,
            variations: [
                (name: "Pec Deck Fly", equipment: .machine),
                (name: "Cable Fly", equipment: .cable)
            ]
        )
        addMovement("Chest Press", aliases: ["Chest Press Machine"], primary: [.chest], secondary: [.frontDelts, .triceps], equipment: .machine, pattern: .horizontalPress, variationNames: ["Chest Press Machine"])

        addMovement("Seated Overhead Press", aliases: ["Military Press", "Shoulder Press"], primary: [.frontDelts, .sideDelts], secondary: [.triceps], equipment: .dumbbell, pattern: .verticalPress)
        addMovement("Lateral Raise", aliases: ["Dumbbell Lateral Raise"], primary: [.sideDelts], equipment: .dumbbell, pattern: .raise, variationNames: ["Dumbbell Lateral Raise"])
        addMovement("Rear Delt Fly", aliases: ["Reverse Fly"], primary: [.rearDelts], secondary: [.upperBack], equipment: .dumbbell, pattern: .fly)
        addMovement("Face Pull", aliases: ["Face Pulls"], primary: [.rearDelts, .upperBack], secondary: [.traps], equipment: .cable, pattern: .horizontalRow)
        addMovement("Y Raise", aliases: ["Cable Y Raise"], primary: [.sideDelts, .rearDelts], secondary: [.traps], equipment: .cable, pattern: .raise, variationNames: ["Cable Y Raise"])

        addMovement("Overhead Triceps Extension", aliases: ["Tricep Extension", "OH Tricep Extension"], primary: [.triceps], equipment: .cable, pattern: .extensionMovement)
        addMovement("Pressdown", aliases: ["Cable Pressdown"], primary: [.triceps], equipment: .cable, pattern: .extensionMovement, variationNames: ["Rope Pressdown"])
        addMovement("Dip", primary: [.triceps, .chest], secondary: [.frontDelts], equipment: .bodyweight, pattern: .horizontalPress)
        addMovement("Skullcrusher", primary: [.triceps], equipment: .barbell, pattern: .extensionMovement)

        addMovement("Lat Pulldown", primary: [.lats], secondary: [.biceps, .upperBack], equipment: .cable, pattern: .verticalPull)
        addMovement("Pull-Up", aliases: ["Pull Ups", "Pullup"], primary: [.lats], secondary: [.biceps, .upperBack], equipment: .bodyweight, pattern: .verticalPull)
        addMovement("Chest-Supported Wide Row", aliases: ["Wide Row"], primary: [.upperBack, .midBack], secondary: [.rearDelts, .biceps], equipment: .plateLoaded, pattern: .horizontalRow)
        addMovement("Chest-Supported Neutral-Grip Row", aliases: ["Narrow Row", "Neutral Row"], primary: [.lats, .midBack], secondary: [.biceps, .rearDelts], equipment: .plateLoaded, pattern: .horizontalRow)
        addMovement("Single-Arm Row", aliases: ["Single-Arm Cable Row"], primary: [.lats, .midBack], secondary: [.biceps], equipment: .cable, pattern: .horizontalRow, variationNames: ["Single-Arm Cable Row"])
        addMovement("Straight-Arm Pulldown", primary: [.lats], equipment: .cable, pattern: .verticalPull)
        addMovement("Row", aliases: ["T-Bar Row"], primary: [.upperBack, .midBack], secondary: [.lats, .biceps], equipment: .plateLoaded, pattern: .horizontalRow, variationNames: ["T-Bar Row"])

        addMovement("Spider Curl", primary: [.biceps], equipment: .dumbbell, pattern: .curl)
        addMovement("Hammer Curl", primary: [.biceps], secondary: [.forearms], equipment: .dumbbell, pattern: .curl)
        addMovement("Incline Curl", aliases: ["Incline Dumbbell Curl"], primary: [.biceps], equipment: .dumbbell, pattern: .curl, variationNames: ["Incline Dumbbell Curl"])
        addMovement("Preacher Curl", primary: [.biceps], equipment: .machine, pattern: .curl)
        addMovement("Curl", aliases: ["Cable Curl"], primary: [.biceps], equipment: .cable, pattern: .curl, variationNames: ["Cable Curl"])

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
