import Foundation

extension ProgramCatalog {
  static var bundled: ProgramCatalog { ProgramCatalog(programs: [
      TrainingProgram(
        id: "full-body", name: "Full Body",
        format: "A / B / C",
        emphasis: "Lifters who want frequent whole-body practice and broad hypertrophy coverage without high per-session volume.",
        workouts: [
            WorkoutTemplate(
              id: "full-body-workout-a-vertical-pull-upper-chest", name: "Workout A — Vertical Pull + Upper Chest",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-a-vertical-pull-upper-chest-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "full-body-workout-b-horizontal-pull-chest", name: "Workout B — Horizontal Pull + Chest",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-incline-dumbbell-curl", exerciseKey: "incline-dumbbell-curl",
                    name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-b-horizontal-pull-chest-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "full-body-workout-c-shoulder-girdle-balanced-lower-body", name: "Workout C — Shoulder Girdle + Balanced Lower Body",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-lying-leg-curl", exerciseKey: "lying-leg-curl",
                    name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align the machine pivot with your knees and place the roller above your heels. Curl smoothly without lifting your hips, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-machine-chest-press", exerciseKey: "machine-chest-press",
                    name: "Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Adjust the seat so the handles start around mid-chest. Keep your back supported and press through a controlled, comfortable range without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "full-body-workout-c-shoulder-girdle-balanced-lower-body-cable-crunch", exerciseKey: "cable-crunch",
                    name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "upper-lower", name: "Upper / Lower",
        format: "Upper A / Lower A / Upper B / Lower B",
        emphasis: "Lifters who prefer shorter sessions and want more recovery between upper- and lower-body work.",
        workouts: [
            WorkoutTemplate(
              id: "upper-lower-upper-a", name: "Upper A",
              banner: "upper-body",
              exercises: [
                  WorkoutExercise(
                    id: "upper-lower-upper-a-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-a-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-a-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-a-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-a-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-a-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "upper-lower-lower-a", name: "Lower A",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "upper-lower-lower-a-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-a-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-a-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-a-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-a-cable-crunch", exerciseKey: "cable-crunch",
                    name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "upper-lower-upper-b", name: "Upper B",
              banner: "upper-body",
              exercises: [
                  WorkoutExercise(
                    id: "upper-lower-upper-b-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-b-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-b-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-b-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-b-incline-dumbbell-curl", exerciseKey: "incline-dumbbell-curl",
                    name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-upper-b-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "upper-lower-lower-b", name: "Lower B",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "upper-lower-lower-b-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-b-45-degree-back-extension", exerciseKey: "45-degree-back-extension",
                    name: "45-Degree Back Extension", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-b-bulgarian-split-squat", exerciseKey: "bulgarian-split-squat",
                    name: "Bulgarian Split Squat", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachLeg),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-b-lying-leg-curl", exerciseKey: "lying-leg-curl",
                    name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align the machine pivot with your knees and place the roller above your heels. Curl smoothly without lifting your hips, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "upper-lower-lower-b-hanging-knee-raise", exerciseKey: "hanging-knee-raise",
                    name: "Hanging Knee Raise", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "push-pull-legs", name: "Push / Pull / Legs",
        format: "Push / Pull / Legs",
        emphasis: "Lifters who like classic movement-based training and can recover from training each major muscle group hard once per week.",
        workouts: [
            WorkoutTemplate(
              id: "push-pull-legs-push", name: "Push",
              banner: "chest-push",
              exercises: [
                  WorkoutExercise(
                    id: "push-pull-legs-push-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-push-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-push-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-push-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-push-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-push-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "push-pull-legs-pull", name: "Pull",
              banner: "back-pull",
              exercises: [
                  WorkoutExercise(
                    id: "push-pull-legs-pull-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-pull-hammer-curl", exerciseKey: "hammer-curl",
                    name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "push-pull-legs-legs", name: "Legs",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "push-pull-legs-legs-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-legs-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-legs-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-legs-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-legs-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "push-pull-legs-legs-cable-crunch", exerciseKey: "cable-crunch",
                    name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "bro-split", name: "Bro Split",
        format: "Chest / Back / Legs / Shoulders / Arms",
        emphasis: "Lifters who enjoy concentrated body-part sessions and prefer very low per-exercise set counts.",
        workouts: [
            WorkoutTemplate(
              id: "bro-split-day-1-chest", name: "Day 1 — Chest",
              banner: "chest-push",
              exercises: [
                  WorkoutExercise(
                    id: "bro-split-day-1-chest-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-1-chest-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-1-chest-machine-chest-press", exerciseKey: "machine-chest-press",
                    name: "Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Adjust the seat so the handles start around mid-chest. Keep your back supported and press through a controlled, comfortable range without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-1-chest-pec-deck", exerciseKey: "pec-deck",
                    name: "Pec Deck", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Adjust the seat so the pads are comfortable and your elbows are slightly bent. Bring your arms together smoothly, then open them under control without forcing a stretch.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "bro-split-day-2-back", name: "Day 2 — Back",
              banner: "back-pull",
              exercises: [
                  WorkoutExercise(
                    id: "bro-split-day-2-back-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-2-back-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-2-back-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-2-back-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-2-back-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "bro-split-day-3-legs", name: "Day 3 — Legs",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "bro-split-day-3-legs-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-3-legs-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-3-legs-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-3-legs-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-3-legs-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "bro-split-day-4-shoulders", name: "Day 4 — Shoulders",
              banner: "shoulders",
              exercises: [
                  WorkoutExercise(
                    id: "bro-split-day-4-shoulders-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-4-shoulders-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-4-shoulders-cable-lateral-raise", exerciseKey: "cable-lateral-raise",
                    name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-4-shoulders-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-4-shoulders-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "bro-split-day-5-arms", name: "Day 5 — Arms",
              banner: "arms",
              exercises: [
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-close-grip-smith-machine-bench-press", exerciseKey: "close-grip-smith-machine-bench-press",
                    name: "Close-Grip Smith-Machine Bench Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-incline-dumbbell-curl", exerciseKey: "incline-dumbbell-curl",
                    name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-hammer-curl", exerciseKey: "hammer-curl",
                    name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "bro-split-day-5-arms-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "minimalist-full-body", name: "Minimalist Full Body",
        format: "A / B",
        emphasis: "People who want the smallest practical weekly gym commitment while still training the major muscle groups hard.",
        workouts: [
            WorkoutTemplate(
              id: "minimalist-full-body-workout-a", name: "Workout A",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-a-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "minimalist-full-body-workout-b", name: "Workout B",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "minimalist-full-body-workout-b-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "v-taper", name: "V-Taper",
        format: "Lats + Upper Chest / Lower Body + Delts / Back + Shoulder Width",
        emphasis: "Greater shoulder-to-waist contrast through lat width, lateral delts, upper chest, and balanced lower-body development.",
        workouts: [
            WorkoutTemplate(
              id: "v-taper-day-1-lats-upper-chest", name: "Day 1 — Lats + Upper Chest",
              banner: "upper-body",
              exercises: [
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-incline-dumbbell-curl", exerciseKey: "incline-dumbbell-curl",
                    name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-1-lats-upper-chest-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "v-taper-day-2-lower-body-delts", name: "Day 2 — Lower Body + Delts",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-cable-lateral-raise", exerciseKey: "cable-lateral-raise",
                    name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-2-lower-body-delts-cable-crunch", exerciseKey: "cable-crunch",
                    name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "v-taper-day-3-back-width-shoulder-width", name: "Day 3 — Back Width + Shoulder Width",
              banner: "back-pull",
              exercises: [
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-incline-machine-chest-press", exerciseKey: "incline-machine-chest-press",
                    name: "Incline Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Adjust the seat so the handles begin beside your upper chest. Keep your back supported and press through a controlled range without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "v-taper-day-3-back-width-shoulder-width-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "powerhouse", name: "Powerhouse",
        format: "Torso + Arms / Thighs + Posterior Chain / Upper Back + Shoulder Girdle",
        emphasis: "A dense, powerful wrestler-like build — thick torso, substantial upper back, strong shoulder girdle, muscular arms and forearms, heavy thighs and posterior chain, with developed neck and traps.",
        workouts: [
            WorkoutTemplate(
              id: "powerhouse-day-1-torso-density-arms", name: "Day 1 — Torso Density + Arms",
              banner: "upper-body",
              exercises: [
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-smith-machine-barbell-row", exerciseKey: "smith-machine-barbell-row",
                    name: "Smith-Machine Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-1-torso-density-arms-dumbbell-wrist-curl", exerciseKey: "dumbbell-wrist-curl",
                    name: "Dumbbell Wrist Curl", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "powerhouse-day-2-thighs-posterior-chain-traps", name: "Day 2 — Thighs + Posterior Chain + Traps",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-machine-neck-extension", exerciseKey: "machine-neck-extension",
                    name: "Machine Neck Extension", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing. Powerhouse guidance calls for conservative neck work, controlled repetitions, and modest loading.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-2-thighs-posterior-chain-traps-cable-crunch", exerciseKey: "cable-crunch",
                    name: "Cable Crunch", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "powerhouse-day-3-upper-back-shoulder-girdle-traps", name: "Day 3 — Upper Back + Shoulder Girdle + Traps",
              banner: "back-pull",
              exercises: [
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-hammer-curl", exerciseKey: "hammer-curl",
                    name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-machine-neck-flexion", exerciseKey: "machine-neck-flexion",
                    name: "Machine Neck Flexion", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing. Powerhouse guidance calls for conservative neck work, controlled repetitions, and modest loading.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "powerhouse-day-3-upper-back-shoulder-girdle-traps-dumbbell-shrug", exerciseKey: "dumbbell-shrug",
                    name: "Dumbbell Shrug", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "classic-physique", name: "Classic Physique",
        format: "Upper Chest + Back Width / Legs + Torso / Delts + Balanced Upper Body",
        emphasis: "Balanced old-school proportions — broad shoulders, upper chest, lat width, proportional arms, a controlled waistline, and athletic legs.",
        workouts: [
            WorkoutTemplate(
              id: "classic-physique-day-1-upper-chest-back-width", name: "Day 1 — Upper Chest + Back Width",
              banner: "back-pull",
              exercises: [
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-incline-smith-machine-press", exerciseKey: "incline-smith-machine-press",
                    name: "Incline Smith-Machine Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-1-upper-chest-back-width-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "classic-physique-day-2-legs-torso", name: "Day 2 — Legs + Torso",
              banner: "lower-body",
              exercises: [
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-hanging-knee-raise", exerciseKey: "hanging-knee-raise",
                    name: "Hanging Knee Raise", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-2-legs-torso-45-degree-back-extension", exerciseKey: "45-degree-back-extension",
                    name: "45-Degree Back Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "classic-physique-day-3-delts-balanced-upper-body", name: "Day 3 — Delts + Balanced Upper Body",
              banner: "shoulders",
              exercises: [
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-cable-lateral-raise", exerciseKey: "cable-lateral-raise",
                    name: "Cable Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-incline-dumbbell-curl", exerciseKey: "incline-dumbbell-curl",
                    name: "Incline Dumbbell Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "classic-physique-day-3-delts-balanced-upper-body-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "free-weight-full-body", name: "Free-Weight Full Body",
        format: "A / B / C",
        emphasis: "Gyms with limited machines or lifters who strongly prefer barbells, dumbbells, and bodyweight loading.",
        workouts: [
            WorkoutTemplate(
              id: "free-weight-full-body-workout-a", name: "Workout A",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-front-squat", exerciseKey: "front-squat",
                    name: "Front Squat", repTarget: RepTarget(minimum: 5, maximum: 8, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 5, maximum: 8, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-weighted-chin-up", exerciseKey: "weighted-chin-up",
                    name: "Weighted Chin-Up", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-incline-dumbbell-press", exerciseKey: "incline-dumbbell-press",
                    name: "Incline Dumbbell Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-romanian-deadlift", exerciseKey: "romanian-deadlift",
                    name: "Romanian Deadlift", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-dumbbell-lateral-raise", exerciseKey: "dumbbell-lateral-raise",
                    name: "Dumbbell Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-a-barbell-curl", exerciseKey: "barbell-curl",
                    name: "Barbell Curl", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "free-weight-full-body-workout-b", name: "Workout B",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-conventional-deadlift", exerciseKey: "conventional-deadlift",
                    name: "Conventional Deadlift", repTarget: RepTarget(minimum: 5, maximum: 8, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 5, maximum: 8, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-weighted-dip", exerciseKey: "weighted-dip",
                    name: "Weighted Dip", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-barbell-row", exerciseKey: "barbell-row",
                    name: "Barbell Row", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-bulgarian-split-squat", exerciseKey: "bulgarian-split-squat",
                    name: "Bulgarian Split Squat", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachLeg),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-dumbbell-rear-delt-raise", exerciseKey: "dumbbell-rear-delt-raise",
                    name: "Dumbbell Rear-Delt Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-b-dumbbell-overhead-triceps-extension", exerciseKey: "dumbbell-overhead-triceps-extension",
                    name: "Dumbbell Overhead Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "free-weight-full-body-workout-c", name: "Workout C",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-goblet-squat", exerciseKey: "goblet-squat",
                    name: "Goblet Squat", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-one-arm-dumbbell-row", exerciseKey: "one-arm-dumbbell-row",
                    name: "One-Arm Dumbbell Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .eachSide),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-standing-dumbbell-shoulder-press", exerciseKey: "standing-dumbbell-shoulder-press",
                    name: "Standing Dumbbell Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-dumbbell-romanian-deadlift", exerciseKey: "dumbbell-romanian-deadlift",
                    name: "Dumbbell Romanian Deadlift", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Stop when you cannot complete another rep without losing position or changing your form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-dumbbell-lateral-raise", exerciseKey: "dumbbell-lateral-raise",
                    name: "Dumbbell Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "free-weight-full-body-workout-c-hammer-curl", exerciseKey: "hammer-curl",
                    name: "Hammer Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Lower the weight under control, use a comfortable full range, and lift without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      ),
      TrainingProgram(
        id: "machine-full-body", name: "Machine Full Body",
        format: "A / B / C",
        emphasis: "Lifters who want maximum stability, simple progression, and a low-skill environment for high-effort training.",
        workouts: [
            WorkoutTemplate(
              id: "machine-full-body-workout-a", name: "Workout A",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-hack-squat-machine", exerciseKey: "hack-squat-machine",
                    name: "Hack Squat Machine", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the machine so your back remains supported and your knees track over your feet. Lower under control through a comfortable range, then drive through the whole foot.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-machine-chest-press", exerciseKey: "machine-chest-press",
                    name: "Machine Chest Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Adjust the seat so the handles start around mid-chest. Keep your back supported and press through a controlled, comfortable range without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-neutral-grip-lat-pulldown", exerciseKey: "neutral-grip-lat-pulldown",
                    name: "Neutral-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the handles toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-machine-preacher-curl", exerciseKey: "machine-preacher-curl",
                    name: "Machine Preacher Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your upper arms supported by the pad and curl without lifting your shoulders. Lower the weight under control without bouncing at the bottom.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-a-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "machine-full-body-workout-b", name: "Workout B",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-leg-press", exerciseKey: "leg-press",
                    name: "Leg Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Place your feet in a comfortable stance and lower the platform only as far as your pelvis stays supported. Press through the whole foot without bouncing or forcefully locking your knees.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 210, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-chest-supported-machine-row", exerciseKey: "chest-supported-machine-row",
                    name: "Chest-Supported Machine Row", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Set the seat so you can reach the handles without losing chest support. Row by moving your elbows back, pause briefly, and return without lifting your chest.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-incline-machine-chest-press", exerciseKey: "incline-machine-chest-press",
                    name: "Incline Machine Chest Press", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Adjust the seat so the handles begin beside your upper chest. Keep your back supported and press through a controlled range without bouncing.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-lying-leg-curl", exerciseKey: "lying-leg-curl",
                    name: "Lying Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align the machine pivot with your knees and place the roller above your heels. Curl smoothly without lifting your hips, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-reverse-pec-deck", exerciseKey: "reverse-pec-deck",
                    name: "Reverse Pec Deck", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the seat so the handles are level with your shoulders. Sweep your arms out and back while keeping your torso against the pad and your neck relaxed.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-cable-curl", exerciseKey: "cable-curl",
                    name: "Cable Curl", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your elbows close to your sides and shoulders still. Curl the handle smoothly and lower it under control without leaning back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-b-overhead-cable-triceps-extension", exerciseKey: "overhead-cable-triceps-extension",
                    name: "Overhead Cable Triceps Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Keep your upper arms steady overhead and extend your elbows through a comfortable range. Return slowly without arching your back.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  )
              ]
            ),
            WorkoutTemplate(
              id: "machine-full-body-workout-c", name: "Workout C",
              banner: "general-gym",
              exercises: [
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-leg-extension", exerciseKey: "leg-extension",
                    name: "Leg Extension", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Align the machine pivot with your knee and place the roller above your ankles. Extend your knees smoothly, then lower the pad under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-machine-shoulder-press", exerciseKey: "machine-shoulder-press",
                    name: "Machine Shoulder Press", repTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    instructions: "Set the handles around shoulder height and keep your back supported. Press upward smoothly without shrugging, then lower under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 180, defaultRepTarget: RepTarget(minimum: 6, maximum: 10, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-wide-grip-lat-pulldown", exerciseKey: "wide-grip-lat-pulldown",
                    name: "Wide-Grip Lat Pulldown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your torso steady and shoulders down. Pull the bar toward your upper chest by driving your elbows down, then return under control without swinging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-seated-leg-curl", exerciseKey: "seated-leg-curl",
                    name: "Seated Leg Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Align your knees with the machine pivot and secure the pads comfortably. Curl the pad down without lifting your hips, then return slowly.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 150, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-pec-deck", exerciseKey: "pec-deck",
                    name: "Pec Deck", repTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    instructions: "Adjust the seat so the pads are comfortable and your elbows are slightly bent. Bring your arms together smoothly, then open them under control without forcing a stretch.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 10, maximum: 15, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-machine-lateral-raise", exerciseKey: "machine-lateral-raise",
                    name: "Machine Lateral Raise", repTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    instructions: "Set the pads against your upper arms and raise through a comfortable arc with a slight elbow bend. Keep your torso still and avoid shrugging.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 12, maximum: 20, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-machine-preacher-curl", exerciseKey: "machine-preacher-curl",
                    name: "Machine Preacher Curl", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your upper arms supported by the pad and curl without lifting your shoulders. Lower the weight under control without bouncing at the bottom.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  ),
                  WorkoutExercise(
                    id: "machine-full-body-workout-c-cable-triceps-pressdown", exerciseKey: "cable-triceps-pressdown",
                    name: "Cable Triceps Pressdown", repTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    instructions: "Keep your elbows near your sides and shoulders steady. Extend your elbows smoothly, then let the cable return under control.",
                    stoppingGuidance: "Continue until you cannot complete another full rep through the planned range with controlled form.",
                    warmupGuidance: "For the first heavy exercise in a workout, use warm-up sets at about 40–50% of your working weight for 6–8 reps, 65–70% for 3–5 reps, and 80–85% for 1–3 reps. Skip any stage that feels unnecessary. For later exercises, warm up only if needed. Do not take warm-up sets to failure.",
                    restSeconds: 120, defaultRepTarget: RepTarget(minimum: 8, maximum: 12, scope: .reps),
                    videoKey: nil
                  )
              ]
            )
        ], recommendedWeeks: 8, isOffered: true
      )
  ]) }
}
