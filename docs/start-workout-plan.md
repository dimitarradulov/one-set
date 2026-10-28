# Start workout planning

Status: approved on 2026-10-28 after the planning interview. Published as [issue #34](https://github.com/dimitarradulov/one-set/issues/34), labelled `ready-for-agent`. No product code changed during planning or spec publication.

## Existing foundations

- Authentication, account-scoped completed setup, units, selected program and a stable first cycle identity exist. Reuse that cycle rather than creating another cycle when starting a session. See [account setup](account-setup.md).
- The bundled and refreshable offline catalog supplies ordered workout slots, exercise identities, rep targets, instructions, warmup guidance and rest defaults. See [catalog publishing](catalog-publishing.md).
- Program overview, read-only workout preview, exercise guidance screens and the Start workout button exist.
- Server schema includes cycles, sessions, captured prescriptions, sets, completion marks and cycle-week membership boundaries. Schema availability does not establish that recording commands exist. See [database design](database/README.md).

## Missing capabilities

| Capability | Current evidence and required work |
| --- | --- |
| Start action | [Workout preview](../OneSet/Features/Programs/WorkoutTemplatePreviewScreen.swift) has an empty Start workout action. No active-session screen is connected. |
| Occurrence identity | [Overview](../OneSet/Features/Programs/ProgramOverviewScreen.swift) holds the selected week locally but passes only the template when opening preview. [Routes](../OneSet/Features/Onboarding/OnboardingRoute.swift) omit the week. Carry cycle + training week + workout identity through start. |
| Durable training state | App persistence currently covers onboarding. Session/set values, captured prescriptions, account-scoped workout repository, local migrations, atomic saves and restart recovery remain to be implemented. |
| Session lifecycle | Implement one active session, duplicate-start protection, resume, draft inputs, completed sets, finish and confirmed discard. Preserve session content through catalog changes. |
| Training progress | Completion marks, current training week and next-workout selection need app integration and finish commands. The overview currently renders templates rather than recorded occurrence progress. |
| Recording and guidance | Weight/reps entry, previous-performance lookup, progression suggestions, calculated warmup loads, rest deadlines and timer reconstruction need implementation. Existing text guidance can be reused. |
| Server recording and restoration | Worker source implements catalog and account setup; session sync, complete account bootstrap/history restoration and related owned mutations remain proposals. Durable pending uploads and retry ordering need implementation on the device. |
| Access | Trial is mocked. Verified subscription access and its cached offline validity limit are absent. Authentication alone does not satisfy the requirement for new-session access. |
| Supporting training features | Exercise replacement and remembered choices, real recorded-performance screens, video playback/downloads, rest notifications and history management remain unfinished. They need explicit milestone placement. |

## Dependency assessment

A screen prototype can be built now. A usable recording milestone needs durable local session state and the start/save/resume/finish/discard lifecycle as part of its implementation. These are work to include, rather than reasons the screen cannot be developed.

The user approved durable device-local recording first, with remote sync and purchases following later. Until those are implemented, recording is device-local and access needs a development-only substitute; this does not constitute the complete launch behavior.

Videos can retain the currently approved placeholder during development. New-cycle management, program switching, full history editing/deletion and replacement can be sequenced separately if the interim scope is explicit. Missing videos must never prevent recording.

## Confirmed decisions

1. Start workout opens active recording directly from the existing preview. Build a usable start, record and finish flow, including resume and confirmed discard.
2. Deliver reliable device-local recording first. Workouts survive app restarts. Add automatic uploads to the account's server database and real subscriptions afterward; the launch access requirement remains unchanged. The user clarified that “online backup” means saving to the online database, rather than a separate backup service.
3. Only the next unfinished workout in week/day order can start. Other days remain available for browsing. Finishing every required day opens the next training week; already completed days cannot start again in this milestone.
4. Users can leave active recording and browse the app without ending the session. Provide a clear Resume workout action. Relaunch returns to the unfinished session. Finish or confirmed discard ends it.
5. Show previous performance beside empty weight/reps inputs. Do not automatically fill today's entries from past results.
6. Include weight/reps entry, previous performance, exercise instructions, rest countdown, finish summary and an optional session note. Defer exercise replacement, actual exercise videos, background rest notifications and editing historical workouts. Existing launch requirements for these features remain in force for later milestones.
7. During an active session, allow correction of completed-set weight/reps and unmarking a set. Save corrections locally; changing numbers does not restart rest.
8. Use one rest countdown. Completing another set replaces it with a fresh countdown for that exercise. Allow adjustment and skip.
9. Leave the History tab placeholder in this milestone. A read-only workout history screen is not required yet. The user will not use the app for actual training until the whole system is complete; local-only recording is an implementation/testing stage, not a personal-use release.
10. Block explicit sign-out while a session is active. Explain that the user must finish or discard first; do not automatically end or discard the workout. Saved workouts remain account-scoped on the device after sign-out and are visible only to the same signed-in account. Server upload and broader account-transition behavior still need completion before actual use.

## Existing requirements carried forward

- One working set per exercise, entered as total external weight and reps; preserve the entered unit. Exercises can be completed in any order within the active workout.
- Follow the compact scrollable exercise-row pattern in the design document. Guidance expands on request. Detailed visual treatment remains implementation work.
- Warmups remain guidance rather than logged sets. Never invent a starting weight. Use the approved previous-performance fallback and clean-rep progression rules when results exist; otherwise show an honest empty state.
- Store the session's captured instructions and exercise order so later catalog updates cannot change a started workout.
- Show successful saves only after durable local commit. A failed write retains input, explains the failure and offers retry; it must not mark a set or workout successfully saved.
- Finish can save a partial workout, showing completed/total exercises. An attempt with zero completed sets offers confirmed discard rather than recording an empty completed workout. Notes belong to the finished session.
- Leaving, backgrounding or closing the app does not finish. Rest uses a saved deadline so time continues while the app is closed. Finishing or discarding ends active rest.
- Completing an occurrence advances progress exactly once, including partial finishes. Discard does not advance. Weeks can continue beyond the recommended eight.
- Authentication expiry does not interrupt active local recording. Explicit sign-out is blocked as agreed above.

## Proposed implementation order

1. Build account-scoped durable workout storage and session/occurrence values, using the existing cycle identity and catalog keys. Include schema migrations, captured prescriptions, drafts, completed sets, finish timestamps, notes, local completion marks and rest deadlines.
2. Implement and verify start/save/complete/correct/unmark/finish/discard commands and restart recovery. Keep the active-session owner outside individual screen lifetimes. Repeated Start must resume the existing session rather than create duplicates.
3. Connect overview and preview to cycle/week/day identity, ordered start eligibility, completion marks and Resume workout. Prevent overlapping starts and active-session sign-out.
4. Build active recording and finish screens, including empty previous performance, recorded previous results, expandable guidance, countdown, partial finish, optional note and storage-error states.
5. Validate durability, account isolation, progress and navigation with automated checks and simulator inspection. The first milestone ends here; it does not claim server recovery or paid access works.
6. Follow with account database upload/restoration and real entitlement integration, then the remaining launch features, including full history, replacements, video support and notifications. Agree their detailed ordering separately.

## Completion checks for the first milestone

- Start Week 1 Day 1; another tap cannot create another active session. Other days can be previewed but cannot start.
- Enter draft values, complete exercises out of order, correct a result and unmark one. Relaunch and recover the exact saved state.
- Background during rest, reopen and see the correct remaining time. A new completion replaces the countdown; a numerical correction does not restart it.
- Leave recording, browse and resume. Relaunch restores active recording. Sign-out remains blocked until finish or confirmed discard.
- Finish partial work with an optional note. Preserve results, mark the day once and enable the next workout. Finishing all required days advances the week.
- Discard with confirmation, preserve unrelated saved workouts and leave progress unchanged. Finishing with no completed sets cannot create an empty completion.
- Simulated storage failure cannot produce successful-save UI or advance progress. Another account cannot read saved workouts.
- Run the full validation suite for shared models/persistence changes and inspect simulator screenshots for the new visible states, following [validation guidance](agents/validation.md).

## Planning closeout

The user confirmed shared understanding and approved publishing the specification. [Issue #34](https://github.com/dimitarradulov/one-set/issues/34) contains the implementation spec and testing decisions. This turn publishes the spec; it does not implement the feature. No new domain term or hard-to-reverse architectural decision was introduced, so the glossary and ADRs remain unchanged. Continue any further interview in plain language as requested by the user.

## Sources and verification

This audit compares the current working tree with [requirements](requirements.md), [domain vocabulary](../GLOSSARY.md), [design proposals](../DESIGN.md), [iOS architecture](agents/architecture.md), [API contracts](api-contracts.md), and [sync and recovery](sync-and-recovery.md). Existing uncommitted changes in requirements and design were read and left untouched. Code and documentation inspection only; no build, simulator run or live infrastructure verification was performed.
