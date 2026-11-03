# Proposed API contracts

HTTPS/JSON interface, aligned with [oneset.dbml](database/oneset.dbml) and [sync rules](sync-and-recovery.md). The catalog and account setup routes below are implemented; other endpoints remain proposals. API version prefix `/v1`. Authenticate private routes with Clerk bearer token; derive account ID server-side. Accept UUID operation IDs for request correlation; stable entity IDs govern creation retries and session revisions protect workout updates, without a server operation ledger. Use opaque pagination cursors and structured errors. Avoid personal data in URLs/logs.

## Operations

| Method / path | Responsibility |
| --- | --- |
| GET /v1/catalog | Authenticated complete catalog snapshot with `ETag` conditional revalidation |
| GET /v1/catalog/programs | Same complete catalog snapshot |
| GET /v1/catalog/programs/{key} | One stable-key program and the shared exercise catalog |
| GET /v1/catalog/exercises | Shared exercise guidance from the same publication snapshot |
| POST /v1/maintenance/catalog/preview | Validate and compare source with the current snapshot; maintenance bearer secret |
| POST /v1/maintenance/catalog/publish | Atomically publish the exact reviewed source; maintenance bearer secret |
| GET /me/setup | Implemented owner-scoped completed setup lookup; [contract](account-setup.md) |
| GET /me/progress | Implemented owner-scoped compact progress restore, independent of paginated session history |
| POST /sessions/completed | Implemented first-write contract for completed sessions and occurrence progress |
| GET /me/bootstrap | Deferred full-snapshot proposal; training readiness uses `/me/progress`, while full sessions use paginated `/sessions` |
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

Catalog reads and account setup require Clerk authentication. Catalog maintenance requires the separate `CATALOG_PUBLISH_TOKEN`; a Clerk session cannot publish. Program preview is available after account creation without subscription. No export, public sharing, custom exercise creation, or soft-delete recovery endpoint.

## Payload rules

- **Catalog:** `GET /v1/catalog` returns `{ publication_id, catalog: { exercises, programs } }` from one publication snapshot. Programs use stable `key`, `name`, `recommended_weeks`, `training_days_per_week`, `format`, `emphasis`, and ordered current workouts. `training_days_per_week` is derived from current workouts, not authored separately. Removed workouts and slots are omitted from app delivery but remain in the reviewed source and database for identity and history preservation. Removed programs remain resolvable for existing followers and are excluded from new selection. Workouts and slots have stable authoring keys; slots contain an exercise key, order, rep bounds, and optional `scope` (`reps`, `each_leg`, or `each_side`). Shared exercises carry stable keys, complete technique, stopping and warm-up text, default reps, rest seconds and an optional video key. `ETag` identifies the complete snapshot; `If-None-Match` receives `304` when unchanged. The Worker also serves `/v1/catalog/programs`, `/v1/catalog/programs/{key}`, and `/v1/catalog/exercises` from that same snapshot.
- **Catalog publication:** preview accepts `{ source, source_fingerprint }`, validates stable keys, all references, required guidance, rep bounds and order, then returns `preview_id`, source/backend fingerprints, changes, and affected programs without writing. Publish accepts that exact source plus all preview identifiers. A changed source or backend returns `409 STALE_PREVIEW`; invalid data returns `422 INVALID_CATALOG`. One database transaction applies the catalog and changes the singleton publication pointer. Repeating the identical publication ID and source returns the prior success; a failed transaction leaves the prior snapshot visible. The publisher CLI requires an explicit environment and reads its separate maintenance token from environment-scoped variables.
- **Settings:** PATCH accepts `preferred_unit` (`kg`/`lb`) and `training_days` (2–5). Read `active_user_program_id` from bootstrap; change it through cycle creation/activation. No settings revision. Clerk owns account profile/access.
- **Cycles:** POST accepts client-generated `id`, `workout_program_id`, `started_at` and an initial `preferences` array. Each preference contains `workout_exercise_id`, optional replacement `exercise_id`, `note` and `rest_seconds`. Insert the owned run/preferences and select it atomically. Creation retries verify fixed run identity and return the existing run without repeating either copy or activation. Resume uses `started_at DESC, id DESC`; activation selects only the latest run for that program. No run revision or current flag.
- **Cycle progress:** `user_programs.current_training_week` is the monotonic week boundary. Catalog publication uses it when applying added or removed workout days, while `required_workouts_for_cycle_week(cycle_id, week)` resolves the current order for future occurrences. A future finish command advances the boundary only after all required workouts for that week are complete; catalog refresh never recomputes it from edited structure.
- **Remembered preferences:** PUT supplies all three override values; null clears an override. All nulls may remove the sparse row. Null `exercise_id` means use the template exercise. Require positive rest seconds when supplied. Validate that the user owns the run and the slot belongs to its current program template. Changing a preference never edits existing session copies.
- **Media:** `video_key` is the stored private object key, not a media-table ID or an access grant. Authorization is required for current and historical referenced media alike.

