# Completed session save planning

Status: shared understanding confirmed on 2026-11-01. Published as [issue #40](https://github.com/dimitarradulov/one-set/issues/40), labelled `ready-for-agent`. Product implementation has not started.

## Existing foundations

The [workout repository](../OneSet/Persistence/WorkoutRepository.swift) already saves active and completed sessions in account-scoped local SQLite. Finish requires at least one completed set, permits partial sessions, saves an optional note and advances local occurrence progress. Discard removes only an unfinished local session. The Worker currently implements catalog and account setup routes; session upload remains absent.

The server schema already includes sessions, one set row per captured slot, independent occurrence completion marks and a monotonic cycle week boundary. See [database design](database/README.md). The broader [API](api-contracts.md) and [sync](sync-and-recovery.md) documents describe proposals that include draft uploads and historical edits; this slice has a narrower upload boundary.

## Confirmed decisions

1. Upload completed sessions to Neon through the authenticated Worker. Active sessions and discarded sessions stay local. Finishing commits the completed session and pending upload atomically on the device. Upload happens without blocking local finish, survives app restart and tolerates retries without duplication.
2. Save captured workout instructions and exercise order, completed-set weight/reps and entered units, completion timestamps, session start/finish times and the optional session note. Preserve the identity of unperformed exercises; unchecked input does not count as a completed result.
3. This slice ends with reliable completed-session storage in Neon. History screens, historical editing/deletion and restoration onto another device are deferred. Demonstrate storage and retry behavior through integration tests and database inspection.
4. Backfill completed sessions already present on the device, oldest first, while signed in as their owning account. Reuse existing session identities; migration must preserve active sessions and completed results.
5. Routine workout uploads are invisible: no pending/synced status, upload progress or Retry button. Automatic upload and retry must not block finishing or starting the next workout. This supersedes the earlier proposal for visible workout sync status; existing setup-upload UI is outside this decision.
6. Allow sign-out with completed uploads pending after explaining that the workouts remain on this device and upload when the same account signs in again. Retain the completed sessions, queue and any pending setup needed to upload them. Other accounts cannot see or upload them. Explicit sign-out during an active session remains blocked.
7. In the same server transaction, save the completed session and captured slots/results, insert its occurrence completion mark once, and advance the cycle's server training week when all required workouts are complete. Retries cannot advance progress twice or move the week backward.
8. Upload pending setup before sessions that depend on its cycle. If setup resolves to a different established server cycle, retain the session under its original cycle and surface an upload problem. Do not silently reassign the session or create a replacement cycle as a workaround. A dedicated conflict-resolution flow is deferred.

## Persistence and failure rules

- The local transaction must commit both completion and its pending upload before successful finish UI. A failed local write retains the active work and reports the failure.
- Keep the complete captured slot list. Upload null performance values and no completion time for unperformed slots; any unchecked draft strings remain local. Retain captured exercise names, instructions, stopping guidance, warmup guidance, rep targets/scope and rest guidance rather than replacing them from today's catalog. Rest countdown state remains local.
- Preserve compatibility with existing local records. Never invent snapshot information missing from an older saved session or substitute changed catalog guidance for it.
- Persist a stable upload body/identity and acknowledgment state. Equal retried content acknowledges the existing session; differing content for an existing identity must not overwrite it. Retain rejected local work.
- Derive ownership from verified authentication and validate the referenced cycle, program, workout and original exercise slots. Resolve stable catalog keys to server identities, including retained entries removed from current templates. An offline captured session must not need to match today's instructions or slot order.
- Authenticate uploads for their owning account only. Ignore responses overtaken by sign-out or account changes. Expired subscription access does not invalidate already performed training; expired credentials defer upload without interrupting local recording.
- Retry temporary connectivity/server failures automatically with bounded backoff, including after relaunch, foreground entry and restored authentication. A rejected session must not prevent unrelated valid sessions from uploading. Do not silently delete failed work or continually retry a permanent validation conflict.
- Routine upload state stays invisible. The agreed conflicting-cycle failure, local storage failures and required reauthentication remain actionable exceptions; a dedicated history or conflict-resolution screen is not part of this slice.

## Verification for implementation

- Verify a full and a partial completed session in PostgreSQL, including note, entered units, timestamps, original captured content and identifiable unperformed slots. Active and discarded sessions never upload.
- Simulate interrupted finish, failed local commit, offline finish, relaunch before upload, server commit with a lost acknowledgment and acknowledgment persistence failure. Recover the same payload and create one session, one row per captured slot and one completion mark.
- Migrate existing local completed sessions into the upload queue without losing active sessions or results. Repeat migration/backfill safely.
- Upload dependent setup before its sessions. Exercise both the ordinary matching-cycle acknowledgment and the agreed different-cycle failure without changing the recorded session's cycle.
- Sign out while uploads are queued or in flight; sign in as another account and verify isolation. Sign back in as the owner and resume. Preserve pending setup needed by the queued workouts.
- Verify ownership rejection, malformed values, conflicting retry content, removed catalog slots, changed captured instructions, expired authentication and expired subscription access. Retain failed records and allow independent valid uploads.
- Verify multiple offline completions upload oldest first and advance server progress once, including retries and training beyond the recommended week count. Check structural catalog changes without rejecting valid captured training or rewinding server progress.
- Follow [validation guidance](agents/validation.md) for code changes. Inspect simulator routes/screenshots if implementing the newly agreed sign-out or exceptional-error UI requires visual verification. Routine upload visibility is not an acceptance requirement.

## Domain documentation

The [glossary](../GLOSSARY.md) now defines a completed session as explicitly finished work with at least one completed working set; partial sessions remain valid. No ADR is needed for this slice: it uses the existing architecture, and deferring draft upload and history features is a reversible milestone boundary.

## Planning closeout

The user confirmed the complete planning record and requested spec publication through `to-spec`. [Issue #40](https://github.com/dimitarradulov/one-set/issues/40) contains the problem, solution, user stories, implementation decisions, testing decisions and exclusions. The agreed workflow/integration checks use existing app model/repository boundaries and authenticated Worker requests backed by disposable database storage; existing app journeys cover the affected visible account/error behavior. No further product interview or implementation took place during publication.

Reviewed the specification structure, approved scope and links, verified the published issue body and label, and checked documentation whitespace. Build/test scripts and live infrastructure checks were not run for this documentation-only task.

## Sources

[Requirements](requirements.md), [domain vocabulary](../GLOSSARY.md), [start workout planning](start-workout-plan.md), [account setup](account-setup.md), [API proposals](api-contracts.md) and [sync proposals](sync-and-recovery.md). Findings describe repository code and documentation; no live database or infrastructure state has been verified during this interview.
