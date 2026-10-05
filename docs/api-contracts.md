# Proposed API contracts

Design-level HTTPS/JSON interface. The narrow [account setup lookup](account-setup.md) is implemented; the other endpoints remain proposals. Aligned with [oneset.dbml](database/oneset.dbml) and [sync rules](sync-and-recovery.md); reviewed 2026-09-29. API version prefix `/v1`. Authenticate private routes with Clerk bearer token; derive account ID server-side. Accept UUID operation IDs for request correlation; stable entity IDs govern creation retries and session revisions protect workout updates, without a server operation ledger. Use opaque pagination cursors and structured errors. Avoid personal data in URLs/logs.

## Operations

| Method / path | Responsibility |
| --- | --- |
| GET /catalog/programs | Ten current program summaries; frequency filters |
| GET /catalog/programs/{id} | Current workouts, workout-exercise IDs, rep targets and referenced exercise guidance/media for download |
| GET /catalog/exercises | Search supplied catalog; stable pagination |
| GET /me/setup | Implemented owner-scoped completed setup lookup; [contract](account-setup.md) |
| GET /me/bootstrap | Complete consistent owned snapshot, including OneSet settings, runs, preferences, sessions and completion marks; Clerk profile/access is resolved separately |
| PATCH /me | OneSet unit/frequency changes; latest saved values take effect; account profile edits go through Clerk |
| POST /cycles | Create and select a new run with its initial compatible preference copy; retries return it without recopying or reactivating |
| POST /cycles/{id}/activate | Select the latest run for that program; latest saved choice takes effect; block active-workout overlap |
| PUT /cycles/{id}/exercises/{workout_exercise_id} | Save remembered `exercise_id`, `note`, `rest_seconds`; latest saved values take effect |
| POST /sync/push | Apply a bounded batch of aggregate operations; outcome per operation |
| GET /sessions | Keyset-paginated history; no public/shared cache |
| GET /sessions/{id} | Snapshot and results; ownership checked |
| DELETE /sessions/{id} | Online confirmed hard deletion after outstanding session uploads resolve; absent record is already deleted |
| GET /exercises/{id}/history | Owned completed results; optional `workout_program_id` / `workout_id` context |
| POST /media/access | Accept `video_key`, verify access and return a short-lived grant or authorized stream location |
| GET /media/content?video_key=... | Protected range-capable response; authorize before serving cached bytes |
| DELETE /me | Proposed account-erasure flow; reauthentication and retention implementation required |

Run creation/activation/catalog maintenance are not assumed to be callable by unauthenticated visitors. Program preview is available after account creation without subscription. No export, public sharing, custom exercise creation, or soft-delete recovery endpoint.

## Payload rules

- **Catalog:** program fields are `id`, `name`, `recommended_weeks`. Frequency is derived from current program-workout rows. Return current template entries with `position IS NOT NULL`; include `workout_exercises.id`, `workout_id`, `exercise_id`, `position`, `reps_min`, `reps_max` and referenced exercise guidance. There are no versions, logical keys, equipment or estimated-duration fields. Template slots have no prescription JSON.
- **Settings:** PATCH accepts `preferred_unit` (`kg`/`lb`) and `training_days` (2–5). Read `active_user_program_id` from bootstrap; change it through cycle creation/activation. No settings revision. Clerk owns account profile/access.
- **Cycles:** POST accepts client-generated `id`, `workout_program_id`, `started_at` and an initial `preferences` array. Each preference contains `workout_exercise_id`, optional replacement `exercise_id`, `note` and `rest_seconds`. Insert the owned run/preferences and select it atomically. Creation retries verify fixed run identity and return the existing run without repeating either copy or activation. Resume uses `started_at DESC, id DESC`; activation selects only the latest run for that program. No run revision or current flag.
- **Remembered preferences:** PUT supplies all three override values; null clears an override. All nulls may remove the sparse row. Null `exercise_id` means use the template exercise. Require positive rest seconds when supplied. Validate that the user owns the run and the slot belongs to its current program template. Changing a preference never edits existing session copies.
- **Media:** `video_key` is the stored private object key, not a media-table ID or an access grant. Authorization is required for current and historical referenced media alike.

Settings, preference and activation writes are serialized on the device and use latest-saved semantics. Their requests never carry a session `base_revision`.

## Session sync envelope

`/sync/push` accepts a bounded list of session operations. Cycles/settings/preferences use their routes above. Here is one operation for saving an unfinished session; the example assumes a one-slot workout:

```json
{
  "operation_id": "11111111-1111-4111-8111-111111111111",
  "aggregate_type": "session",
  "aggregate_id": "22222222-2222-4222-8222-222222222222",
  "base_revision": 3,
  "intent": "save",
  "payload": {
    "user_program_id": "33333333-3333-4333-8333-333333333333",
    "workout_id": 1,
    "week_number": 1,
    "workout_name": "Workout A",
    "started_at": "2026-09-29T12:00:00Z",
    "completed_at": null,
    "note": null,
    "sets": [
      {
        "workout_exercise_id": 1,
        "exercise_id": 1,
        "position": 1,
        "prescription": {
          "name": "Leg Press",
          "instructions": "Reviewed exercise instructions and stopping guidance.",
          "video_key": null,
          "reps_min": 8,
          "reps_max": 12,
          "rest_seconds": 180,
          "warmup_guidance": {"steps": [], "note": "Reviewed exercise-specific warmup guidance."}
        },
        "note": null,
        "weight": 40,
        "unit": "kg",
        "reps": 10,
        "completed_at": "2026-09-29T12:01:00Z"
      }
    ]
  }
}
```

The envelope's aggregate ID supplies `workout_sessions.id`; its set rows inherit `workout_session_id`. Each set is identified by that ID plus `workout_exercise_id`, not another UUID. Validate ownership through `user_programs.user_id`. Do not accept a session owner field, client-controlled revision increments or account/access fields. Rest timer state stays on the device.

- **Create:** use a stable session UUID and `base_revision: null`; initialize server revision to 1. Include one row for every captured slot. A retry of an existing ID acknowledges equal state; differing state returns a conflict, never an overwrite.
- **Save:** require the last acknowledged revision. Preserve fixed run/week/workout and captured slot IDs. Missing sessions return 404; save is not an upsert. Retain snapshots even when the current template changes or its positions become null. Deliberate replacement/history edits update the relevant snapshot and actual exercise together.
- **Finish:** require a completion timestamp at or after start and at least one completed set. Completed sets need nonnegative weight, positive reps and completion times within the session. Save session/sets and insert the run/week/workout completion mark atomically. Clients do not write completion marks separately.
- **Discard:** remove a never-uploaded draft locally. If it reached the server, send discard after resolving outstanding uploads; an absent session succeeds, an unfinished owned session is deleted, and a completed one requires the confirmed history-deletion flow. No server tombstone is written.

Only sessions use revisions. Equal normalized session/set state is acknowledged without rewriting; differing stale state conflicts and local input is retained. Acknowledgment returns operation ID, session ID and current revision (or deletion confirmation for discard). Correlation IDs are not permanent server receipts. Operations are individually atomic; a batch need not be all-or-nothing. Retry unresolved operations without changing their IDs or sent bodies.

Validate full prescription structure, finite decimal weight, positive reps when present, units, positions and timestamps. Draft weight/reps may be null. Proposed request limits: 25 operations, 100 slots per session and 1 MB body, subject to implementation measurement.

## Refresh and deletion

Bootstrap returns a complete consistent snapshot of owned settings, runs, remembered preferences, sessions with nested sets, and completion marks. It has no change-feed cursor, deleted-ID list or provider-access fields. History pagination is for display and must not be interpreted as a complete account snapshot. Preserve local pending work and ignore responses overtaken by newer local saves.

Completed-history DELETE requires online confirmation and resolved pending uploads. Delete the owned session and its sets, retain completion marks, then acknowledge so the device can clear its copy. Repeated deletion of an absent session succeeds. Discarded drafts remain hidden locally during refresh until server deletion is confirmed. See [sync and recovery](sync-and-recovery.md) for retry ordering.

## Errors

| HTTP / code | Client behavior |
| --- | --- |
| 401 AUTH_REQUIRED | Silent refresh first; pending local work survives; deferred sign-in during active training |
| 403 FORBIDDEN | No automatic retry; retain local data; verify correct account |
| 409 REVISION_CONFLICT | Session payload differs at an old revision; retain local input and retrieve current state |
| 409 ACTIVE_WORKOUT / COMPLETED_SESSION | Finish/discard before switching, or use confirmed history deletion for a completed session |
| 404 SESSION_NOT_FOUND | An update cannot recreate missing history; reconcile from server state |
| 422 INVALID_WORKOUT | Show correction details; retain input |
| 429 RATE_LIMITED | Honor Retry-After, jitter retry |
| 5xx TEMPORARY_FAILURE | Backoff and keep device copy |

Clerk manages account profiles and access. The earlier RevenueCat webhook proposal is not an agreed API contract; payment-to-Clerk integration remains to be specified separately. No subscription projection is stored in this schema. Media authorization failures show retry/unavailable UI and never block local set logging.
