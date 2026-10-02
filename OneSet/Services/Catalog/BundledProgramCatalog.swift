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
        WorkoutTemplate(
          name: "Workout A — Vertical Pull + Upper Chest",
          exercises: [
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout B — Horizontal Pull + Chest",
          exercises: [
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout C — Shoulder Girdle + Balanced Lower Body",
          exercises: [
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        )
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
        WorkoutTemplate(
          name: "Upper A",
          exercises: [
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Lower A",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Upper B",
          exercises: [
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Lower B",
          exercises: [
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "45-Degree Back Extension", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Bulgarian Split Squat", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachLeg)),
            WorkoutExercise(name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Hanging Knee Raise", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        )
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
        WorkoutTemplate(
          name: "Push",
          exercises: [
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Pull",
          exercises: [
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Legs",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        )
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
        WorkoutTemplate(
          name: "Day 1 — Chest",
          exercises: [
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Pec Deck", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 2 — Back",
          exercises: [
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 3 — Legs",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 4 — Shoulders",
          exercises: [
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 5 — Arms",
          exercises: [
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Close-Grip Smith-Machine Bench Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
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
        WorkoutTemplate(
          name: "Workout A",
          exercises: [
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout B",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        )
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
        WorkoutTemplate(
          name: "Day 1 — Lats + Upper Chest",
          exercises: [
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 2 — Lower Body + Delts",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 3 — Back Width + Shoulder Width",
          exercises: [
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Incline Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
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
        WorkoutTemplate(
          name: "Day 1 — Torso Density + Arms",
          exercises: [
            WorkoutExercise(name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Dumbbell Wrist Curl", repTarget: RepTarget(minimum: 12, maximum: 20)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 2 — Thighs + Posterior Chain + Traps",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Neck Extension", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 3 — Upper Back + Shoulder Girdle + Traps",
          exercises: [
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Neck Flexion", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
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
        WorkoutTemplate(
          name: "Day 1 — Upper Chest + Back Width",
          exercises: [
            WorkoutExercise(name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 2 — Legs + Torso",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Hanging Knee Raise", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "45-Degree Back Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Day 3 — Delts + Balanced Upper Body",
          exercises: [
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
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
        WorkoutTemplate(
          name: "Workout A",
          exercises: [
            WorkoutExercise(name: "Front Squat", repTarget: RepTarget(minimum: 5, maximum: 8)),
            WorkoutExercise(name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Incline Dumbbell Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Dumbbell Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout B",
          exercises: [
            WorkoutExercise(name: "Conventional Deadlift", repTarget: RepTarget(minimum: 5, maximum: 8)),
            WorkoutExercise(name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Bulgarian Split Squat", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachLeg)),
            WorkoutExercise(name: "Dumbbell Rear-Delt Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Dumbbell Overhead Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout C",
          exercises: [
            WorkoutExercise(name: "Goblet Squat", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "One-Arm Dumbbell Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachSide)),
            WorkoutExercise(name: "Standing Dumbbell Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Dumbbell Romanian Deadlift", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Dumbbell Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
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
        WorkoutTemplate(
          name: "Workout A",
          exercises: [
            WorkoutExercise(name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Machine Chest Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Machine Preacher Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout B",
          exercises: [
            WorkoutExercise(name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Incline Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Cable Curl", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
          ]
        ),
        WorkoutTemplate(
          name: "Workout C",
          exercises: [
            WorkoutExercise(name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10)),
            WorkoutExercise(name: "Wide-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Pec Deck", repTarget: RepTarget(minimum: 10, maximum: 15)),
            WorkoutExercise(name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20)),
            WorkoutExercise(name: "Machine Preacher Curl", repTarget: RepTarget(minimum: 8, maximum: 12)),
            WorkoutExercise(name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12)),
          ]
        )
      ]
    )
  ])
}
