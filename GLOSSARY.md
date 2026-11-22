# OneSet

OneSet guides lifters through curated HIT programs and keeps a reliable record of their training.

## Language

**Catalog**: The curated collection of programs, workout templates, exercises, and prescriptions supplied by OneSet.

**Catalog publication**: A complete catalog version made available to lifters after review.

**Program**: A named training plan containing an ordered rotation of workouts.
_Avoid_: Plan (when referring to a different concept)

**Removed program**: A program unavailable in program choosers, which users can continue while it remains their current program and whose training history remains available.

**Enrollment**: A user's lasting relationship with a program, including remembered exercise preferences.
_Avoid_: Cycle

**Cycle**: A user's run through a program. Starting another cycle leaves prior training history intact.

**Training week**: One group of the program's prescribed workout days, independent of calendar dates.
_Avoid_: Calendar week

**Workout template**: The ordered exercises and instructions prescribed for a workout day.
_Avoid_: Session

**Exercise**: A distinct movement in the curated catalog, shared across programs. Its recorded results belong to that movement; different variations have separate results.

**Workout occurrence**: A particular workout day within a particular training week and cycle.

**Session**: An actual attempt to perform a workout occurrence, including its recorded performance.
_Avoid_: Workout template

**Completed session**: A session explicitly finished after completing at least one working set. It may include unperformed exercises.

**Training history**: The record of a user's completed sessions across programs and cycles, including sessions with unperformed exercises. Active and discarded attempts are excluded.

**Session duration**: The elapsed time from starting a session to explicitly finishing it, including rests and interruptions.

**Exercise slot**: A prescribed place for an exercise in a workout, retained as a recognizable place when a replacement is chosen.

**Prescription**: The exercise, working-set count, rep target, stopping instructions, warmup guidance, and rest guidance assigned to a slot.

**Superset**: Two adjacent exercise slots in a workout template prescribed to be performed back to back before resting. An exercise slot can belong to at most one superset.

**Working set**: The single main effort performed for an exercise after preparation. For unilateral movements, the prescription includes work on both sides.

**Warmup**: Preparatory work preceding the working set; shown as guidance but not logged in OneSet.

**Session replacement**: An exercise change that applies only to the current session.

**Remembered replacement**: An exercise choice retained for one slot in a user's program across future cycles until the user changes it. Other slots and programs keep their own exercise choices.

**Total weight**: The external load used in the performed movement: combined dumbbell weight when two are used, one dumbbell's weight when one is used, or bar plus plates for a barbell. Added load is recorded for weighted bodyweight movements.

**Previous performance**: The latest completed working-set result for the same exercise in the same program workout, with a clearly labeled fallback to the latest result elsewhere.

**Double progression**: Increasing clean repetitions within a prescribed range, then suggesting an increase in load upon reaching the upper target.

**Technical failure**: The stopping point at which another repetition would require unacceptable technique breakdown.

**Momentary muscular failure**: The point at which another full repetition cannot be completed with the prescribed movement standard.

## Subscription

**Pro access**: The right to start new workouts, granted only by an active, server-verified production entitlement for the selected account. Existing sessions, history, and previews never require it.
_Avoid_: Premium, subscribed

**Account selection**: The signed-in account that owns subscription state, numbered by a generation. Any change of account, including signing out and back in as the same account, starts a new generation; results and purchases tied to an earlier generation are discarded.

**Saved verified expiry**: The latest server-verified Pro expiry kept on the device for one account and billing environment, so Pro access can be granted offline until that time. Sandbox and production records are kept apart, and a confirmed sign-out removes them.

**Pending approval**: A purchase awaiting outside approval, such as Ask to Buy, or a charge not yet confirmed by a verified check. It keeps the account out of checkout and grants no Pro access until verified.
