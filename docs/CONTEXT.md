# HIT Workout App

This context defines the domain language for a guided high-intensity training app focused on efficient muscle-building workouts with strict progression and minimal planning overhead for the user.

## Language

**Availability**:
The user's intended number of training sessions per week under normal conditions.
_Avoid_: Schedule, training days, calendar

**Recovery Guidance**:
The app's recommendation for when a user is ready to perform the next workout in their program sequence.
_Avoid_: Lockout, mandatory rest, calendar rule

**Next Workout**:
The next workout template in the user's assigned program sequence.
_Avoid_: Today's workout, scheduled workout

**Program**:
An ordered sequence of workout templates assigned to a user.
_Avoid_: Schedule, split

**Workout Template**:
A predefined set of exercises performed as one unit within a program sequence.
_Avoid_: Session plan, day

**Template Family**:
The structural pattern a program uses to organize workout templates.
_Avoid_: Split, bro-split

**Training Philosophy**:
The app-level explanation of the principles that shape all programs in the product.
_Avoid_: Program subtitle, coach identity

**Working Set**:
The primary logged effort set for an exercise that counts toward progression.
_Avoid_: Warm-up, feeder set

**Failure Marker**:
The user's indication of whether a working set was taken to failure.
_Avoid_: Requirement, completion gate

**Warm-up Guidance**:
Instructional guidance for preparation sets performed before a working set.
_Avoid_: Logged set, progression set

**Target Rep Range**:
The intended repetition window that defines whether a working set is appropriately loaded.
_Avoid_: Goal reps, ideal reps

**Load Recommendation**:
The app's advisory suggestion for how the user should adjust working weight on the next session.
_Avoid_: Auto-load, prescribed weight

**Recovery Window**:
The default amount of rest a workout template recommends before the next training session.
_Avoid_: Readiness score, dynamic recovery

**Exercise Category**:
The classification used to determine default training guidance for an exercise.
_Avoid_: Muscle group, tag

**Canonical Sequence**:
The single predefined workout-template sequence used for a template family in MVP.
_Avoid_: Variant, option pack

**Program Assignment**:
The deterministic rule that maps onboarding inputs to a template family.
_Avoid_: Recommendation engine, personalization

**Program Switch**:
An explicit user action that changes the assigned program after onboarding.
_Avoid_: Re-onboarding only, locked assignment

**Program Intro**:
The screen that explains the assigned program immediately after onboarding assignment.
_Avoid_: Optional tooltip, hidden settings copy

**Exercise Slot**:
The fixed position of an exercise inside a workout template.
_Avoid_: Optional exercise, filler

**Movement Role**:
The training purpose an exercise slot serves inside a workout template.
_Avoid_: Exact exercise, equipment choice

**Coverage Bias**:
The degree to which a workout template prioritizes a few high-value roles instead of trying to directly cover every muscle every session.
_Avoid_: Muscle checklist, full coverage

**Movement Emphasis**:
The specific pattern variation a workout template uses within a shared movement role.
_Avoid_: Random variation, exercise swap

## Relationships

- **Availability** influences which **Program** is assigned to a user
- **Availability** does not bind a user to specific calendar days
- **Recovery Guidance** advises when a user should perform their **Next Workout**
- A **Program** defines an ordered sequence of **Next Workouts**
- A **Program** consists of one or more **Workout Templates**
- Completing a **Workout Template** advances the user to the next position in the **Program**
- A **Program** uses exactly one **Template Family**
- **Training Philosophy** applies across all **Programs**
- A **Workout Template** contains one **Working Set** per exercise in MVP
- A **Failure Marker** describes a **Working Set** but does not determine whether it counts as completed
- **Warm-up Guidance** may accompany an exercise, but only the **Working Set** is logged in MVP
- A **Working Set** is evaluated against a **Target Rep Range**
- A **Load Recommendation** is derived from the previous **Working Set** and its **Target Rep Range**
- A **Workout Template** defines one **Recovery Window**
- **Recovery Guidance** is derived from the **Recovery Window** of the completed **Workout Template**
- An exercise's **Exercise Category** determines its default **Target Rep Range**
- Each **Template Family** has one **Canonical Sequence** in MVP
- **Program Assignment** uses **Availability** and training experience to select a **Template Family**
- A **Program Switch** replaces the user's assigned program after onboarding
- A **Program Intro** follows onboarding assignment before normal app usage begins
- Each **Workout Template** has a fixed number of **Exercise Slots** in MVP
- Each **Exercise Slot** is defined first by a **Movement Role**
- Each **Workout Template** uses a **Coverage Bias** toward fewer high-value roles rather than exhaustive muscle-by-muscle coverage
- Templates within the same **Canonical Sequence** may vary by **Movement Emphasis** while keeping the same core roles

