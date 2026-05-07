PRODUCT SPEC - HIT WORKOUT APP (MVP)

## 1. Product Overview

### Working Name
OneSet

### Value Proposition
Build muscle with guided high-intensity workouts in under 30 minutes per session, without living in the gym.

### Target User
- Busy adults who want efficient strength training
- Beginner to intermediate lifters by default, with an advanced path available
- People who want clear structure instead of custom programming
- Users who are not already fluent in HIT principles

### Product Positioning
The app follows one shared training philosophy across all programs:
- low volume
- hard working sets
- progressive overload
- recovery-aware progression
- minimal time investment

Program names and user-facing language should stay structural and generic. Do not reference specific bodybuilders, coaches, or branded methods in user-facing copy.

## 2. MVP Scope

### Core Features
- Guided workout flow
- Strict predefined programs
- Logbook and exercise history
- Rest timer
- Advisory recovery guidance
- AI post-workout insight
- Offline-first workout logging and sync

### Explicit Non-Goals
- Custom workouts
- Custom exercise editing
- Social features
- Gamification
- Wearables
- AI chat coach
- Admin tooling for remote program management

## 3. Product Rules

### Core Training Rules
- One working set per exercise
- Fixed exercise list per workout template
- Users cannot add or remove exercises in MVP
- Weight and reps are required to complete a set
- Failure is encouraged and logged, but not required for completion
- Warm-up sets are instructional only and are not logged

### Scheduling Model
- Programs are sequence-based, not calendar-based
- Availability means intended weekly training cadence, not fixed weekdays
- The home screen shows the next workout in the assigned sequence
- Missed days do not skip workouts automatically
- Completing a workout advances the sequence
- Discarding an in-progress workout does not advance the sequence

### Recovery Model
- Recovery guidance is advisory only
- Each workout template defines a fixed recovery window in days
- The app may recommend resting before the next workout, but the user can still train

## 4. Onboarding

### Goals
- Educate the user on the method
- Collect only the inputs that affect product behavior
- Auto-assign a starting program

### Inputs
- Training experience: `Beginner | Intermediate | Advanced`
- Goal: `Build muscle | Stay fit | Lose weight`
- Availability: `2 | 3 days per week`
- Familiar with HIT: `Yes | No`

### Input Meanings
- Goal affects messaging only, not program assignment
- Availability drives intended cadence and program assignment
- Familiar with HIT controls education only, not program assignment

### Education Step
If the user is not familiar with HIT, show a short 60-90 second intro that explains:
- one working set
- training hard
- low frequency
- progression over time

### Assignment Flow
- The app auto-assigns a program immediately based on onboarding inputs
- After assignment, show a dedicated Program Intro screen
- Program Intro must stay short and high-level
- Manual program switches later in the app also show the normal Program Intro

### Program Intro Must Explain
- the assigned program
- why it was assigned
- that workouts rotate in sequence
- that progression is based on one logged working set
- that recovery guidance is advisory
- that programs can be switched later

## 5. Program Assignment

Program assignment is deterministic.

### Default Mapping
- `2 days/week` -> `Alternating Full Body`
- `3 days/week + Beginner` -> `Alternating Full Body`
- `3 days/week + Intermediate` -> `Push / Pull / Legs`
- `3 days/week + Advanced` -> `Upper / Lower`

### Assignment Rules
- If availability and experience conflict, availability wins
- Onboarding assignment is immediate
- Users may later switch programs manually

## 6. Program Catalog

### Supported Template Families
- Alternating Full Body
- Upper / Lower
- Push / Pull / Legs

### Excluded Template Families
- Classic body-part splits such as chest day, arm day, or back day

### Canonical Program Rule
Each supported template family has one canonical sequence in MVP.

Canonical program definitions live in app code, not in backend-managed content.

## 7. Canonical Program Design

Canonical templates are defined first by movement roles, then mapped to exact exercises later.

They should prioritize a few high-value roles instead of trying to directly checklist every muscle each session.

### Alternating Full Body
Sequence: `Full Body A -> Full Body B -> repeat`

Both templates include:
- 1 leg role
- 1 press role
- 1 pull role
- 1 shoulder role
- 1 biceps role
- 1 triceps role

Additional structure:
- One Full Body template also includes calves as an extra slot
- Full Body A and B differ by movement emphasis, not just by calf inclusion
- Full Body A uses:
  - quad-biased leg
  - horizontal press
  - horizontal pull
- Full Body B uses:
  - posterior-chain-biased leg
  - incline-or-vertical press
  - vertical pull

### Upper / Lower
Sequence: `Upper -> Lower -> repeat`

Upper includes exactly 5 roles:
- 1 press
- 1 pull
- 1 shoulder
- 1 biceps
- 1 triceps

Lower includes exactly 4 roles:
- 1 quad-biased role
- 1 posterior-chain-biased role
- 1 secondary leg isolation/support role
- 1 calf role

Lower includes no direct core work in MVP.

### Push / Pull / Legs
Sequence: `Push -> Pull -> Legs -> repeat`

Push includes exactly 4 roles:
- 1 chest-dominant press
- 1 shoulder-dominant press
- 1 shoulder isolation role
- 1 triceps role

Pull includes exactly 4 roles:
- 1 horizontal pull
- 1 vertical pull
- 1 upper-back or rear-delt support role
- 1 biceps role

Legs includes exactly 4 roles and shares the same structure as Lower:
- 1 quad-biased role
- 1 posterior-chain-biased role
- 1 secondary leg isolation/support role
- 1 calf role

## 8. Exercise and Rep-Range Rules

### Exercise Classification
Each exercise has an `exercise_category` used for training guidance:
- `upper`
- `leg`
- `calf`

This classification is distinct from `muscle_group`.

