import type { ProgramLibrary } from '@/types/program';

export const PROGRAM_LIBRARY: ProgramLibrary = {
  programs: [
    {
      id: 'foundation-full-body-hit',
      number: 1,
      name: 'Foundation Full-Body HIT',
      slug: 'foundation-full-body-hit',
      bestFor: 'Beginner lifters, returning lifters, or users learning HIT discipline.',
      weeklySchedule:
        'Train **2–3 days per week**, never on back-to-back days.\n\nExample:\n\n- Monday — Workout A\n- Thursday — Workout B\n- Optional Saturday — Workout A, only if recovery is excellent',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    },
    {
      id: 'classic-symmetry-full-body-hit',
      number: 2,
      name: 'Classic Symmetry Full-Body HIT',
      slug: 'classic-symmetry-full-body-hit',
      bestFor:
        'Users who want a balanced, classic physique look: shoulders, upper chest, back width, waist control, legs, and posture.',
      weeklySchedule:
        'Train **3 days per week** if recovery is good. Otherwise train 2 days per week.\n\nExample:\n\n- Monday — Workout A\n- Wednesday — Workout B\n- Friday — Workout C',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 3,
    },
    {
      id: 'machine-circuit-hit',
      number: 3,
      name: 'Machine Circuit HIT',
      slug: 'machine-circuit-hit',
      bestFor:
        'Beginners, busy lifters, commercial gym users, and anyone who wants a pure machine-based HIT experience.',
      weeklySchedule:
        'Train **2 days per week**.\n\nExample:\n\n- Tuesday — Full-Body Machine HIT\n- Friday — Full-Body Machine HIT',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 2,
      workoutCount: 1,
    },
    {
      id: 'two-way-split-hit',
      number: 4,
      name: 'Two-Way Split HIT',
      slug: 'two-way-split-hit',
      bestFor:
        'Late beginners and intermediate lifters who need more focus than full-body HIT but are not ready for very low-frequency advanced training.',
      weeklySchedule:
        'Train **3 days per week** using alternating A/B sessions.\n\nWeek 1:\n\n- Monday — A\n- Wednesday — B\n- Friday — A\n\nWeek 2:\n\n- Monday — B\n- Wednesday — A\n- Friday — B',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    },
    {
      id: 'three-way-precision-hit',
      number: 5,
      name: 'Three-Way Precision HIT',
      slug: 'three-way-precision-hit',
      bestFor: 'Intermediate lifters who want a clean push/pull/legs structure with HIT intensity.',
      weeklySchedule:
        'Train **3 days per week**.\n\nExample:\n\n- Monday — Push\n- Wednesday — Pull\n- Friday — Legs',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 3,
    },
    {
      id: 'four-day-mass-split-hit',
      number: 6,
      name: 'Four-Day Mass Split HIT',
      slug: 'four-day-mass-split-hit',
      bestFor:
        'Intermediate to advanced lifters who can generate high effort and need more recovery between body parts.',
      weeklySchedule:
        'This is a rotating 6-day cycle.\n\n- Day 1 — Delts, Traps, Triceps, Abs\n- Day 2 — Back, Rear Delts\n- Day 3 — Rest\n- Day 4 — Chest, Biceps, Abs\n- Day 5 — Rest\n- Day 6 — Legs, Calves\n- Day 7 — Rest or repeat Day 1 if recovered',
      recommendedDaysPerWeekMin: null,
      recommendedDaysPerWeekMax: null,
      workoutCount: 4,
    },
    {
      id: 'minimalist-recovery-hit',
      number: 7,
      name: 'Minimalist Recovery HIT',
      slug: 'minimalist-recovery-hit',
      bestFor:
        'Advanced lifters, hard gainers, older lifters, or users who stall on higher frequency.',
      weeklySchedule:
        'Train every **4–7 days**, alternating Workout A and Workout B.\n\nExample:\n\n- Monday — A\n- Friday — B\n- Next Wednesday — A\n- Next Sunday — B',
      recommendedDaysPerWeekMin: 1,
      recommendedDaysPerWeekMax: 2,
      workoutCount: 2,
    },
    {
      id: 'athletic-power-hit',
      number: 8,
      name: 'Athletic Power HIT',
      slug: 'athletic-power-hit',
      bestFor:
        'Users who want a dense, explosive, wrestler-like physique while still respecting HIT recovery.',
      weeklySchedule:
        'Train **4 days per week** with 3 rest days.\n\nExample:\n\n- Monday — Power Lower + Pull\n- Tuesday — Power Upper + Press\n- Wednesday — Rest\n- Thursday — Strength Pull + Traps\n- Friday — Strength Press + Conditioning Core\n- Saturday — Rest\n- Sunday — Rest',
      recommendedDaysPerWeekMin: 4,
      recommendedDaysPerWeekMax: 4,
      workoutCount: 4,
    },
    {
      id: 'pre-exhaust-specialist-hit',
      number: 9,
      name: 'Pre-Exhaust Specialist HIT',
      slug: 'pre-exhaust-specialist-hit',
      bestFor:
        'Intermediate and advanced users who struggle to feel the target muscle during heavy compound lifts.',
      weeklySchedule:
        'Train **3 days per week**.\n\nExample:\n\n- Monday — Chest/Back\n- Wednesday — Legs\n- Friday — Shoulders/Arms',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 3,
    },
    {
      id: 'negative-control-hit',
      number: 10,
      name: 'Negative-Control HIT',
      slug: 'negative-control-hit',
      bestFor:
        'Advanced users with excellent form, good recovery, and access to safe machines or a trusted training partner.',
      weeklySchedule:
        'Train **2 days per week**.\n\nExample:\n\n- Monday — Upper\n- Friday — Lower',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 2,
      workoutCount: 2,
    },
    {
      id: 'upper-lower-logbook-hit',
      number: 11,
      name: 'Upper/Lower Logbook HIT',
      slug: 'upper-lower-logbook-hit',
      bestFor:
        'Users who like simple structure, measurable progression, and a slightly more modern app-friendly split.',
      weeklySchedule:
        'Train **2–4 days per week** depending on recovery.\n\nBeginner/intermediate:\n\n- Monday — Upper A\n- Thursday — Lower A\n\nIntermediate/advanced:\n\n- Monday — Upper A\n- Tuesday — Lower A\n- Thursday — Upper B\n- Friday — Lower B',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 4,
      workoutCount: 4,
    },
    {
      id: 'weak-point-rotation-hit',
      number: 12,
      name: 'Weak-Point Rotation HIT',
      slug: 'weak-point-rotation-hit',
      bestFor: 'Advanced users who need specialization without abandoning recovery.',
      weeklySchedule:
        'Train **3 days per week**.\n\n- Day 1 — Priority Muscle + Maintenance Push\n- Day 2 — Legs + Back Maintenance\n- Day 3 — Priority Muscle + Arms/Delts Maintenance\n\nThe app should let the user choose one priority:\n\n- Chest\n- Back\n- Delts\n- Arms\n- Legs',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 1,
    },
    {
      id: 'rest-pause-density-hit',
      number: 13,
      name: 'Rest-Pause Density HIT',
      slug: 'rest-pause-density-hit',
      bestFor:
        'Advanced users who want a time-efficient high-effort routine without increasing exercise count.',
      weeklySchedule:
        'Train **2–3 days per week**.\n\nExample:\n\n- Monday — A\n- Thursday — B\n- Optional Sunday — A',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    },
    {
      id: 'beginner-strength-to-hit-bridge',
      number: 14,
      name: 'Beginner Strength-to-HIT Bridge',
      slug: 'beginner-strength-to-hit-bridge',
      bestFor: 'New lifters who need skill practice before true all-out HIT.',
      weeklySchedule: 'Train **3 days per week** for 4–6 weeks.',
      recommendedDaysPerWeekMin: 3,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    },
    {
      id: 'home-minimal-equipment-hit',
      number: 15,
      name: 'Home Minimal Equipment HIT',
      slug: 'home-minimal-equipment-hit',
      bestFor: 'Users training at home with dumbbells, bands, a pull-up bar, and a bench.',
      weeklySchedule: 'Train **2–3 days per week**.',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    },
  ],
  selectionGroups: {
    beginner: [
      'Beginner Strength-to-HIT Bridge',
      'Foundation Full-Body HIT',
      'Machine Circuit HIT',
    ],
    late_beginner: [
      'Two-Way Split HIT',
      'Classic Symmetry Full-Body HIT',
      'Upper/Lower Logbook HIT',
    ],
    intermediate: [
      'Three-Way Precision HIT',
      'Four-Day Mass Split HIT',
      'Pre-Exhaust Specialist HIT',
      'Upper/Lower Logbook HIT',
    ],
    advanced: [
      'Minimalist Recovery HIT',
      'Negative-Control HIT',
      'Rest-Pause Density HIT',
      'Weak-Point Rotation HIT',
      'Athletic Power HIT',
    ],
  },
  selectionGroupIds: {
    beginner: [
      'beginner-strength-to-hit-bridge',
      'foundation-full-body-hit',
      'machine-circuit-hit',
    ],
    late_beginner: [
      'two-way-split-hit',
      'classic-symmetry-full-body-hit',
      'upper-lower-logbook-hit',
    ],
    intermediate: [
      'three-way-precision-hit',
      'four-day-mass-split-hit',
      'pre-exhaust-specialist-hit',
      'upper-lower-logbook-hit',
    ],
    advanced: [
      'minimalist-recovery-hit',
      'negative-control-hit',
      'rest-pause-density-hit',
      'weak-point-rotation-hit',
      'athletic-power-hit',
    ],
  },
};