## Example dialogue

> **Dev:** "If a user says they are available 3 days per week, do we lock them to Monday, Wednesday, Friday?"
> **Domain expert:** "No. **Availability** tells us the intended training cadence, not fixed workout days."

> **Dev:** "If the app recommends two rest days, does that block the user from training?"
> **Domain expert:** "No. **Recovery Guidance** is advisory. The user can still start their **Next Workout**."

> **Dev:** "Is a Program just one workout repeated forever?"
> **Domain expert:** "No. A **Program** is a sequence of **Workout Templates** that the user rotates through."

> **Dev:** "Are body-part splits part of this product's training model?"
> **Domain expert:** "No. MVP **Template Families** are limited to Alternating Full Body, Upper / Lower, and Push / Pull / Legs."

> **Dev:** "Should each Program have its own philosophy subtitle?"
> **Domain expert:** "No. The **Training Philosophy** belongs to the app as a whole because all Programs follow the same HIT principles."

> **Dev:** "If the user doesn't reach failure, do we reject the set?"
> **Domain expert:** "No. The app encourages a **Failure Marker**, but a **Working Set** can still be completed without it."

> **Dev:** "Do warm-up sets appear in the logbook?"
> **Domain expert:** "No. **Warm-up Guidance** is instructional only. The user logs only the **Working Set**."

> **Dev:** "If a user gets far more reps than the target range, do we force the next weight?"
> **Domain expert:** "No. The app shows a **Load Recommendation**, but the user still chooses the next working weight."

> **Dev:** "If the user hits the top of the rep range exactly, do we increase the load?"
> **Domain expert:** "No. Hitting the top of the **Target Rep Range** still counts as stable performance. The **Load Recommendation** increases only when the user exceeds the range."

> **Dev:** "Does recovery guidance depend on dynamic fatigue analysis?"
> **Domain expert:** "No. In MVP, **Recovery Guidance** comes from the fixed **Recovery Window** attached to each **Workout Template**."

> **Dev:** "Are rep ranges strict rules?"
> **Domain expert:** "No. The **Target Rep Range** is guidance used for progression decisions, not a hard validity rule."

> **Dev:** "How do we set rep ranges across exercises?"
> **Domain expert:** "Use 8-15 for all leg exercises, 12-20 for calves, and 6-10 for everything else in MVP."

> **Dev:** "Can muscle group alone drive rep-range logic?"
> **Domain expert:** "No. Use an explicit **Exercise Category** so calves can be treated separately from other leg exercises."

> **Dev:** "Do we support multiple program variants per template family?"
> **Domain expert:** "No. Each **Template Family** has one **Canonical Sequence** in MVP."

> **Dev:** "How does the app choose a template family?"
> **Domain expert:** "Use a deterministic **Program Assignment** rule based on **Availability** and training experience."

> **Dev:** "Is the assigned program fixed after onboarding?"
> **Domain expert:** "No. The user may perform a **Program Switch** whenever they want in MVP."

> **Dev:** "Where does the user enter a new program after switching?"
> **Domain expert:** "At the first workout template of the new program sequence."

> **Dev:** "Can the user switch programs while a session is in progress?"
> **Domain expert:** "Only after resolving the in-progress session by resuming/finishing it or discarding it first."

> **Dev:** "Does exercise history reset when the user switches programs?"
> **Domain expert:** "No. Exercise history carries across program switches wherever the same exercise reappears."

> **Dev:** "Does onboarding end with a recommendation to confirm, or an immediate assignment?"
> **Domain expert:** "Use immediate auto-assignment in MVP. Program switching is a later explicit action."

> **Dev:** "Does the app go straight to home after assignment?"
> **Domain expert:** "No. Show a **Program Intro** screen first so the user understands the assigned plan."

> **Dev:** "How detailed should Program Intro be?"
> **Domain expert:** "Keep **Program Intro** minimal: explain the assigned program, why it was assigned, how sequence/progression/recovery work at a high level, and note that switching is possible later."

> **Dev:** "Where does program switching live in the app?"
> **Domain expert:** "Expose **Program Switch** directly from Home."

> **Dev:** "Does program switching show only recommended options?"
> **Domain expert:** "No. Program switching shows all supported programs in MVP."

> **Dev:** "Does the program switcher show names only?"
> **Domain expert:** "No. Each program in the switcher includes a short explanatory line."

> **Dev:** "Does program switching show a shortened intro or the normal one?"
> **Domain expert:** "Show the normal **Program Intro** after every program switch."

