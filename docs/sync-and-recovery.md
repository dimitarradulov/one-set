# Synchronization, durability and recovery

Status: completed-session upload, compact program-progress restore, compact previous-performance restore, and paginated authenticated History are implemented. Recent History refreshes on tab return and foreground, with pull-to-refresh for the user. Older pages load on demand. The user approved offline training, immediate durable local writes, no silent overwrites, hard deletion and uninterrupted active training. History edits, deletes and the broader recovery protocol remain future work.

The [completed-session save slice](https://github.com/dimitarradulov/one-set/issues/40) narrows the first upload implementation to finished sessions and supersedes the routine visible workout sync states and Retry action proposed below. Active drafts and discards remain local; automatic completed-session retries are invisible during normal use. Actionable failures still surface. The broader draft, history-edit and restoration protocol below remains future work.

## Save states

| State | Meaning |
| --- | --- |
| Draft | Entered values committed locally; not a completed working set |
| Saved on device | Completed work durably committed locally with its pending operation |
| Syncing / pending | Device retains its copy; request is in flight or waiting |
| Synced | Server transaction has committed and client has recorded its acknowledgment |
| Needs attention | Authentication, conflict, validation or storage issue requires resolution; data retained |

“Synced” does not mean an independent backup already contains the data. Offline records cannot survive loss of their only device. Never use a green check to imply more protection than exists.

## Local saves and uploads

Save session inputs, completed sets, notes and the rest countdown deadline locally before confirming success. Keep the deadline only on the device; PostgreSQL stores the training record, not the live countdown. A local transaction also queues pending server changes.

Send one session update at a time. Preserve a sent body and base session revision for retries; keep newer local input separately until the earlier request is acknowledged. Session revisions protect against a delayed request overwriting a newer saved workout. They do not apply to runs, preferences or account settings.

### First-time program switching

The account-scoped onboarding file stores confirmed latest-cycle metadata, the selected cycle, fixed creation requests, and ordered activation requests. A missing or failed discovery is not evidence that a program is new. A switch commits the selection and its required requests in one atomic file replacement before navigating; the original setup upload remains separate. Creation follows setup, and session drains skip only sessions whose own cycle creation remains pending. Permanent creation and activation rejections are retained with their original cycle identities and are not automatically retried. Later valid selection requests and sessions for owned cycles continue independently. A rejected creation and its queued workouts remain on the device with their original payloads; the overview explains that the change was not saved to the account.

### Completed-only first upload

For an authenticated account with an existing server-side cycle, finishing a full or partial workout commits the finished local session and a stable completed-session request body together before the app confirms finish. The body includes the captured week/day, full slot list and prescription; performed results include the entered unit, load, reps and time, while unperformed slots carry null results. Draft text and the running rest countdown remain local. Drafts, discarded sessions and empty attempts are never sent. The app tries the completed-only `POST /v1/sessions/completed` request immediately after the durable local finish and shows no routine sync status or retry action.

Local schema version 5 backfills finished rows from pre-upload stores into the same account-scoped queue. It uses each session's existing ID and captured payload, skips active and empty attempts, and does not fill missing snapshot fields from today's catalog. Inserts are idempotent and leave any existing acknowledgment or retry state unchanged; the migration never deletes or rewrites a stored session.

The local queue retains an unacknowledged body if that request fails. An equal retry with the same session ID and body is safe; a different body with that ID conflicts. Queue reads, retry state and acknowledgments are scoped by account. The request uses the currently authenticated account token and only records acknowledgment if the account and request generation still match after the response. App-lifetime drains run after finish, authenticated restoration, foreground entry and a network path becoming available. While the process remains active, a cancellable wakeup retries at the earliest persisted due time; relaunch and foreground entry recover work if the process stops. Drains send due records oldest first. A transient failure gets its own retry date while later due records continue; a permanent rejection remains in the local queue and does not block later records. A 401 defers the record until authentication is restored; 403, 409 and invalid-session responses are retained as permanent failures. Other request failures persist an exponentially increasing retry date from 15 seconds up to six hours, honoring a longer `Retry-After` value when supplied. Background execution remains opportunistic, and a retained pending body alone is not a backup until the server confirms it.

### Paginated session history and refresh

Authenticated History loads the newest remote page after reading local completed sessions, and stores each imported page together with its owner-scoped cursor and coverage marker in local schema version 9. Each page write is atomic; imported rows never enter the outbound session queue. The app keeps loaded rows and coverage offline, refreshes the newest page when History becomes active or the app returns to the foreground, and requests an older page only when the user chooses to continue at the archive boundary. Pull-to-refresh uses the same recent-page operation. Stable session IDs merge local finishes and uploaded copies without replacing their local upload bookkeeping. A recent-page refresh atomically resets the continuation to the newest page boundary; pages remain keyset ordered by `(started_at, id)`, so equal timestamps and late uploads do not create gaps. A failed refresh keeps saved rows and the existing durable continuation; a failed older request keeps the loaded rows and offers a connection/retry action. Account changes and overtaken page requests are rejected before they can update visible state or durable coverage.

### Compact previous-performance restore

After authenticated account setup resolves, the app reads `GET /v1/me/previous-performance`, which returns the latest completed working-set result for each actual exercise and original slot in each owned program workout. This read restores the preferred same-exercise/same-workout result and the latest fallback without fetching session history pages. The Worker derives ownership from Clerk authentication, keeps the response private, and does not require active subscription access. Local SQLite migration v8 adds an account-scoped cache separate from session rows and the upload queue. Results retain their original load and unit; the existing recorder uses them for display and progression guidance without filling current inputs. Local completed sessions are merged during selection, so newer offline work takes precedence. Failed reads preserve cached/local results and show an unavailable state with a retry action rather than claiming there is no earlier performance.

### Compact program-progress restore

After account setup resolves, the app reads `GET /v1/me/progress` and stores the active cycle's monotonic training-week boundary, completion marks, retained workout periods and current required workout order in account-scoped SQLite migration v7. This read restores Program overview completion marks and next-workout eligibility independently of History pages and full session details. Local finished sessions continue to contribute immediately, including work still pending upload. A failed summary read preserves an already restored snapshot; on a fresh device without safe cached progress, account restoration exposes its retry state instead of inventing a new week or cycle.

If a locally completed setup is still pending, session uploads wait for its acknowledgment. Setup retries keep the same device-generated cycle ID, including after a lost response. If the account already has a different established cycle, the app records a durable block for the local cycle before acknowledging setup. Sessions under that original cycle remain queued with their original IDs and bodies; the Worker rejects them because the cycle is not owned by the account. Other sessions for valid owned cycles continue through the queue. An active workout on the blocked local cycle may still be finished and saved locally, but its upload remains blocked. The app explains that the completed workout is still on this device and was not moved or uploaded. It does not create a replacement cycle, rewrite the session, or show routine retry controls.

### Sign-out with queued workouts

Sign-out remains blocked while a workout is active. When completed sessions are still queued, ask before signing out and explain that they stay on this device and resume under the same account. Confirming sign-out stops starting new upload requests and preserves queued session IDs, bodies, retry dates, and failure metadata. Keep a pending setup if a queued session uses its cycle; discard an unrelated pending setup. Session and setup queues remain scoped to the original account, so another account cannot resume them. After the owner signs in again, resolve or upload setup first, then retry the same session requests.

An HTTP request already in flight may finish at the server after sign-out starts. Its response is ignored after the request generation or account changes, so it cannot acknowledge local work for a signed-out or different account. The retained request can safely retry with its original ID and body. A cancelled confirmation leaves the account unchanged. If authentication sign-out fails, keep the same account and queue, report that the workouts remain on the device, and resume automatic retry. Local pending workouts remain dependent on this device until the server acknowledges them; they are not an independent backup.

In one short server transaction:

1. Authenticate and lock the user's row. Derive session ownership through `user_programs`; there is no session `user_id` field.
2. Validate the session's fixed run/week/workout and original slots, including slots removed from the current template after the workout was downloaded. Updates cannot recreate a missing session.
3. If intended session/set state already equals stored state, acknowledge it. Otherwise require the expected revision, write the session and all sets, and increment the revision.
4. On Finish require at least one completed set and insert the completion mark with `ON CONFLICT DO NOTHING`. Commit before acknowledgment.

Run/session UUIDs are generated once on the device and reused. Set identity is session UUID + original slot ID. No operation receipts, change feed or server deletion identifiers are needed. Keep local input if validation or a stale session revision rejects a write; never discard it or blindly rebase an ambiguous retry.

User settings and remembered replacements/notes/rest use the latest saved values. Serialize/coalesce their pending writes on the device. They have no revision or multi-device conflict flow.

## Program runs

Resume the latest started run for the selected program (`started_at DESC, id DESC`). The app exposes Start new cycle, not arbitrary activation of an older cycle. Start time and run identity are fixed after creation.

Starting a new cycle creates the run, copies compatible preferences from local state and selects it in one durable device transaction. The client restores and caches each cycle’s complete preference list and persists the compatible snapshot with the new run. If that knowledge is unavailable, it offers recovery instead of inventing empty preferences. Sync the run and captured preferences together; on first insertion the server also selects the new run under the user lock. A create retry returns the existing run without recopying preferences or reactivating it. Other program selections queue after pending run creation. Copy only preferences whose original slot remains in the current program template.

`users.active_user_program_id` records the selected run; no per-run current flag is needed. Switching programs and new-cycle creation are blocked until the active workout is finished or discarded.

## Refresh and device replacement

Fetch account setup and compact training progress independently from paginated History. The authenticated progress read returns the active cycle's monotonic training-week boundary, completion marks, retained workout membership periods, and required workout keys for the current week. Persist it by account/cycle, merge completion marks by identity and never lower the saved week boundary. Do not create session rows or upload work from these marks. Preserve local pending completions and include them when selecting completed days and the next workout.

History pages restore full session details as the lifter browses; cached rows alone do not establish complete training progress or previous performance. Active timers and unsynced work remain local. Concurrent training across devices is outside the current scope.

## Delete and discard

Completed-history deletion is online-only and confirmed. Resolve outstanding uploads for that session before DELETE and suppress further writes. Hard-delete the session and its sets atomically; retain completion marks. After acknowledgment remove local history/pending writes. Repeated DELETE of an absent record succeeds; UPDATE never recreates one.

Confirmed discard of a never-uploaded draft removes it locally and cancels its create. If it was uploaded or a request is unresolved, hide it locally and persist a pending discard. Resolve outstanding creation before deleting the server draft; retry until acknowledged and suppress it during refresh. Do not send another create for that ID. If the record is already completed, use online confirmed history deletion. This is device retry bookkeeping, not a server tombstone table.

## Retry, authentication and access

Retry network/5xx/429 failures with bounded backoff; honor Retry-After. Persist the queue and retry on finish, authenticated restoration, foreground entry and reconnection. Background execution is opportunistic. Routine upload state stays invisible.

401: refresh silently or defer reauthentication until local finish. 403: retain input and stop automatic retries. 409: retrieve current session state without clearing local work. 422: retain input and identify corrections. Never treat an error as permission to delete training data.

Clerk owns account/access management. Offline starts use the access integration's last verified local validity limit. Expiry blocks new protected activity, not completing or synchronizing an already started workout.

## Operational recovery and no-cost condition

Chosen baseline: Neon Free plus a separate private R2 backup bucket **only if total incremental cost is zero**. Verify current pricing, restore limits, shared allowances and compressed backup sizes before activation. A paid plan has not been approved.

Proposed backup workflow:

1. Daily standard Linux GitHub Actions job, subject to verified account allowances and scheduler limitations.
2. Produce a transaction-consistent Postgres dump using a compatible client. Encrypt before upload; keep decryption material separately recoverable, never inside the backup bucket or logs.
3. Upload immutable dated object plus checksum/manifest to private R2. No public endpoint or GitHub artifact containing the dump.
4. Retain 30 daily copies subject to the approved free-space budget; do not silently reduce retention when full. Alert and obtain a decision if quotas prevent the policy.
5. Verify job success and independently detect a stale newest-successful-backup timestamp. Preserve last good backup on failure.
6. Rehearse restore into a disposable target before launch and periodically afterward; record timings, row counts and sample relationship checks.

Runner minutes, Neon compute/egress and R2 storage/operations are all shared allowances. R2 budget alerts are not hard caps. Actual compressed dump sizes and account usage are unverified; this is a candidate, not a guaranteed free activated service.

### Failure boundaries

| Failure | Intended recovery | Limit |
| --- | --- | --- |
| App crash / restart | Durable local store and outbox | Storage corruption/device loss excluded |
| Network/server outage | Local training; retry later | Fresh sign-in/download/expired-access renewal needs network |
| Lost device after acknowledged sync | Restore owned history from server | Unsynced edits may be lost |
| Bad migration/data corruption within restore window | Provider restore into separate target; compare before cutover | Free restore window is short and quota-limited |
| Primary provider/account unavailable | Independent encrypted R2 dump | Daily backup can omit roughly a day of changes; longer if missed |
| Intentional user deletion | Keep deleted data absent | No user-facing recovery; restoration must replay deletion/erasure instructions |

An independent deletion/erasure ledger is needed to avoid resurrecting deliberate deletions from older backups. Its protected storage, retention and update protocol must be designed before enabling operational restore; recording it only in the database being lost is insufficient. It should contain identifiers, not deleted workout contents. This is a launch gate, not permission to introduce a soft-delete feature.

No zero-loss guarantee or recovery-time SLA has been established. Proposed operational goal: restore within one working day after incident acknowledgment, subject to a successful rehearsal and operator availability. The founder must explicitly accept any remaining disaster gap at launch; approval of a backup location alone does not validate recovery performance.
