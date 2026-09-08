import Foundation

extension WorkoutStore {
    public static let exerciseLibrary: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Bench press", category: "Chest", reps: 8, restSeconds: 120),
        ExerciseTemplate(name: "Dumbbell press", category: "Chest", reps: 10),
        ExerciseTemplate(name: "Incline dumbbell press", category: "Chest", reps: 10),
        ExerciseTemplate(name: "Push-up", category: "Chest", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Cable fly", category: "Chest", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Lat pulldown", category: "Back", reps: 10),
        ExerciseTemplate(name: "Seated cable row", category: "Back", reps: 10),
        ExerciseTemplate(name: "Dumbbell row", category: "Back", reps: 10),
        ExerciseTemplate(name: "Pull-up", category: "Back", reps: 6, restSeconds: 120),
        ExerciseTemplate(name: "Deadlift", category: "Back", reps: 5, restSeconds: 180),
        ExerciseTemplate(name: "Overhead press", category: "Shoulders", reps: 8, restSeconds: 120),
        ExerciseTemplate(name: "Lateral raise", category: "Shoulders", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Face pull", category: "Shoulders", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Biceps curl", category: "Arms", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Hammer curl", category: "Arms", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Triceps pushdown", category: "Arms", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Back squat", category: "Legs", reps: 8, restSeconds: 150),
        ExerciseTemplate(name: "Goblet squat", category: "Legs", reps: 10),
        ExerciseTemplate(name: "Romanian deadlift", category: "Legs", reps: 10, restSeconds: 120),
        ExerciseTemplate(name: "Leg press", category: "Legs", reps: 10, restSeconds: 120),
        ExerciseTemplate(name: "Walking lunge", category: "Legs", reps: 12),
        ExerciseTemplate(name: "Leg curl", category: "Legs", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Leg extension", category: "Legs", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Calf raise", category: "Legs", reps: 15, restSeconds: 60),
        ExerciseTemplate(name: "Hip thrust", category: "Glutes", reps: 10, restSeconds: 120),
        ExerciseTemplate(name: "Glute bridge", category: "Glutes", reps: 15, restSeconds: 60),
        ExerciseTemplate(name: "Cable crunch", category: "Core", reps: 15, restSeconds: 60),
        ExerciseTemplate(name: "Hanging knee raise", category: "Core", reps: 12, restSeconds: 60),
        ExerciseTemplate(name: "Dead bug", category: "Core", reps: 10, restSeconds: 45),
        ExerciseTemplate(name: "Russian twist", category: "Core", reps: 20, restSeconds: 60)
    ]

    public static let starterRoutines: [Routine] = [
        Routine(name: "Upper body", subtitle: "Push, pull, feel powerful", symbol: "figure.strengthtraining.traditional", exercises: [
            exerciseLibrary[0], exerciseLibrary[5], exerciseLibrary[10], exerciseLibrary[13], exerciseLibrary[15]
        ]),
        Routine(name: "Lower body", subtitle: "Build from the ground up", symbol: "figure.strengthtraining.functional", exercises: [
            exerciseLibrary[16], exerciseLibrary[18], exerciseLibrary[21], exerciseLibrary[23]
        ]),
        Routine(name: "Full body", subtitle: "A little of everything", symbol: "bolt.heart.fill", exercises: [
            exerciseLibrary[17], exerciseLibrary[1], exerciseLibrary[7], exerciseLibrary[24], exerciseLibrary[28]
        ])
    ]
}