> **Dev:** "What if experience and availability conflict?"
> **Domain expert:** "Let **Availability** win. An advanced user with only 2-3 sessions per week still gets Alternating Full Body."

> **Dev:** "Does Goal change the actual program?"
> **Domain expert:** "No. In MVP, Goal affects messaging only and does not change Program Assignment or progression rules."

> **Dev:** "Does familiarity with HIT change the assigned program?"
> **Domain expert:** "No. In MVP, familiarity with HIT only controls onboarding education and does not affect Program Assignment."

> **Dev:** "Do workout templates have flexible exercise counts?"
> **Domain expert:** "No. Each canonical workout template has fixed **Exercise Slots** in MVP."

> **Dev:** "Do all template families use the same exercise count?"
> **Domain expert:** "No. Exercise-slot counts are fixed per canonical template: Full Body 5, Upper 5, Lower 4, Push 4, Pull 4, Legs 4."

> **Dev:** "Should we define templates by exact exercises immediately?"
> **Domain expert:** "No. Define the canonical structure by **Movement Role** first, then map exact exercises later."

> **Dev:** "Should each template try to cover every muscle directly?"
> **Domain expert:** "No. Use a **Coverage Bias** toward fewer high-value movement roles instead of a muscle checklist."

> **Dev:** "Do both Full Body templates include direct leg work?"
> **Domain expert:** "Yes. Each Full Body template includes one leg movement role."

> **Dev:** "Do press and pull alternate across Full Body A/B?"
> **Domain expert:** "No. Each Full Body template includes both one press role and one pull role."

> **Dev:** "Does Full Body keep the 5-slot rule if it must include both biceps and triceps?"
> **Domain expert:** "No. Full Body is an explicit exception: it includes separate biceps and triceps roles even though that expands the template beyond 5 exercises."

> **Dev:** "If calves appear in Full Body, do they replace another role?"
> **Domain expert:** "No. Calves are an added slot in one Full Body template rather than a substitution."

> **Dev:** "Should Full Body A and B differ only by calf work?"
> **Domain expert:** "No. Full Body A and B should also vary by **Movement Emphasis** within shared roles."

> **Dev:** "How should the Full Body leg role vary across A and B?"
> **Domain expert:** "Alternate the leg **Movement Emphasis**: one template is quad-biased and the other is posterior-chain-biased."

> **Dev:** "Should Full Body press and pull repeat the same plane across A and B?"
> **Domain expert:** "No. Full Body A uses horizontal press/pull emphasis, and Full Body B uses incline-or-vertical press and vertical pull emphasis."

> **Dev:** "Can shoulder work be absorbed into pressing on one Full Body day?"
> **Domain expert:** "No. Both Full Body templates keep a dedicated direct shoulder role."

> **Dev:** "Does Upper / Lower rely on compound pressing and pulling for arm work?"
> **Domain expert:** "No. The Upper template also includes separate direct biceps and triceps roles."

> **Dev:** "Should Upper break the count rule to fit more chest or back work?"
> **Domain expert:** "No. Upper stays at exactly five roles: press, pull, shoulder, biceps, triceps."

> **Dev:** "Does Lower include direct core work in MVP?"
> **Domain expert:** "No. Lower stays focused on leg and calf roles only."

> **Dev:** "Does the Lower template cover both quad and posterior-chain work?"
> **Domain expert:** "Yes. Lower always includes both quad-biased and posterior-chain-biased roles."

> **Dev:** "What fills the final non-calf slot in Lower?"
> **Domain expert:** "Use a secondary leg isolation/support role."

> **Dev:** "Does Push / Pull / Legs reuse the same direct-arm logic across every day?"
> **Domain expert:** "No. Push / Pull / Legs stays split-true: Push includes triceps but not biceps, Pull includes biceps but not triceps, and Legs stays focused on leg and calf roles."

> **Dev:** "How should the two Push press roles differ?"
> **Domain expert:** "Use one chest-dominant press role and one shoulder-dominant press role."

> **Dev:** "How should the two Pull roles differ?"
> **Domain expert:** "Use one horizontal pull role and one vertical pull role."

> **Dev:** "Does Legs differ structurally from Lower?"
> **Domain expert:** "No. Legs and Lower share the same role structure in MVP."

> **Dev:** "Where do canonical program definitions live in MVP?"
> **Domain expert:** "In app code. Supabase stores user state and workout history, not the canonical program catalog."

> **Dev:** "What does assigned program persist if programs live in app code?"
> **Domain expert:** "Persist a stable app-defined program key, not a backend-generated ID."

