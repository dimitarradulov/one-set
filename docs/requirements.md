# Product and requirements

Status: implementation baseline from the approved interview. Items explicitly called “design assumption” are concrete proposals to validate during implementation, not additional founder commitments. No application implementation has been tested; the proposed schema has passed disposable SQL/query checks. The current database design and API contracts reflect the later simplification decisions.

## Purpose and boundaries

OneSet helps a lifter select a curated HIT program, perform it without phone friction, and retrieve trustworthy past performance. The founder supplies programs and exercise videos. The app targets people familiar with gym movements. The supplied library defines one working set per exercise after warmups, exercise-specific technical/momentary failure, and double progression.

Priority comes from the founder's program library and product decisions. Earlier TrainWise user reports and competitor desk research informed reliability priorities but did not establish market prevalence or add requirements. The accepted scope is recorded here.

## Functional requirements

| ID | Requirement and acceptance criteria |
| --- | --- |
| FR-01 | Account-first Variant A onboarding: welcome with Apple, Google, and email account actions plus Log in, then kg/lb and 2/3/4/5-day preference, program selection, seven-day trial offer, overview. There is no separate account-choice screen. Previously registered users restore existing state through Log in; no accidental reset through onboarding. |
| FR-02 | Browse all ten gym-only programs, showing frequency and workout previews. Frequency filters prioritize matching programs without hiding access to others. |
| FR-03 | Starting a program creates/resumes enrollment and a cycle linked directly to the program. Eight training weeks recommended; training weeks are rotations, not calendar weeks. |
| FR-04 | Overview displays week selectors and ordered Day 1/Day 2 cards. Each occurrence has its own completion state. Missing days does not advance the sequence. |
| FR-05 | Open a downloaded workout offline; draft inputs, completed sets, instructions, previous results and timer state survive app interruption. Entering data never waits for a network response. |
| FR-06 | One working set per exercise. Scrollable compact rows display previous result, inputs, completion control and a small progression line. Guidance and videos expand on request. Warmups are not logged. |
| FR-07 | Warmups show percentages of today's planned working weight and calculated loads when known. Use the library's ranges, without a mandatory calculator questionnaire. Never fabricate a working weight when no prior result exists. |
| FR-08 | Record total external weight as decimal in kg/lb. Two 20 kg dumbbells = 40 kg; one 20 kg dumbbell = 20 kg. Unilateral reps are entered once and interpreted per side. No left/right fields. |
| FR-09 | All exercises record weight and reps. Powerhouse uses Dumbbell Wrist Curl (12–20 reps) and Dumbbell Shrug (8–12 reps) in place of the former non-rep exercises. |
| FR-10 | Previous result prefers the same actual exercise in the same program workout across cycles, then falls back to the latest completed result elsewhere with a label. Unfinished draft values never appear as completed performance. |
| FR-11 | At the upper rep target, show a short suggestion to increase by the smallest practical increment; otherwise retain load and aim for more clean reps. Actual load remains editable. No invented kilogram jump, automatic deload, or mandatory effort questionnaire. Technique cannot be inferred from numbers; guidance states the clean-rep condition. |
| FR-12 | User-initiated replacement opens the supplied searchable exercise library. Scope: this workout only / remember for this program. No unsolicited recommendations. Log actual exercise identity and preserve separate historical results. |
| FR-13 | Remember optional exercise notes and rest preferences. Historical session notes/prescription copies remain stable after later preference edits. Optional workout note is collapsed on finish. |
| FR-14 | Completing a set starts rest automatically: 180 seconds large compound, 150 moderate compound, 120 isolation. Timer can be adjusted/skipped, reconstructed after restart, and optionally notify in background. Notification denial does not block training. |
| FR-15 | Exercises may be logged out of order. Explicit Finish saves completed work and shows e.g. Completed · 5/7. Unperformed exercises remain distinguishable. Leaving the app does not finish. Design assumption: finishing with zero completed sets offers discard rather than counting an empty workout. |
| FR-16 | Only one active workout intended. Program switch/new cycle is blocked until the current session is finished or discarded. Discard requires confirmation. Concurrent training on multiple devices is outside the current scope. |
| FR-17 | Switching back resumes previous cycle and completion marks. Start a new cycle resets occurrence marks, preserves history and carries compatible preferences. Template updates apply to future sessions in any cycle; started and completed sessions keep their captured content. |
| FR-18 | History is chronological; session detail exposes sets, notes and duration; exercise detail exposes past results. Edits update previous-performance/progression calculations. Charts deferred. |
| FR-19 | Completed-session deletion is online-only, confirmed, hard deletion, with no recovery UI. Coordinate deletion with pending uploads on the training device. Discarding an unfinished local session works offline. |
| FR-20 | Opening a workout on Wi-Fi starts downloads for its current exercise videos. Merely opening the overview does not. Cached clips work offline; missing clips show unavailability without blocking logging. Online playback is allowed on cellular. |
| FR-21 | R2 video objects are private; Worker verifies authorization before serving protected media. No DRM promise. Database object references are not access controls. |
| FR-22 | Seven-day trial followed by intended $4.89/month; show actual localized store terms and eligibility. Restore/manage subscription accessible. Users without access can preview programs and read history; starting new sessions requires entitlement. |
| FR-23 | Offline starts allowed until the last verified entitlement expiration. Beyond that, renewal must be checked online. A previously started session can always finish locally and later sync. Server must not reject historical workout data merely because a subscription has since expired. |
| FR-24 | Credential expiration/revocation never interrupts active training. Refresh silently where possible; if reauthentication is required, prompt after local workout finish and resume sync afterward. No promise that credentials themselves never expire. |
| FR-25 | Drafts and completed data save locally before success UI; automatic sync uses explicit saved-on-device versus synced states. Target one training device at a time; restoring synced history on a replacement device remains supported. |
| FR-26 | Content maintenance is a documented validated file-import/video-upload process. No admin app. |