### Default Rep Ranges
- Calf exercises: `12-20`
- Other leg exercises: `8-15`
- Non-leg exercises: `6-10`

Rep ranges are guidance for progression, not strict validity rules.

### First-Time Exercise Flow
If the user has no history for an exercise:
- they choose their own starting working weight
- the app instructs them to choose a load they expect will take them near failure within the target rep range
- the logged result becomes the baseline for future guidance

## 9. Warm-Up Guidance

Warm-up sets are not logged.

The app may show instructional warm-up guidance before a working set:
- larger lifts: `1 set at 50%`, then `1 set at 75%` of working weight
- smaller lifts: `1 set at 50%` of working weight

When a next working weight recommendation exists, warm-up guidance should be based on that recommended weight.

## 10. Progression Guidance

Progression is advisory, not automatic.

After each working set, the app suggests a `load_recommendation`:
- `reduce`
- `keep`
- `increase`

### Rule
- below minimum reps -> `reduce`
- within range, including the top of the range -> `keep`
- above the range -> `increase`

### Important Constraints
- The user still chooses the next working weight
- Historical sets must keep the rep-range snapshot that applied when they were logged

## 11. Workout Flow

### Home Screen
If the user has an active in-progress session:
- show `Resume Workout`

Otherwise:
- show the next workout in the assigned program sequence
- show advisory recovery guidance
- show `Start Workout`
- show `Switch Program`

### Workout Screen
Per exercise, show:
- name
- short instruction
- warm-up guidance when relevant
- last performance
- weight input
- reps input
- `To failure` toggle

### Session Lifecycle
- At most one in-progress session per user
- In-progress sessions can be resumed
- In-progress sessions can be discarded
- Only completed sessions advance the next workout template

If a user discards an in-progress session:
- unfinished workout data is removed
- sequence position does not change

## 12. Program Switching

Program switching is a first-class user action and is available directly from Home.

### Switcher Rules
- Show all supported programs, not just the originally recommended one
- Each program includes a short explanatory line
- Switching resets the user to the first workout template of the new program
- Exercise history carries across programs by exercise

### Guardrail
If the user has an in-progress workout, they must:
- resume and finish it
- or discard it first

The app must not silently discard an active workout during a program switch.

## 13. Logbook

The logbook shows both raw history and lightweight interpretation.

### Per Exercise, Show
- last result
- best result
- latest structured load recommendation

### Best Result Rule
Best result is determined by:
- heaviest logged weight first
- if weight ties, higher reps wins

## 14. AI Insight

### Placement
Summary screen only, after a completed workout

### Comparison Basis
The AI compares:
- the current completed workout
- the previous completed session of the same workout template

### Output Rules
- maximum 2 sentences
- actionable only
- may discuss performance trends
- may discuss likely load direction
- may discuss recovery interpretation based on known workout history
- must not provide medical, nutrition, supplement, or form-coaching advice the app cannot observe
- must not contradict the app's structured load recommendation

## 15. Architecture and Tech

### Stack
- React Native with Expo
- Expo Router
- Supabase
- PostgreSQL
- Expo SQLite for local-first storage
- OpenAI API for post-workout insight

### Data Flow
User -> React Native app -> SQLite local store -> Supabase sync -> AI on summary only

### Key Principle
SQLite is the source of truth during workouts.

## 16. Data Model

### Canonical Program Definitions
Canonical program definitions live in app code, for example in `/constants/programs.ts`.

They include:
- `program_key`
- `template_family`
- ordered workout templates
- per-template recovery window
- ordered template exercises
- movement roles
- target rep ranges
- extra-slot flags when needed

### Persisted User and Workout Data

`users`
- `id`
- `email`
- `created_at`

`user_profiles`
- `id`
- `user_id`
- `experience_level`
- `goal`
- `availability`
- `familiar_with_hit`
- `assigned_program_key`
- `next_workout_template_key`

`exercises`
- `id`
- `name`
- `muscle_group`
- `exercise_category`
- `instructions`
- `default_warmup_type`

`workout_sessions`
- `id`
- `user_id`
- `program_key`
- `workout_template_key`
- `status` with values `in_progress | completed`
- `started_at`
- `finished_at`
- `synced`

`working_sets`
- `id`
- `session_id`
- `exercise_id`
- `movement_role`
- `weight`
- `reps`
- `to_failure`
- `target_reps_min`
- `target_reps_max`
- `load_recommendation`
- `created_at`

## 17. Offline-First Sync

### Local-First Behavior
- Save workout activity to SQLite immediately
- Workouts must be usable without internet

### Sync Conditions
- app is open
- internet is available

### Sync Behavior
- fetch unsynced sessions
- send them to Supabase
- mark them as synced

## 18. App Structure

### Navigation
- `/(onboarding)`
- `/program-intro`
- `/(tabs)/home`
- `/(tabs)/logbook`
- `/workout/[sessionId]`
- `/summary/[sessionId]`

### Suggested Project Structure
`/src/app`
`/src/components`
`/src/services`
`/src/storage`
`/src/hooks`
`/src/constants/programs.ts`

## 19. UX Principles

### Core Rule
Fast. Minimal. No thinking.

### UX Direction
- clean
- friendly
- direct
- low-friction

### Copy Style
Prefer concrete workout language over generic UI language.

Example:
- use `Finish workout`
- avoid `Submit`

## 20. MVP Roadmap

### Week 1
- project setup
- auth
- navigation

### Week 2
- onboarding
- deterministic program assignment
- program intro

### Week 3
- workout flow
- session lifecycle
- local storage

### Week 4
- logbook
- progression guidance

### Week 5
- AI summary insight

### Week 6
- offline sync
- program switching

## 21. Post-MVP Ideas
- exercise substitution
- custom plans with validation
- advanced analytics
- subscriptions
