# Synchronization, durability and recovery

Status: proposed protocol. The user approved offline training, immediate durable local writes, no silent overwrites, hard deletion and uninterrupted active training. No protocol or recovery drill has been implemented.

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

In one short server transaction:

1. Authenticate and lock the user's row. Derive session ownership through `user_programs`; there is no session `user_id` field.
2. Validate the session's fixed run/week/workout and original slots, including slots removed from the current template after the workout was downloaded. Updates cannot recreate a missing session.
3. If intended session/set state already equals stored state, acknowledge it. Otherwise require the expected revision, write the session and all sets, and increment the revision.
4. On Finish require at least one completed set and insert the completion mark with `ON CONFLICT DO NOTHING`. Commit before acknowledgment.

Run/session UUIDs are generated once on the device and reused. Set identity is session UUID + original slot ID. No operation receipts, change feed or server deletion identifiers are needed. Keep local input if validation or a stale session revision rejects a write; never discard it or blindly rebase an ambiguous retry.

User settings and remembered replacements/notes/rest use the latest saved values. Serialize/coalesce their pending writes on the device. They have no revision or multi-device conflict flow.

## Program runs

Resume the latest started run for the selected program (`started_at DESC, id DESC`). The app exposes Start new cycle, not arbitrary activation of an older cycle. Start time and run identity are fixed after creation.

Starting a new cycle creates the run, copies compatible preferences from local state and selects it in one durable device transaction. Sync the run and initial preferences together; on first insertion the server also selects the new run under the user lock. A create retry returns the existing run without recopying preferences or reactivating it. Other program selections queue after pending run creation. Copy only preferences whose original slot remains in the current program template.

`users.active_user_program_id` records the selected run; no per-run current flag is needed. Switching programs and new-cycle creation are blocked until the active workout is finished or discarded.

## Refresh and device replacement

Fetch a complete owned snapshot from one read-only repeatable-read transaction: settings, runs/preferences, completion marks and sessions/sets. Apply only a complete response, preserving pending local input and suppressing pending deletions. Discard responses overtaken by newer local writes/acknowledgments. Partial history pages must never stand in for a full account snapshot.

The same snapshot restores synced history on a replacement device. Active timers and unsynced work remain local. Concurrent training across devices is outside the current scope. Measure full-refresh size before introducing incremental synchronization.

## Delete and discard

Completed-history deletion is online-only and confirmed. Resolve outstanding uploads for that session before DELETE and suppress further writes. Hard-delete the session and its sets atomically; retain completion marks. After acknowledgment remove local history/pending writes. Repeated DELETE of an absent record succeeds; UPDATE never recreates one.

Confirmed discard of a never-uploaded draft removes it locally and cancels its create. If it was uploaded or a request is unresolved, hide it locally and persist a pending discard. Resolve outstanding creation before deleting the server draft; retry until acknowledged and suppress it during refresh. Do not send another create for that ID. If the record is already completed, use online confirmed history deletion. This is device retry bookkeeping, not a server tombstone table.

## Retry, authentication and access

Retry network/5xx/429 failures with bounded backoff and jitter; honor Retry-After. Persist the queue and retry on foreground/reconnection. Background execution is opportunistic. Surface pending state and a retry action.

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