Settings, preference and activation writes are serialized on the device and use latest-saved semantics. Their requests never carry a session `base_revision`.

## Compact progress restore

`GET /v1/me/progress` returns `{ progress }` for the authenticated user's active cycle, or `{ progress: null }` when no active cycle exists. A non-null response includes the stable cycle and program keys, monotonic `current_training_week`, all known completed occurrence marks (`week_number`, `workout_id`), retained workout membership periods (`starts_week`, nullable `ends_week`), and the ordered workout keys required in the current training week. It contains no session or set payloads. The Worker derives ownership from the verified Clerk subject and responds with `Cache-Control: private, no-store`; subscription access is not checked.

The app persists this compact summary by account and cycle. It merges occurrence marks by identity and never lowers the saved week boundary. These marks drive week checkmarks and next-workout eligibility without creating synthetic session rows or upload operations. Local completed sessions remain part of progress when they are newer than the server summary.

## Completed-session first write

`POST /v1/sessions/completed` is an authenticated first-write command for a finished session. It does not accept drafts, edits, or deletes. The Clerk subject supplies ownership. The client sends stable cycle, program, workout, slot, and exercise authoring keys plus the full captured prescription; the server resolves those keys and verifies that the cycle belongs to the caller and that the workout and slots belong to that cycle's program. Captured guidance and order are retained as sent, even when current catalog content has since changed. Subscription expiry is not rechecked for work already performed.

The body contains `session_id`, `cycle_id`, `program_key`, `workout_key`, `week_number`, `workout_name`, `started_at`, `completed_at`, nullable `note`, and an ordered `sets` array. Every captured slot appears once with `position` equal to its one-based array index. A completed slot has `weight`, entered `unit`, `reps`, and `completed_at`; an unperformed slot sends null for weight, reps, and set completion time. Each row also contains `workout_exercise_key`, actual `exercise_key`, and a `prescription` with captured `name`, `instructions`, `stopping_guidance`, `warmup_guidance`, nullable `video_key`, `reps_min`, `reps_max`, `rep_scope`, and nullable `rest_seconds`. Nullable fields must be present with explicit JSON `null`; omission is invalid. `warmup_guidance` contains `steps` and `note`. Rest countdown state and uncompleted draft strings stay on the device.

For example, a completed row with no video key or customized rest still includes those keys:

```json
{
  "session_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  "cycle_id": "11111111-1111-4111-8111-111111111111",
  "program_key": "machine-full-body",
  "workout_key": "day-a",
  "week_number": 1,
  "workout_name": "Workout A",
  "started_at": "2026-10-01T10:00:00.000Z",
  "completed_at": "2026-10-01T10:45:00.000Z",
  "note": null,
  "sets": [{
    "workout_exercise_key": "slot-a",
    "exercise_key": "leg-press",
    "position": 1,
    "prescription": {
      "name": "Leg Press",
      "instructions": "Use a controlled full range.",
      "stopping_guidance": "Stop when you cannot complete another rep with good form.",
      "warmup_guidance": { "steps": [], "note": "Warm up gradually." },
      "video_key": null,
      "reps_min": 8,
      "reps_max": 12,
      "rep_scope": "reps",
      "rest_seconds": null
    },
    "weight": 40,
    "unit": "kg",
    "reps": 10,
    "completed_at": "2026-10-01T10:12:00.000Z"
  }]
}
```

