extension ProgramCatalog {
  static let bundled = ProgramCatalog(programs: [
    TrainingProgram(
      id: "full-body",
      name: "Full Body",
      trainingDaysPerWeek: 3,
      format: "A / B / C",
      emphasis: "Frequent whole-body practice with broad hypertrophy coverage.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Workout A — Vertical Pull + Upper Chest", movements: ["Weighted Chin-Up", "Incline Smith-Machine Press", "Leg Press", "Seated Leg Curl", "Machine Lateral Raise", "Barbell Curl", "Cable Triceps Pressdown"]),
        WorkoutTemplate(name: "Workout B — Horizontal Pull + Chest", movements: ["Smith-Machine Barbell Row", "Weighted Dip", "Hack Squat Machine", "Romanian Deadlift", "Reverse Pec Deck", "Incline Dumbbell Curl", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Workout C — Shoulder Girdle + Balanced Lower Body", movements: ["Machine Shoulder Press", "Neutral-Grip Lat Pulldown", "Leg Extension", "Lying Leg Curl", "Machine Chest Press", "Dumbbell Shrug", "Cable Crunch"])
      ]
    ),
    TrainingProgram(
      id: "upper-lower",
      name: "Upper / Lower",
      trainingDaysPerWeek: 4,
      format: "Upper A / Lower A / Upper B / Lower B",
      emphasis: "Shorter sessions with more recovery between upper- and lower-body work.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Upper A", movements: ["Weighted Chin-Up", "Incline Smith-Machine Press", "Chest-Supported Machine Row", "Machine Lateral Raise", "Barbell Curl", "Cable Triceps Pressdown"]),
        WorkoutTemplate(name: "Lower A", movements: ["Hack Squat Machine", "Romanian Deadlift", "Leg Extension", "Seated Leg Curl", "Cable Crunch"]),
        WorkoutTemplate(name: "Upper B", movements: ["Weighted Dip", "Smith-Machine Barbell Row", "Machine Shoulder Press", "Neutral-Grip Lat Pulldown", "Incline Dumbbell Curl", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Lower B", movements: ["Leg Press", "45-Degree Back Extension", "Bulgarian Split Squat", "Lying Leg Curl", "Hanging Knee Raise"])
      ]
    ),
    TrainingProgram(
      id: "push-pull-legs",
      name: "Push / Pull / Legs",
      trainingDaysPerWeek: 3,
      format: "Push / Pull / Legs",
      emphasis: "Classic movement-based training, with each major muscle group trained hard once per week.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Push", movements: ["Incline Smith-Machine Press", "Weighted Dip", "Machine Shoulder Press", "Machine Lateral Raise", "Cable Triceps Pressdown", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Pull", movements: ["Weighted Chin-Up", "Smith-Machine Barbell Row", "Neutral-Grip Lat Pulldown", "Reverse Pec Deck", "Dumbbell Shrug", "Barbell Curl", "Hammer Curl"]),
        WorkoutTemplate(name: "Legs", movements: ["Hack Squat Machine", "Romanian Deadlift", "Leg Press", "Seated Leg Curl", "Leg Extension", "Cable Crunch"])
      ]
    ),
    TrainingProgram(
      id: "bro-split",
      name: "Bro Split",
      trainingDaysPerWeek: 5,
      format: "Chest / Back / Legs / Shoulders / Arms",
      emphasis: "Concentrated body-part sessions with very low per-exercise set counts.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Day 1 — Chest", movements: ["Incline Smith-Machine Press", "Weighted Dip", "Machine Chest Press", "Pec Deck"]),
        WorkoutTemplate(name: "Day 2 — Back", movements: ["Weighted Chin-Up", "Smith-Machine Barbell Row", "Chest-Supported Machine Row", "Neutral-Grip Lat Pulldown", "Dumbbell Shrug"]),
        WorkoutTemplate(name: "Day 3 — Legs", movements: ["Hack Squat Machine", "Romanian Deadlift", "Leg Press", "Seated Leg Curl", "Leg Extension"]),
        WorkoutTemplate(name: "Day 4 — Shoulders", movements: ["Machine Shoulder Press", "Machine Lateral Raise", "Cable Lateral Raise", "Reverse Pec Deck", "Dumbbell Shrug"]),
        WorkoutTemplate(name: "Day 5 — Arms", movements: ["Barbell Curl", "Close-Grip Smith-Machine Bench Press", "Incline Dumbbell Curl", "Overhead Cable Triceps Extension", "Hammer Curl", "Cable Triceps Pressdown"])
      ]
    ),
    TrainingProgram(
      id: "minimalist-full-body",
      name: "Minimalist Full Body",
      trainingDaysPerWeek: 2,
      format: "A / B",
      emphasis: "The smallest practical weekly gym commitment while training major muscle groups hard.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Workout A", movements: ["Leg Press", "Weighted Chin-Up", "Incline Smith-Machine Press", "Seated Leg Curl", "Machine Lateral Raise", "Barbell Curl"]),
        WorkoutTemplate(name: "Workout B", movements: ["Hack Squat Machine", "Smith-Machine Barbell Row", "Weighted Dip", "Romanian Deadlift", "Reverse Pec Deck", "Overhead Cable Triceps Extension"])
      ]
    ),
    TrainingProgram(
      id: "v-taper",
      name: "V-Taper",
      trainingDaysPerWeek: 3,
      format: "Lats + Upper Chest / Lower Body + Delts / Back + Shoulder Width",
      emphasis: "Build shoulder-to-waist contrast through lat width, lateral delts, upper chest, and balanced lower-body work.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Day 1 — Lats + Upper Chest", movements: ["Weighted Chin-Up", "Incline Smith-Machine Press", "Neutral-Grip Lat Pulldown", "Machine Lateral Raise", "Incline Dumbbell Curl", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Day 2 — Lower Body + Delts", movements: ["Hack Squat Machine", "Romanian Deadlift", "Seated Leg Curl", "Machine Shoulder Press", "Cable Lateral Raise", "Cable Crunch"]),
        WorkoutTemplate(name: "Day 3 — Back Width + Shoulder Width", movements: ["Neutral-Grip Lat Pulldown", "Chest-Supported Machine Row", "Machine Lateral Raise", "Incline Machine Chest Press", "Reverse Pec Deck", "Barbell Curl", "Cable Triceps Pressdown"])
      ]
    ),
    TrainingProgram(
      id: "powerhouse",
      name: "Powerhouse",
      trainingDaysPerWeek: 3,
      format: "Torso + Arms / Thighs + Posterior Chain / Upper Back + Shoulder Girdle",
      emphasis: "Whole-body muscular density, especially torso, upper back, arms, thighs, and posterior chain.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Day 1 — Torso Density + Arms", movements: ["Smith-Machine Barbell Row", "Weighted Dip", "Weighted Chin-Up", "Machine Shoulder Press", "Barbell Curl", "Cable Triceps Pressdown", "Dumbbell Wrist Curl"]),
        WorkoutTemplate(name: "Day 2 — Thighs + Posterior Chain + Traps", movements: ["Hack Squat Machine", "Romanian Deadlift", "Leg Press", "Seated Leg Curl", "Dumbbell Shrug", "Machine Neck Extension", "Cable Crunch"]),
        WorkoutTemplate(name: "Day 3 — Upper Back + Shoulder Girdle + Traps", movements: ["Chest-Supported Machine Row", "Neutral-Grip Lat Pulldown", "Incline Smith-Machine Press", "Reverse Pec Deck", "Hammer Curl", "Machine Neck Flexion", "Dumbbell Shrug"])
      ]
    ),
    TrainingProgram(
      id: "classic-physique",
      name: "Classic Physique",
      trainingDaysPerWeek: 3,
      format: "Upper Chest + Back Width / Legs + Torso / Delts + Balanced Upper Body",
      emphasis: "Balanced proportions with broad shoulders, upper chest, lat width, proportional arms, and athletic legs.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Day 1 — Upper Chest + Back Width", movements: ["Incline Smith-Machine Press", "Weighted Chin-Up", "Machine Lateral Raise", "Chest-Supported Machine Row", "Barbell Curl", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Day 2 — Legs + Torso", movements: ["Hack Squat Machine", "Romanian Deadlift", "Leg Extension", "Seated Leg Curl", "Hanging Knee Raise", "45-Degree Back Extension"]),
        WorkoutTemplate(name: "Day 3 — Delts + Balanced Upper Body", movements: ["Machine Shoulder Press", "Neutral-Grip Lat Pulldown", "Weighted Dip", "Cable Lateral Raise", "Reverse Pec Deck", "Incline Dumbbell Curl", "Cable Triceps Pressdown"])
      ]
    ),
    TrainingProgram(
      id: "free-weight-full-body",
      name: "Free-Weight Full Body",
      trainingDaysPerWeek: 3,
      format: "A / B / C",
      emphasis: "Barbells, dumbbells, and bodyweight loading for gyms with limited machines or lifters who prefer free weights.",
      symbol: "dumbbell",
      workouts: [
        WorkoutTemplate(name: "Workout A", movements: ["Front Squat", "Weighted Chin-Up", "Incline Dumbbell Press", "Romanian Deadlift", "Dumbbell Lateral Raise", "Barbell Curl"]),
        WorkoutTemplate(name: "Workout B", movements: ["Conventional Deadlift", "Weighted Dip", "Barbell Row", "Bulgarian Split Squat", "Dumbbell Rear-Delt Raise", "Dumbbell Overhead Triceps Extension"]),
        WorkoutTemplate(name: "Workout C", movements: ["Goblet Squat", "One-Arm Dumbbell Row", "Standing Dumbbell Shoulder Press", "Dumbbell Romanian Deadlift", "Dumbbell Lateral Raise", "Hammer Curl"])
      ]
    ),
    TrainingProgram(
      id: "machine-full-body",
      name: "Machine Full Body",
      trainingDaysPerWeek: 3,
      format: "A / B / C",
      emphasis: "Maximum stability, simple progression, and a low-skill environment for high-effort training.",
      symbol: "figure.strengthtraining.traditional",
      workouts: [
        WorkoutTemplate(name: "Workout A", movements: ["Hack Squat Machine", "Machine Chest Press", "Neutral-Grip Lat Pulldown", "Seated Leg Curl", "Machine Lateral Raise", "Machine Preacher Curl", "Cable Triceps Pressdown"]),
        WorkoutTemplate(name: "Workout B", movements: ["Leg Press", "Chest-Supported Machine Row", "Incline Machine Chest Press", "Lying Leg Curl", "Reverse Pec Deck", "Cable Curl", "Overhead Cable Triceps Extension"]),
        WorkoutTemplate(name: "Workout C", movements: ["Leg Extension", "Machine Shoulder Press", "Wide-Grip Lat Pulldown", "Seated Leg Curl", "Pec Deck", "Machine Lateral Raise", "Machine Preacher Curl", "Cable Triceps Pressdown"])
      ]
    )
  ])
}
