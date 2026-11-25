# HIT principles and OneSet house rules

Distilled from the November 2026 HIT research review. Use this to ground design choices. The approved source for global rules is [the program library](../../../../docs/HIT_Workout_Program_Library.md); if the two disagree, the library wins.

## Lineage, by what each contributes to a design

| Source | Use it for |
| --- | --- |
| Arthur Jones (Nautilus, 1970s) | Whole-body sessions, one set per exercise, pre-exhaust (isolation straight into a compound for the same muscle), full range of motion, controlled cadence. Late Jones: 1-2 sessions a week. |
| Casey Viator (Colorado Experiment, 1973) | Proof of concept only. His logged session covered the whole body in about 30 minutes. The reported gains are disputed, so never cite them as expected results. |
| Ellington Darden | Twice-weekly full-body routines, machines are as good as free weights, negative emphasis. |
| Mike Mentzer | Ideal Routine: 4 workouts at least 96 h apart, 15 working sets in total, pre-exhaust supersets, rep bands of 6-10 for upper body, 8-15 for legs and 12-20 for calves. Consolidated: 2-3 big lifts per workout, 7-14 days apart. Rule: if you aren't getting stronger, add rest, not sets. |
| Dorian Yates (mid-1990s) | Four sessions on a 7-day cycle, 2-4 exercises per muscle, one all-out set each, rested pre-exhaust (leg extension before presses, leg curl before stiff-leg deadlift), calves every leg day, under 45 minutes. |
| McGuff and Little (*Body by Science*) | Minimum effective dose: five machine compounds once a week. |
| Hutchins (SuperSlow), Brzycki, Leistner | Strict cadence, no momentum, simple progression. |

## Non-negotiable house rules

- One working set per exercise slot. Warmups are guidance and are never logged.
- Every slot records weight and reps. A timed hold is logged as one rep (see `leg-extension-static-hold`).
- Stopping standard per exercise:
  - **MMF:** stable machines and isolation movements.
  - **TF:** free-weight compounds, weighted chins and dips, rows, deadlift variations, and anything where a forced failed rep adds risk.
- Rep bands:
  - Heavy compounds: 5-8 or 6-10.
  - Moderate compounds: 8-12.
  - Isolation: 10-15.
  - Lateral and rear delts, calves, neck: 12-20.
- Progression is double progression, already built into the app. Do not program forced reps, drop sets or partials: users mostly train alone, and those techniques break session-to-session comparisons.
- Rest bands (`rest_seconds` on the exercise): large compounds 150-240, moderate compounds 120-180, isolation 90-150.
- One definitive exercise per slot. No A/B alternatives inside a workout.

## Design heuristics

1. **Priority goes first.** Place the goal's highest-priority muscles at the start of the session and give them the most weekly exposures.
2. **Session size:**

   | Program type | Working sets per session |
   | --- | --- |
   | 2-day full body | 6-9 |
   | 3-day | 5-8 |
   | 4- or 5-day split | 4-7 |

   Above about 8 slots, a session stops being HIT.
3. **Weekly direct sets per muscle:** usually 1-3 for most muscles and up to 4-5 for priority muscles. Twice-weekly exposure for priorities when frequency allows.
4. **Pre-exhaust supersets** only when the isolation and compound load the same prime mover, for example:
   - Leg Extension into Leg Press or Hack Squat.
   - Pec Deck into an incline press.
   - Lateral Raise into a shoulder press.
   - Leg Curl into an RDL. When the RDL follows a leg curl, use a lighter load and TF.

   Use at most 2-3 pairs per workout. A pair shares one 3-minute rest after both sets.
5. **No duplicate slot within a workout.** Avoid repeating the same exercise across a program's workouts unless it is the deliberate priority lift.
6. **Joint and fatigue order:** don't stack three free-weight TF compounds in a row. Don't put a heavy hinge and a heavy row in the same session when a lighter-hinge day exists.
7. **Always include calves on at least one day**, plus some trunk work: Cable Crunch, Hanging Knee Raise or 45-Degree Back Extension.
8. **Distinctness:** a new program must differ from every existing program in at least one of: frequency, split structure, emphasis, or equipment profile. If it would be under 70% different from an existing program in slots, propose editing that program instead.

## Translating an aesthetic or athletic goal

State the mapping explicitly before drafting:

- **Primary muscles:** the shape-defining ones that get the most exposures and go first.
- **Secondary muscles:** trained directly, at normal volume.
- **Maintenance muscles:** trained through compounds, with no extra direct work.
- **What the goal does not mean:** the program builds the appearance through hypertrophy, not sport performance. For example, a sprinter look comes from glutes, hamstrings, quads, calves, shoulders, arms and abs on a lean frame. Sprint speed would need sprint training, which OneSet doesn't program.

Example mappings (starting points, not rules):

| Goal | Primary | Secondary | Keep modest |
| --- | --- | --- | --- |
| Sprinter / athletic | Glutes, hamstrings, quads, calves | Delts, arms, abs, upper back | Chest mass, traps |
| Swimmer | Lats, delts, triceps | Upper chest, upper back, abs | Leg mass |
| Wrestler / powerhouse | Upper back, traps, neck, thighs | Arms, forearms, posterior chain | none |
| Classic / golden era | Delts, lats, upper chest, calves | Arms, quads, hamstrings | Waist (trunk work stays moderate) |
| Glute focus | Glutes, hamstrings | Quads, adductors, upper back | Heavy upper-body compounds |