The Worker rejects malformed values and cross-account references before writing. The database function writes the session, every captured set, the occurrence completion mark, and any applicable monotonic week advancement in one transaction. It accepts partial finishes with at least one completed set, older valid occurrences, and weeks beyond the recommended program duration. A new write returns `201 {"session_id":"…","result":"created"}`; an equal retry returns `200` with `result: "acknowledged"`; differing content for the same session ID returns `409 SESSION_CONFLICT`. Invalid payloads return `400` or `422 INVALID_SESSION`, cross-account cycle references return `403 FORBIDDEN`, and temporary database failures return `503 TEMPORARY_FAILURE`.

On device, finishing commits the completed session and its exact sent body to the local store in one transaction before finish succeeds. The same session ID and body are reused after interruption or retry. A successful server response is acknowledged locally only for the same account and request generation; a failed request or failed local acknowledgment leaves the upload pending with durable retry metadata. App-lifetime drains run after finish, authenticated restoration, foreground entry and reconnection, in oldest-first order; while the process is active, a cancellable wakeup retries at the earliest persisted due time. Transient failures use exponential backoff from 15 seconds to six hours and honor a longer `Retry-After` header while later due records continue in the drain. A 401 defers the record until authentication is restored. 403, 409 and invalid-session responses are retained as permanent failures and do not block later uploads. Routine upload state is not shown in the UI.

If a pending setup PUT returns a different established cycle, the app persists a setup-cycle conflict for the submitted local cycle before acknowledging setup. Sessions retain their original cycle, ID and sent body and remain queued; the Worker rejects the unowned cycle with `403 FORBIDDEN`. Sessions for other cycles continue independently. The app explains that the completed workout remains on-device, with no routine status or manual retry control.

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

The former full bootstrap proposal is deferred. Compact training progress is restored separately through `/me/progress`; full sessions are retrieved only through bounded history pages. Neither the visible History cache nor a partial page is a complete account snapshot. Preserve local pending work and ignore responses overtaken by newer local saves.

Completed-history DELETE requires online confirmation and resolved pending uploads. Delete the owned session and its sets, retain completion marks, then acknowledge so the device can clear its copy. Repeated deletion of an absent session succeeds. Discarded drafts remain hidden locally during refresh until server deletion is confirmed. See [sync and recovery](sync-and-recovery.md) for retry ordering.

## Errors

| HTTP / code | Client behavior |
| --- | --- |
| 401 AUTH_REQUIRED | Silent refresh first; pending local work survives; deferred sign-in during active training |
| 403 FORBIDDEN | No automatic retry; retain local data; verify correct account |
| 409 REVISION_CONFLICT | Session payload differs at an old revision; retain local input and retrieve current state |
| 409 SESSION_CONFLICT | Completed-session ID already stores different content; keep the sent body and investigate before resolving |
| 409 ACTIVE_WORKOUT / COMPLETED_SESSION | Finish/discard before switching, or use confirmed history deletion for a completed session |
| 404 SESSION_NOT_FOUND | An update cannot recreate missing history; reconcile from server state |
| 400 / 422 INVALID_SESSION | Completed-session body is malformed or has invalid results; retain the local record for correction |
| 422 INVALID_WORKOUT | Show correction details; retain input |
| 429 RATE_LIMITED | Honor Retry-After, jitter retry |
| 5xx TEMPORARY_FAILURE | Backoff and keep device copy |

Clerk manages account profiles and access. The earlier RevenueCat webhook proposal is not an agreed API contract; payment-to-Clerk integration remains to be specified separately. No subscription projection is stored in this schema. Media authorization failures show retry/unavailable UI and never block local set logging.
