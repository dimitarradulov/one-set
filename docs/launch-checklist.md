# Implementation and launch checklist

Status: planned checks, not completed validation. Product choices are settled; these gates prevent implementation assumptions from being mistaken for deployed guarantees.

## Suggested implementation order

1. Inspect the applied Neon schema/data and write reviewed future migrations from the DBML. Rehearse rollback on disposable data.
2. Build durable local session storage and interrupted-workout recovery before UI polish or payment integration.
3. Implement owned API aggregates, idempotency, conflicts, hard deletion and complete-snapshot reconciliation.
4. Import reviewed programs and videos; implement the selected onboarding and program flow.
5. Integrate account identity, verified entitlements, protected streaming and Wi-Fi-triggered downloads.
6. Add the minimal analytics and operational visibility, run the failure checks below, then review costs and recovery before release.

## Content / product acceptance

- [ ] Founder approves all ten programs, rep targets, warmup exceptions, failure guidance and available video coverage.
- [ ] Variant A sequence preserved; final visuals/copy reviewed separately.
- [ ] Original requested six functions work: start/switch program, log, watch exercise video, history, program workout browsing.
- [ ] No warmup logs, per-side entry, auto-substitution prompts, export or soft-delete UI slipped into scope.
- [ ] Progression fits in a compact line and never invents a first-time weight.
- [ ] Verify total-weight examples, unit switching and per-side reps interpretation.
- [ ] Prototype assumptions signed off where material: deletion does not rewind program, zero-set finish, week 9+, replacement rep targets and exact paywall media boundary.

## Persistence and synchronization checks

- [ ] Enter draft → terminate/relaunch → restore draft.
- [ ] Complete set → immediately terminate → exactly one completed result and reconstructed timer.
- [ ] Local disk/write failure cannot show successful save or discard input.
- [ ] Finish offline → relaunch → completed history preserved, next occurrence advances once.
- [ ] Lose HTTP response after server commit → retry same session ID and sent revision/body → no duplicate/extra advancement.
- [ ] Edit while request in flight → old acknowledgment never overwrites newer draft.
- [ ] Retry Finish after a lost acknowledgment → no duplicate sets or completion marks.
- [ ] Delayed older session upload after a newer save → reject stale content and retain local input.
- [ ] Delete online → resolve outstanding session uploads, remove server/local history and clear pending writes.
- [ ] Discard offline after possible server receipt → queued discard eventually reconciles.
- [ ] Complete account refresh and replacement-device restore use a consistent snapshot.
- [ ] Program switch blocked during active workout; template edits affect future sessions while started sessions retain their captured content.

- [ ] Removing/reordering template entries preserves session order, guidance and references; new sessions exclude null positions.
- [ ] Resume selects the latest run; new-cycle retries never recopy preferences or reactivate it.
- [ ] Session ownership derives through the run; only sessions have revisions and timer state remains local.

## Identity / billing / media checks

- [ ] Apple/email sign-in restores the same account correctly; no linking solely by email.
- [ ] Authentication expiry/revocation during training never interrupts local logging.
- [ ] Choose and verify the payment-to-Clerk integration, then test trial eligibility, localized price, purchase cancellation, restore, renew, expire and refund.
- [ ] Cached entitlement expiration permits intended offline behavior; client clock is not authoritative server payment proof.
- [ ] Subscription expiry never prevents syncing previously recorded history.
- [ ] Cross-user ID substitution rejected on all routes and nested aggregate records.
- [ ] Private video inaccessible through unprotected bucket URL; authorization checked even on cache hits.
- [ ] Stream seek/range requests work; partially downloaded files never marked ready.
- [ ] Opening overview alone downloads nothing; opening workout on Wi-Fi does; cellular playback still works when requested.
- [ ] Notifications denied/phone locked/restarted still yield correct timer state without blocking workouts.
- [ ] Account deletion and subscription-management flows reviewed against current platform rules before submission.

## Performance checks

- [ ] Select oldest supported device and current device; document iOS/SDK floor after compatibility review.
- [ ] Measure input feedback and local-save p95 against 100 ms, including realistic history volume.
- [ ] Measure downloaded video first-frame time against one second.
- [ ] Measure online playback under explicit network conditions; confirm or revise proposed two-second p95 target.
- [ ] Verify Worker free CPU allowance with auth, real transaction sizes, media grants and retries.
- [ ] Inspect accessibility: screen reader, large text, visible units and non-color status.

## Costs and recovery — unresolved launch gates

- [ ] Confirm actual shared R2, GitHub Actions and Neon quotas, compressed backup sizes and video sizes. $0 backup approval is conditional.
- [ ] Choose/schedule the free runner and independent stale-backup detection. Account for delayed/missed scheduler executions.
- [ ] Configure retention and alerts without representing alerts as hard vendor spend caps.
- [ ] Independently retain minimal deletion/account-erasure instructions required after restore; do not recover intentionally erased records from an old dump.
- [ ] Store/recover encryption key separately and restrict backup credentials.
- [ ] Restore a backup into a separate database; verify owners, rows, relationships, sets and deletion reconciliation; record time.
- [ ] Document actual recovery point/time and residual risk. Six-hour provider restore and conditional daily backup do not fulfill literal zero-loss in every disaster.
- [ ] If no-cost conditions fail, pause activation of that backup plan and obtain a budget/recovery decision; never silently remove backups or enable billing.

## Artifact status

The documented database migration was applied to Neon production on 2026-09-29. No app, API, importer or media delivery has been built. Disposable PostgreSQL/DBML validation passed 29 SQL/query checks for the 11-table, 58-column schema; application workflows remain unimplemented. The approved onboarding sequence is in [requirements](requirements.md).
