# Implementation Plan: Account Deletion - V1

Source spec: [SPEC.md](../SPEC.md) · Issue: [#102](https://github.com/dimitarradulov/one-set/issues/102)

## Overview

This plan implements the deletion flow described in the spec. The Worker gets a new endpoint, `DELETE /v1/me`, which works in this order:

1. Erase the user's data in one transaction.
2. Run the hook that #103 will fill in for subscription cleanup.
3. Delete the user in Clerk.
4. Run the erasure again (the sweep), to catch rows a stale request created meanwhile.

Separately, a guard on setup stops an old token from bringing a deleted account back. On iOS, a new Settings screen asks the user to confirm, pauses uploads, deletes the account on the server, erases that account's data on the device, and signs the user out. Docs and the privacy text come last.

Tasks are tracked as GitHub sub-issues of [#102](https://github.com/dimitarradulov/one-set/issues/102), with native blocked-by links. The issues are the source of truth for each task's status. The task details below are the planning record.

## Architecture Decisions

- **No schema migration.** Erasure deletes existing rows and nothing else. Setup creates the user row before calling `complete_onboarding`, so the user-row insert inside that function never fires for a new account.
- **One erasure function, used in three places:** the delete endpoint, the sweep that follows Clerk deletion, and the setup guard's undo. A single batched `sql.transaction` deletes rows from child tables first and the `users` row last.
- **A thin Clerk Backend client.** It lives in `worker/src/clerk-users.ts` and exposes `deleteUser` and `getUser`. Tests inject it, as they do the database today.
- **Local erasure is one place.** On iOS, `LocalAccountErasure` runs a list of `AccountDeletionCleanup` steps. #103 adds its billing step to that list.
- **Upload pausing is per account and owned by the coordinators.** The deletion model calls `suspend(accountID:)` and `resume(accountID:)` on `CompletedSessionUploadCoordinator` and `ProgramCycleSyncCoordinator`.
- **The model orders the steps, the service makes the calls.** `AccountDeletionModel` decides the sequence. `AccountDeletionService` does the HTTP request and makes the request and maps the result to deleted or failed.

## Dependency Graph

```text
T1 Clerk client     ──┬── T2 DELETE /v1/me ──┐
                        └── T3 setup guard ─────┤
                                                │ (API contract fixed by spec; iOS can start in parallel)
T4 local erasure ──┐                            │
T5 upload suspend ─┼── T7 deletion model ── T8 screen + route ── T9 end-to-end journey
T6 service ─┘                                                        │
                                                       T10 docs + #103 ─┴── T11 privacy text
```

## Issue Index

| Task | Issue | Blocked by |
| --- | --- | --- |
| T1 | [#107](https://github.com/dimitarradulov/one-set/issues/107) | - |
| T2 | [#108](https://github.com/dimitarradulov/one-set/issues/108) | #107 |
| T3 | [#109](https://github.com/dimitarradulov/one-set/issues/109) | #107, #108 |
| T4 | [#110](https://github.com/dimitarradulov/one-set/issues/110) | - |
| T5 | [#111](https://github.com/dimitarradulov/one-set/issues/111) | - |
| T6 | [#112](https://github.com/dimitarradulov/one-set/issues/112) | - |
| T7 | [#113](https://github.com/dimitarradulov/one-set/issues/113) | #110, #111, #112 |
| T8 | [#114](https://github.com/dimitarradulov/one-set/issues/114) | #113 |
| T9 | [#115](https://github.com/dimitarradulov/one-set/issues/115) | #114 |
| T10 | [#116](https://github.com/dimitarradulov/one-set/issues/116) | #108, #113 |
| T11 | [#117](https://github.com/dimitarradulov/one-set/issues/117) | #116 |

## Task List

### Phase 1: Worker

#### Task 1: Add the Clerk users client

**Description:** Add a small Clerk Backend client that uses the `CLERK_SECRET_KEY` secret.

**Acceptance criteria:**
- [ ] `deleteUser(id)` and `getUser(id)` return a typed result: success, not found, or temporary failure.
- [ ] `CLERK_SECRET_KEY` is declared in the Worker env types. No secret value appears in the repository.

**Verification:** `npm --prefix worker run typecheck`, `npm --prefix worker test` (the client maps 200/404/5xx).

**Dependencies:** None · **Files:** `worker/src/authentication.ts`, `worker/src/clerk-users.ts` (new), `worker/src/env.d.ts`, `worker/tests/authentication.test.ts`, `worker/tests/clerk-users.test.ts` (new) · **Scope:** M

#### Task 2: `DELETE /v1/me`

**Description:** Add the deletion route. It relies on the authenticated Clerk session only, runs the batched erasure transaction, calls the no-op `cleanupSubscription` hook, deletes the Clerk user (a 404 counts as success), then runs the sweep. Errors use the existing response shapes.

**Acceptance criteria:**
- [ ] Success returns 200 and leaves no rows for the user. Other users are untouched. A failing statement rolls back the whole erasure.
- [ ] If Clerk fails, the route returns 503, and a repeat call completes the deletion. A repeat call with no rows left still deletes the identity. The steps run in the order erase, hook, Clerk, sweep. A sweep failure is logged with the Clerk ID only.

**Verification:** `npm --prefix worker test` (new `account-deletion.test.ts`), `npm --prefix worker run typecheck`.

**Dependencies:** T1 · **Files:** `worker/src/account-deletion.ts` (new), `worker/src/index.ts`, `worker/tests/account-deletion.test.ts` (new) · **Scope:** M

#### Task 3: Setup stale-token guard

**Description:** Change the provisioning insert in `setup.ts` to `RETURNING id`. Only when it actually creates a row, ask Clerk with `getUser`. If Clerk returns 404, run the erasure and respond 401. If the Clerk call fails, run the erasure and respond 503. POST setup runs this guarded insert before `complete_onboarding`.

**Acceptance criteria:**
- [ ] Setup for an existing row makes no Clerk call.
- [ ] A new row for a deleted Clerk user is removed, and the response is 401. If the Clerk check fails, the row is removed and the response is 503.
- [ ] A race test passes: a row inserted between the erase and the Clerk deletion is gone after the sweep.

**Verification:** `npm --prefix worker test` (`setup.test.ts`, `account-deletion.test.ts`).

**Dependencies:** T1 (shares the erasure function with T2, so land T2 first or extract the function in T2) · **Files:** `worker/src/setup.ts`, `worker/tests/setup.test.ts`, `worker/tests/account-deletion.test.ts` · **Scope:** S

### Checkpoint: Worker

- [ ] `npm --prefix worker run typecheck` and `npm --prefix worker test` pass.
- [ ] **Ask first:** set `CLERK_SECRET_KEY` with `wrangler secret put --env development`, and deploy to `development`.
- [ ] Manual check on dev Clerk: delete from a signed-in session. The deleted user can't sign in again. The same email signs up as a new, empty account.
- [ ] Review with the user before starting the iOS work, if it was done in order.

### Phase 2: iOS

#### Task 4: Local account erasure

**Description:** Add `WorkoutRepository.eraseAccount(accountID:)`. In one GRDB transaction it deletes the account's sessions, upload queue, restored progress, cached History, and previous performance. Also add `LocalAccountErasure`, which runs a list of `AccountDeletionCleanup` steps: the repository, onboarding progress `remove`, saved subscription access `removeAll`, and pending subscription operations `remove`.

**Acceptance criteria:**
- [ ] After erasure, no local data remains for the erased account. Another account's data is unchanged.
- [ ] If a step fails, the error is reported, and later steps still run so no data is left half-erased.
- [ ] #103 can add a step without changing `LocalAccountErasure`.

**Verification:** `./scripts/validate.sh --focused OneSetTests/WorkoutRepositoryAccountErasureTests OneSetTests/LocalAccountErasureTests`

**Dependencies:** None · **Files:** `OneSet/Persistence/WorkoutRepository.swift`, `OneSet/Persistence/LocalAccountErasure.swift` (new), `OneSetTests/Persistence/…` (2 new) · **Scope:** M

#### Task 5: Pause uploads per account

**Description:** Add `suspend(accountID:)` and `resume(accountID:)` to `CompletedSessionUploadCoordinator` and `ProgramCycleSyncCoordinator`. While an account is paused, nothing triggers a drain for it, and any drain already running for it finishes or is cancelled before `suspend` returns.

**Acceptance criteria:**
- [ ] Once `suspend` returns, no request goes out for that account until it resumes. Other accounts keep draining.
- [ ] After `resume`, uploads continue under the existing retry rules. Queued records are kept.

**Verification:** `./scripts/validate.sh --focused OneSetTests/CompletedSessionUploadCoordinatorTests OneSetTests/ProgramCycleSyncCoordinatorTests`

**Dependencies:** None · **Files:** `OneSet/Sync/CompletedSessionUploadCoordinator.swift`, `OneSet/Sync/ProgramCycleSyncCoordinator.swift`, matching tests · **Scope:** M

#### Task 6: Deletion service

**Description:** Add the `AccountDeletionService` protocol with HTTP and preview implementations. It calls `DELETE /v1/me` with the signed-in session and returns deleted or failed.

**Acceptance criteria:**
- [ ] The service returns one of: deleted or failed. It never retries.
- [ ] The preview/mock service can be scripted for UI tests (success and failure).

**Verification:** `./scripts/validate.sh --focused OneSetTests/HTTPAccountDeletionServiceTests`

**Dependencies:** API contract from the spec (it can start before Phase 1 lands) · **Files:** `OneSet/Services/Account/AccountDeletionService.swift`, `HTTPAccountDeletionService.swift`, `PreviewAccountDeletionService.swift` (new) · **Scope:** M

#### Task 7: Account deletion model

**Description:** Add `@MainActor @Observable AccountDeletionModel`. It works out the blocking states (offline, active workout) and the unsynced warning. When the user confirms, it pauses uploads, calls the service, and on 200 runs local erasure and signs out. On any other outcome it resumes uploads and shows the failure.

**Acceptance criteria:**
- [ ] Each phase works as the spec describes, including offline and active-workout blocking and the unsynced warning.
- [ ] Uploads are paused before the request and resumed after a failure. A failure erases nothing locally.
- [ ] Only a 200 leads to local erasure and sign-out.

**Verification:** `./scripts/validate.sh --focused OneSetTests/AccountDeletionModelTests`

**Dependencies:** T4, T5, T6 · **Files:** `OneSet/Features/Onboarding/AccountDeletionModel.swift` (new), `OneSetTests/Features/AccountDeletionModelTests.swift` (new) · **Scope:** S

#### Task 8: Account deletion screen and route

**Description:** Build `AccountDeletionScreen` using the copy from the spec. It replaces the placeholder destination in Settings, opens App Store subscription management from **Manage subscription**, and shows the destructive confirmation dialog. Add the `--ui-account-deletion` launch route. Use the `impeccable` skill.

**Acceptance criteria:**
- [ ] The screen matches the spec's copy table and DESIGN.md styling, and each blocking state shows its reason.
- [ ] Settings > Account deletion opens the screen. The existing settings-row expectations still pass.

**Verification:** `./scripts/validate-ui.sh --ui-account-deletion`, then inspect the screenshot, then `./scripts/validate.sh --focused OneSetUITests/OnboardingJourneyTests`

**Dependencies:** T7 · **Files:** `OneSet/Features/Onboarding/AccountDeletionScreen.swift` (new), `SettingsNavigationView.swift`, `SettingsDestination.swift`, `OneSet/App/AppLaunchConfiguration.swift`, `OneSet/App/AppDependencies.swift` · **Scope:** M

#### Task 9: End-to-end journey and Welcome message

**Description:** After deletion, the app returns to Welcome and shows "Your account was deleted." once. Add a UI journey on the mocked backend that covers confirm, cancel, and the blocking states.

**Acceptance criteria:**
- [ ] Confirming leads to Welcome with the message. Relaunching doesn't show it again.
- [ ] Cancelling keeps the account. Being offline or having an active workout disables Delete.

**Verification:** `./scripts/validate.sh --focused OneSetUITests/AccountDeletionJourneyTests`, and a screenshot of the Welcome message.

**Dependencies:** T8 · **Files:** `OneSet/Features/Onboarding/OnboardingFlowView.swift` (or the Welcome screen), `OnboardingModel.swift`, `OneSetUITests/AccountDeletionJourneyTests.swift` (new) · **Scope:** M

### Checkpoint: iOS

- [ ] All focused tests from T4-T9 pass.
- [ ] Screenshots of the deletion screen (normal, blocked, and with the warning) and of Welcome have been inspected.
- [ ] Against the dev Worker: a real deletion from a signed-in session on the simulator.

### Phase 3: Docs and wording

#### Task 10: Update docs and #103

**Description:** Bring the docs in line with the spec:
- `requirements.md`: the account deletion behavior and the active-workout block.
- `api-contracts.md`: the `DELETE /v1/me` contract and the setup guard.
- `system-design.md`: remove the "minimal erasure instruction".
- `sync-and-recovery.md`: note that deletion keeps no records and that restore is a known gap.
- `revenuecat-integration.md`: RevenueCat deletion runs inline and can be repeated safely, with no retry record.

**Ask first:** reword #103's acceptance criteria to match.

**Acceptance criteria:**
- [ ] No doc still describes an erasure record, a tombstone, or a background retry for account deletion.
- [ ] #103 describes the inline, safely repeatable RevenueCat step and the hooks from T2 and T4.

**Verification:** Read the changed files and check their links. No build is needed.

**Dependencies:** T2, T7 · **Files:** the 5 docs above · **Scope:** M

#### Task 11: Privacy policy text

**Description:** Add the account deletion section to the privacy text in `legal/`. It covers how to delete, that everything is removed and nothing is kept, that backups age out on their own, and that subscriptions are canceled separately through Apple. **Ask first** before publishing.

**Acceptance criteria:**
- [ ] The text matches the spec's privacy outline, and the user has approved it.

**Verification:** Review the changed file. Also check the rendered page if `legal/` is deployed.

**Dependencies:** T10 · **Files:** `legal/public/…` · **Scope:** XS

### Checkpoint: Complete

- [ ] `./scripts/validate.sh` passes (final validation: the change spans iOS, Worker, and auth).
- [ ] Every success criterion in SPEC.md is checked.
- [ ] Spec `Status:` is changed to `implemented`, and #102 is closed after review.

## Parallelization

- Three tracks can start together: Phase 1 (T1-T3), and on iOS, T4 and T5. T6 can start alongside them too, because the spec fixes the API contract.
- T7-T9 run in sequence. T10 can be written once T2 and T7 are settled.
- T2 and T3 both touch `account-deletion.ts` and its tests, so the same person or session should do them one after the other.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| A drain already running sends a request after `suspend` returns | Med | T5's acceptance criteria require `suspend` to wait for or cancel running drains, and a test covers it. |
| The sweep fails after Clerk deletion and leaves an orphan row | Low | Accepted in the spec. The failure is logged with the Clerk ID for manual cleanup. |
| A later migration lets `complete_onboarding` create a user row without the guard | Low | T3 has a test that POST setup goes through the guarded insert. Add a comment in `setup.ts`. |

## Open Questions

None for planning. The deploy and secret step, the production Clerk setting, the #103 rewording, and the privacy text are all **ask-first** points during implementation.