> **Dev:** "Should historical sets rely on current app definitions for target rep ranges?"
> **Domain expert:** "No. Each logged working set stores its own target rep range snapshot."

> **Dev:** "Is load recommendation stored as free text?"
> **Domain expert:** "No. Persist it as a structured value such as reduce, keep, or increase."

> **Dev:** "How does the app know the next workout before a session starts?"
> **Domain expert:** "Persist the next workout template key directly on the user profile."

> **Dev:** "When does the next workout advance?"
> **Domain expert:** "Only when a workout session is explicitly finished, not when it is started."

> **Dev:** "What happens if a workout is started but not finished?"
> **Domain expert:** "The user may have one active in-progress session that can be resumed."

> **Dev:** "How many session states do we support in MVP?"
> **Domain expert:** "Two only: in_progress and completed."

> **Dev:** "Can the user back out of an in-progress session?"
> **Domain expert:** "Yes. They may discard it entirely, which removes its unfinished data and does not advance the sequence."

> **Dev:** "What should the AI compare a completed workout against?"
> **Domain expert:** "Compare it to the previous completed session of the same workout template."

> **Dev:** "What is the AI allowed to talk about?"
> **Domain expert:** "Only performance trends, likely load direction, and recovery interpretation based on template-specific workout history."

> **Dev:** "Can the AI contradict the app's structured load recommendation?"
> **Domain expert:** "No. The structured load recommendation is authoritative; the AI may only explain or contextualize it."

> **Dev:** "Should the logbook show only raw history?"
> **Domain expert:** "No. The logbook shows raw results plus lightweight interpretation such as the latest structured recommendation."

> **Dev:** "How do we decide the best result for an exercise?"
> **Domain expert:** "Use the heaviest successfully logged weight; if weight ties, the higher rep count wins."

## Flagged ambiguities