## Non-functional requirements

| ID | Acceptance target / constraint |
| --- | --- |
| NF-01 | Initial 50 active users. 50:1 read/write is an estimate, not a measured capacity target; autosave/sync may change it. |
| NF-02 | Input feedback and durable local set-save confirmation ≤100 ms at p95 on supported devices. Measure event-to-commit and commit-to-render separately. If a write fails, never show a successful save. |
| NF-03 | Downloaded video time-to-first-frame ≤1 second. Proposed online benchmark: p95 ≤2 seconds at ≥10 Mbps, ≤100 ms network RTT, cache warm, reference short clip; cold-cache separately reported. This online target is a design assumption requiring measurement. |
| NF-04 | Account-confirmed records survive device replacement. Offline unsynced records cannot be recovered after destruction/loss of that device. Retrying never duplicates a set or advances progress twice. |
| NF-05 | High durability is the priority, but Neon Free plus conditional daily backups does not guarantee zero loss across every disaster. Explicit launch risk acceptance required if recovery cannot fit the no-cost condition. |
| NF-06 | Workout completion may sync with delay; local finish must remain usable without waiting for the server. No backend latency SLA has been promised. |
| NF-07 | Secure per-user authorization on every operation; server derives owner from verified identity. No database/service credentials shipped to the app. Protected user data never cached publicly. |
| NF-08 | Costs ideally $0, target $5–10/month. Neon Free initially. Backups may add no cost without renewed approval; alerts are not equivalent to vendor spending caps. |
| NF-09 | Proposed accessibility baseline: Dynamic Type, VoiceOver labels, visible units, touch targets, non-color-only completion/sync status and reduced-motion support. Supported iOS/device floor to be checked against chosen SDKs. |
| NF-10 | PostHog records onboarding completion, program choice, trial conversion, workout start/finish and sync failures. No weights/reps/free text, credentials, video tokens or replay. Analytics never blocks training. |

## Launch exclusions

Nutrition/supplements, social feeds, challenges, body tracking, AI coaching, custom plans/exercises, charts, watch support, CSV export, user-facing soft delete/recovery, warmup logs, additional working sets, structured forced/drop/rest-pause sets, admin app, mandatory readiness or effort input.

## Edge cases requiring explicit handling

- Same lift in different workout positions: show appropriate previous context, never transfer a replacement's load blindly.
- Switching units: preserve original entry/unit; convert for display without rewriting historic values repeatedly.
- Changing exercise after logging: require explicit action; do not relabel an existing completed set as another exercise. Design assumption: amend the historical set through edit flow or clear/re-enter the current result with confirmation.
- Replacement prescription mismatch: supported exercises carry their own rep targets and instructions covering technique and when to stop the set; apply the selected movement's defaults. Content compatibility rules are an implementation gate.
- Forgotten timer with denied notifications: reconstruct elapsed/remaining time correctly, no retroactive notification spam.
- Retried session uploads must not duplicate sets or advance completion twice.
- Deleting an older session: proposed behavior leaves already advanced sequence in place; it changes history/progression without undoing future training.

## Key user flows

**First use:** Welcome → Continue with Apple, Continue with Google, or Continue with email → kg/lb and 2–5 training days → browse all ten programs, with frequency matches first → select program → seven-day trial offer → program overview. The account actions and Log in are on Welcome; there is no separate account-choice screen. This focused sequence is the approved onboarding structure; other visual details remain open. The trial begins only after successful subscription enrollment. Dismissing the offer leaves program previews and existing history available. Returning users restore their existing state through Log in. Interrupted onboarding retains progress. Ask for notification permission when rest alerts are enabled, not during initial onboarding.

**Program and workout:** The overview shows training weeks and ordered Day cards. Opening a card previews exercises and triggers current video downloads on Wi-Fi without starting a session. Start creates a local session after the access check. Inputs save locally as drafts; completing a set starts rest. Finish records completed/total exercises, duration and an optional note. An unfinished session resumes after interruption. Switching programs or starting a new cycle requires finishing or confirming discard of the active session.

**Replacement and history:** Choose a replacement from the supplied exercise library for this session or remember it for the program. Do not transfer the previous exercise's load automatically. History lists sessions chronologically and exposes actual exercises, results, notes and duration. Editing a historical result updates previous-performance displays. Deletion requires an online confirmation; its completion mark remains.

**Access and settings:** Expired sign-in never interrupts local training; prompt after local finish if needed. When cached entitlement has expired, require online renewal verification before starting another session. Settings include units, training frequency, rest alerts, download storage, sync/retry status, subscription management, sign-out and account deletion. Profile data remains Clerk-managed. These navigation details are design assumptions to verify during UI implementation.