- "availability" was initially close to "schedule" — resolved: it means intended weekly cadence, not fixed weekdays.
- "rest" could have meant either a hard rule or a suggestion — resolved: **Recovery Guidance** is advisory in MVP.
- "program" was close to "split" — resolved: a **Program** is the full ordered sequence, while a **Workout Template** is one unit inside it.
- "split" was too broad — resolved: use **Template Family** for the allowed structural patterns, and exclude classic body-part splits from MVP.
- "program branding" was drifting into philosophy and endorsement language — resolved: keep **Program** names structural and place HIT messaging in a shared **Training Philosophy** layer.
- "to failure" could have become a hard validation rule — resolved: it is encouraged and logged via a **Failure Marker**, but not enforced as a completion requirement.
- "warm-up sets" could have become tracked workout data — resolved: keep them as **Warm-up Guidance** only, with progression based on the logged **Working Set**.
- "progression" could have become automatic load prescription — resolved: the app gives a **Load Recommendation**, but the user chooses the next working weight.
- "top of range" could have triggered an increase — resolved: it still counts as `keep`; only exceeding the **Target Rep Range** triggers an `increase` recommendation.
- "recovery" could have drifted into dynamic readiness scoring — resolved: use a fixed **Recovery Window** per **Workout Template** in MVP.
- "rep range" could have sounded like a hard rule — resolved: the **Target Rep Range** is advisory guidance.
- "legs" was initially too broad for rep ranges — resolved: all leg exercises use 8-15, calves use 12-20, and all other exercises use 6-10 in MVP.
- "muscle group" could have been overloaded for progression logic — resolved: use **Exercise Category** to drive rep-range behavior.
- "program choice" could have expanded into many variants — resolved: each **Template Family** has one **Canonical Sequence** in MVP.
- "program assignment" could have felt personalized or opaque — resolved: use a deterministic **Program Assignment** rule from onboarding inputs.
- "program assignment" could have been treated as permanent — resolved: users may change programs freely via **Program Switch**.
- "program switching" could have tried to map users into the middle of a new sequence — resolved: every **Program Switch** restarts at the first template of the selected program.
- "program switching" could have silently discarded active workout data — resolved: an in-progress session must be completed or explicitly discarded before switching.
- "program switching" could have reset exercise history — resolved: historical exercise data carries across programs by exercise.
- "onboarding assignment" could have become a confirm-or-edit flow — resolved: onboarding auto-assigns immediately in MVP.
- "assignment handoff" could have been abrupt — resolved: show a **Program Intro** screen after auto-assignment.
- "Program Intro" could have become a long reading step — resolved: keep it minimal and high-level.
- "program switching" could have been hidden in settings — resolved: expose it directly from Home.
- "program switching" could have been constrained by onboarding recommendations — resolved: show all supported programs.
- "program switching" could have lacked enough context to choose — resolved: show each program with a short explanatory line.
- "post-switch onboarding" could have diverged from first assignment — resolved: show the normal **Program Intro** after every program switch.
- "experience" could have overridden practical cadence — resolved: when inputs conflict, **Availability** wins in **Program Assignment**.
- "goal" could have implied different programming — resolved: in MVP it affects copy only, not the actual program design.
- "activity level" appeared in onboarding without changing any domain decision — resolved: remove it from MVP.
- "age" appeared in onboarding without changing any domain decision — resolved: remove it from MVP.
- "familiar with HIT" could have been mistaken for a programming input — resolved: it is an onboarding education flag only.
- "exercise count" could have stayed flexible — resolved: each canonical workout template has fixed **Exercise Slots** in MVP.
- "all workouts have 5 exercises" would have been false symmetry — resolved: fixed exercise counts vary by canonical template.
- "template design" could have jumped straight to named lifts — resolved: define structure by **Movement Role** first.
- "full-body coverage" could have turned into a checklist — resolved: use a **Coverage Bias** toward fewer high-value roles.
- "Alternating Full Body" could have underdosed legs — resolved: both Full Body templates include one direct leg movement role.
- "press/pull balance" could have alternated too aggressively in Full Body — resolved: each Full Body template includes both one press role and one pull role.
- "fixed exercise counts" needed one exception — resolved: Full Body templates may exceed 5 slots so they can include separate biceps and triceps roles.
- "calves in Full Body" could have forced a substitution — resolved: calves are an added slot in one Full Body template.
- "A/B rotation" could have been superficial — resolved: Full Body A and B differ by **Movement Emphasis**, not just by calf inclusion.
- "Full Body leg work" could have repeated the same pattern every time — resolved: Full Body alternates quad-biased and posterior-chain-biased leg emphasis.
- "Full Body upper-body work" could have repeated the same plane every time — resolved: Full Body alternates horizontal press/pull with incline-or-vertical press and vertical pull emphasis.
- "shoulder work" could have been treated as incidental pressing volume — resolved: both Full Body templates include a dedicated shoulder role.
- "Upper template arm work" could have been left to compounds — resolved: the Upper template includes dedicated biceps and triceps roles.
- "Upper template volume" could have expanded beyond its identity — resolved: Upper stays at exactly five roles.
- "Lower template scope" could have expanded into core work — resolved: Lower stays focused on leg and calf roles only.
- "Lower balance" could have overfavored one lower-body pattern — resolved: Lower always includes both quad-biased and posterior-chain-biased roles.
- "Lower fourth slot" could have stayed vague — resolved: it is a secondary leg isolation/support role.
- "Push / Pull / Legs" could have blurred into Upper/Lower — resolved: it stays split-true by role ownership.
- "Push" could have doubled down on chest too heavily — resolved: its two press roles split between chest-dominant and shoulder-dominant emphasis.
- "Pull" could have repeated one pull plane only — resolved: it includes both horizontal and vertical pull roles.
- "Legs" could have diverged needlessly from Lower — resolved: Legs and Lower share the same role structure in MVP.
- "canonical program storage" could have moved to backend content management too early — resolved: canonical program definitions live in app code in MVP.
- "assigned program" could have implied backend-owned content IDs — resolved: persist stable app-defined program keys.
- "historical rep ranges" could have depended on current app code — resolved: each logged working set stores a target rep range snapshot.
- "load recommendation" could have been stored as prose — resolved: persist it as a structured value.
- "next workout" could have been recalculated indirectly from history — resolved: persist the next workout template key on the user profile.
- "sequence advancement" could have happened on session start — resolved: advance only on explicit workout completion.
- "incomplete sessions" could have been discarded or duplicated — resolved: allow one active resumable session per user.
- "session lifecycle" could have expanded into many states — resolved: use only in_progress and completed in MVP.
- "discarding a workout" could have affected program progression — resolved: discarding removes unfinished session data and does not advance the sequence.
- "AI comparison" could have used unrelated prior sessions — resolved: compare against the previous completed session of the same workout template.
- "AI scope" could have expanded into unsupported coaching domains — resolved: keep it to performance, load direction, and recovery interpretation from known workout data.
- "AI advice" could have conflicted with deterministic progression rules — resolved: AI may explain the structured load recommendation, but not contradict it.
- "logbook" could have become raw data only — resolved: show raw results plus lightweight structured interpretation.
- "best result" could have required a derived scoring formula — resolved: use heaviest weight first, with reps as the tiebreaker.
