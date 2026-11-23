# Spec: Account Deletion - V1

Status: proposed
Issue: [#102](https://github.com/dimitarradulov/one-set/issues/102) · Unblocks: [#103](https://github.com/dimitarradulov/one-set/issues/103) (RevenueCat customer deletion)

## Objective

Account deletion is required for release (App Store Review Guideline 5.1.1(v)). The app has to let a signed-in user delete their OneSet account from inside the app. Today Settings shows only the `accountDeletion` placeholder ([SettingsDestination.swift](OneSet/Features/Onboarding/SettingsDestination.swift)), and the Worker has no erasure route (`DELETE /me` is listed as proposed in [api-contracts.md](docs/api-contracts.md)).

**User:** a signed-in OneSet user, with or without an active subscription, who wants their account and training data gone.

**User story:** In Settings > Account deletion, I can read what will be deleted and see that my Apple subscription is canceled separately. I confirm my identity, then delete. When that finishes I'm signed out, my data is gone from the server and this device, and that account can't be signed into again.

### Decisions

| Topic | Decision |
| --- | --- |
| Spec shape | One spec, delivered in three phases (below). |
| Clerk identity | The Worker deletes the Clerk user through the Clerk Backend API. |
| Reauthentication | None. `DELETE /v1/me` relies on the authenticated Clerk session only. The in-app confirmation dialog is the guard against accidental deletion. |
| Deletion records | None are kept. No erasure table, ledger, or tombstone of any kind. The Postgres transaction is the consistency guarantee. |
| Retries | No background retry. Every step of `DELETE /v1/me` is idempotent, so the user's own repeat attempt is the retry. |
| Active workout | Deletion is blocked until the workout is finished or discarded. |
| Disaster restore | Out of scope (see Deferred). |
| Copy | Drafted in this spec (see [Copy](#copy)). |

### Assumptions (correct these during review)

1. **The same email can register again.** That creates a new Clerk user and therefore a new, empty OneSet account.
2. **Unsynced completed sessions trigger a warning but don't block deletion.** They would be deleted anyway.
3. **Leftover risk from stale tokens is accepted.** The race with stale tokens is closed in [Stale-token guard](#server-stale-token-guard). The only remaining case is when the sweep step fails right after a stale request inserted a row. That row can't be reached by any login and is removed by hand.

## Tech Stack

- iOS: SwiftUI, Swift 6, GRDB, ClerkKit/ClerkKitUI ([ClerkAuthenticationService](OneSet/Services/Identity/ClerkAuthenticationService.swift))
- Worker: Cloudflare Workers (TypeScript), `@clerk/backend` ^3.22, `@neondatabase/serverless` (Postgres via `DATABASE_URL`, batched `sql.transaction`), Wrangler from `worker/`
- New Worker secret: `CLERK_SECRET_KEY`, used for Backend API user deletion. It is set with `wrangler secret put` and never stored in the app or the repository.
- No schema migration. Erasure deletes existing rows only.

## Commands

```sh
# Worker
npm ci --prefix worker
npm --prefix worker run typecheck
npm --prefix worker test

# iOS build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OneSet.xcodeproj -scheme OneSet \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Focused iOS checks (selectors are created in Phase 2)
./scripts/validate.sh --focused OneSetTests/AccountDeletionModelTests OneSetUITests/AccountDeletionJourneyTests

# Visual check of the new screen (route added in Phase 2)
./scripts/validate-ui.sh --ui-account-deletion

# Final validation (spans iOS, Worker, auth)
./scripts/validate.sh
```

## Behavior

### Server: `DELETE /v1/me`

1. Verify the Clerk session with the existing `authenticateClerkRequest`.
2. **Erase data.** In one Postgres transaction, delete every row the user owns: `completed_workouts`, `workout_session_sets`, `workout_sessions`, `user_workout_exercises`, `user_program_workout_periods`, `user_programs`, and `users`. Run this as one batched `sql.transaction`, so either all rows go or none do. If the user has no rows (a repeat attempt), it succeeds without doing anything.
3. **Subscription cleanup hook.** `cleanupSubscription(clerkUserId)` is a no-op in V1. #103 fills it in with RevenueCat customer deletion, which must also be idempotent (treat 404 as done).
4. **Delete the identity.** Call Clerk Backend API `DELETE /users/{id}`. A 404 counts as success. This comes after erasure because once the Clerk user is gone the client can't authenticate to retry anything.
5. **Sweep.** Run the step 2 erasure transaction again. It removes any row that a stale token's setup request inserted while deletion was running (see [Stale-token guard](#server-stale-token-guard)). Normally it deletes nothing.
6. Respond `200 { status: "deleted" }` with `Cache-Control: private, no-store`.
7. **On failure,** respond with the existing error shape: `503 TEMPORARY_FAILURE` for a database or upstream failure. Steps that already finished stay finished.
   - **Failure before step 4:** every step is idempotent, so the user's next `DELETE /v1/me` picks up where the last one stopped.
   - **Failure in step 5:** the identity is already gone, so the client can't retry. A row can be left only if a stale request inserted one during the race. It can't be reached by any login. The error is logged with the Clerk user ID only, so an operator can remove the row by hand. The response is still `200`, because the deletion itself is complete.

### Server: stale-token guard

Clerk session tokens are verified without a network call and stay valid for up to about 60 seconds after the Clerk user is deleted. The only code that creates a `users` row is the provisioning insert in [setup.ts](worker/src/setup.ts) (`INSERT ... ON CONFLICT DO NOTHING`), which runs on setup GET and POST, plus the same insert inside `public.complete_onboarding`. Every other route needs an existing `users` row, so it can't bring an account back. The guard works like this:

1. **Insert, then confirm.** The setup route's insert uses `RETURNING id` to learn whether it created the row.
   - Row already existed: continue as today, with no extra call.
   - Row created: call Clerk Backend API `GET /users/{id}`. If that returns 404, delete everything owned by that subject (the same erasure transaction) and respond `401 AUTH_REQUIRED`. Any other Clerk failure also deletes the new row and responds `503 TEMPORARY_FAILURE`, so the client retries later.
   - **Erase retry:** if that erase transaction fails, it is retried once. If it fails twice, the response is `503 TEMPORARY_FAILURE` and the new row stays. Later setups skip the Clerk check for an existing row, so that unconfirmed row could revive a deleted account for a stale token. The failure is rare (two consecutive database errors right after a Clerk response), is accepted, and is removed by hand like the sweep leftover.
2. **POST setup** runs the guarded insert before `complete_onboarding`, so the function only ever finds an existing row and never creates a new one itself.
3. **Why this closes the race:** deletion runs erase, then the Clerk delete, then the sweep. A stale insert that lands after the Clerk delete fails its own check and removes itself. One that lands before the Clerk delete also lands before the sweep, and the sweep removes it.

The cost is one Clerk call each time a new account is set up. Logins to existing accounts are unchanged.

**Why there is no background retry:** retries are only needed when the Clerk or RevenueCat call fails after the data has already been erased. The account is then empty but still exists, and the app keeps showing the deletion screen with Retry. If the user gives up at that point, an empty Clerk identity with no OneSet data remains. That is accepted.

### App: Settings > Account deletion

The screen replaces the placeholder and has these parts:

- **What gets deleted:** programs, workout history, progress, and app preferences, on the server and on this device. The account can't be recovered.
- **Subscription notice:** deleting the account does not cancel an Apple subscription. The notice includes a **Manage subscription** action that opens App Store subscription management.
- **Unsynced warning:** shown when there are completed sessions that haven't uploaded yet. They will be permanently lost.
- **Blocking states, which disable Delete and show the reason:**
  - Offline.
  - An active workout exists. The user is told to finish or discard it first, with a link to the workout.
- **Delete account** (destructive): opens a confirmation dialog with Cancel.

After confirmation:

1. Suspend the upload coordinator for this account, so no setup, cycle, or session upload can run during or after erasure.
2. Call `DELETE /v1/me`. If it fails, resume uploads and change nothing.
3. On `200`, erase this account's local state:
   - Workout repository rows and the upload queue for the account
   - The onboarding progress file
   - Saved subscription access and pending subscription operations
   - Cached History, progress, and previous performance

   Then sign out of Clerk locally and return to Welcome with a one-time deleted message.
4. Only HTTP `200` counts as deleted; any other response, including other `2xx` codes, leaves local data intact. On failure, erase nothing locally, resume uploads in the background, and show the error with Retry. The account stays signed in.
5. **Cleanup failure.** If the server returned `200` but erasing local data or signing out fails, the account is already deleted on the server and the request must not be sent again. The screen shows the cleanup failure copy with Retry, and Retry repeats only local cleanup. Uploads stay paused.

Local erasure only touches data scoped to the deleted account. Other accounts' data on the device is left alone.

**App hook for #103:** local erasure goes through a single `AccountDeletionCleanup` step list, so #103 can add "disable billing actions for the departing account" without changing the flow.

### Copy

This is the in-app copy. Keep it plain and short.

| Element | Text |
| --- | --- |
| Screen title | Delete account |
| What gets deleted | Deleting your account permanently removes your programs, workout history, progress, and settings from OneSet and from this device. This can't be undone. |
| Subscription notice | Deleting your account doesn't cancel your subscription. Apple keeps billing you until you cancel it in your Apple Account settings. |
| Subscription action | Manage subscription |
| Unsynced warning | Some finished workouts haven't been saved to your account yet. They'll be deleted too. |
| Active workout block | Finish or discard your current workout before deleting your account. |
| Offline block | Connect to the internet to delete your account. |
| Button | Delete account |
| Confirmation title | Delete your account? |
| Confirmation message | Your programs, history, and progress will be permanently deleted. |
| Confirmation actions | Delete account (destructive), Cancel |
| Failure | Your account couldn't be deleted. Check your connection and try again. |
| Retry button | Retry |
| Cleanup failure | Your account was deleted, but this device couldn't finish signing you out. Try again. |
| Welcome message | Your account was deleted. |

For the privacy policy in `legal/`, add a short section with this content:

- How to delete an account: Settings > Account deletion.
- What is removed: all training data and app preferences, and the sign-in account itself.
- What is kept: nothing. Deletion leaves no record in OneSet's database.
- Encrypted operational backups age out on their own schedule. Deleted data is not restored from them.
- Subscriptions are canceled separately through Apple.

## Delivery phases

| Phase | Scope | Done when |
| --- | --- | --- |
| 1. Worker | `DELETE /v1/me`, transactional erasure, the subscription hook, Clerk user deletion, the sweep, the stale-token guard on setup, and the `CLERK_SECRET_KEY` secret | Worker tests below pass. Deployed to `development` and exercised with a real dev Clerk user. |
| 2. iOS | Account deletion screen and model, blocking states, upload suspension, local erasure, Welcome message, UI route, and tests | Focused iOS tests pass, and the screenshot has been reviewed (`impeccable` skill). |
| 3. Docs | Update [requirements](docs/requirements.md), [api-contracts](docs/api-contracts.md), and [system-design](docs/system-design.md#security-and-operational-boundaries), removing the "minimal erasure instruction". Update [revenuecat-integration](docs/revenuecat-integration.md) and the #103 acceptance criteria: there is no retry record, and RevenueCat deletion runs inline and idempotently. Update [sync-and-recovery](docs/sync-and-recovery.md) and the `legal/` privacy text. | The docs agree with this spec, and #103 is updated. |

## Project Structure

```text
worker/src/account-deletion.ts        → DELETE /v1/me: erasure, hook, Clerk deletion
worker/src/index.ts                   → route
worker/src/setup.ts                   → guarded provisioning insert (confirm with Clerk only for new rows)
worker/tests/account-deletion.test.ts → Worker tests
OneSet/Features/Onboarding/           → AccountDeletionScreen, AccountDeletionModel (next to SettingsNavigationView)
OneSet/Services/Account/              → AccountDeletionService (HTTP)
OneSet/Persistence/                   → account-scoped local erase on each store
OneSet/Sync/                          → suspend/resume uploads for an account
OneSetTests/AccountDeletionModelTests.swift, OneSetUITests/AccountDeletionJourneyTests.swift
```

## Code Style

Follow [iOS architecture](docs/agents/architecture.md). The model is `@MainActor @Observable`, owned once and injected. The service is a protocol so previews and UI tests can use a mocked backend.

```swift
@MainActor @Observable
final class AccountDeletionModel {
  enum Phase: Equatable { case idle, blocked(Reason), confirming, deleting, failed }
  private(set) var phase: Phase = .idle

  func confirmDeletion() async {
    phase = .deleting
    await uploads.suspend(for: account)
    do {
      try await deletion.deleteAccount()        // deleted or failed
      try await localErasure.eraseAccount(account)
      await authentication.signOutAfterDeletion()
    } catch {
      await uploads.resume(for: account)
      phase = .failed
    }
  }
}
```

Worker errors use the existing `{ error: { code } }` shape and `Cache-Control: private, no-store`. Project text uses plain hyphens and keeps em dashes rare.

## Testing Strategy

- **Worker (`node:test` via `tsx`):**
  - Erasure deletes every owned table and leaves other users untouched.
  - A failing statement rolls back the whole erasure.
  - Clerk success returns 200, and a Clerk 404 is also 200.
  - A Clerk failure after erasure returns 503, and a repeat call deletes the identity and returns 200.
  - A repeat call with no rows left is a no-op that still deletes the identity.
  - The call order is erase, then hook, then Clerk, then sweep.
  - Stale-token race, insert before the Clerk delete: a row a setup request created between the erase and the Clerk delete is gone after the sweep.
  - Stale-token race, insert after the Clerk delete: setup with a still-valid token creates the row, Clerk returns 404, the row is removed, and the response is 401.
  - Setup for an existing row makes no Clerk call. Setup for a new row whose Clerk check fails (5xx) removes the row and returns 503.
  - POST setup for a new user goes through the guarded insert before `complete_onboarding`.
- **iOS unit (Swift Testing):**
  - The model's phases, including the blocking states for offline and an active workout.
  - A failure erases nothing locally and resumes uploads.
  - Uploads are suspended before the request.
  - Local erasure removes only the deleted account's repository rows, queue, onboarding file, and saved access.
- **iOS UI (XCUITest, mocked backend):**
  - Settings > Account deletion > confirm > Welcome shows the deleted message.
  - Cancel at confirmation keeps the account.
  - Offline and an active workout both disable Delete.
  - Update `OnboardingJourneyTests` settings-row expectations if the row changes.
- **Manual (dev Clerk instance):**
  - A deletion request from a signed-in session.
  - The deleted user can't sign in again.
  - The same email can sign up as a new empty account.

## Boundaries

- **Always:**
  - Erase server data in one transaction.
  - Delete the Clerk identity last.
  - Keep every step idempotent.
  - Scope local erasure to the deleted account.
  - Never log workout contents or tokens.
  - Run the validation scope from `docs/agents/validation.md`.
- **Ask first:**
  - Any `wrangler.jsonc` change beyond adding the secret.
  - Publishing the privacy policy change.
- **Never:**
  - Keep a deletion record, tombstone, or ledger.
  - Add a background retry job.
  - Soft-delete user training data.
  - Put `CLERK_SECRET_KEY` or a RevenueCat secret in the app or the repository.
  - Cancel or alter the Apple subscription from the app.
  - Erase local data when the server call didn't return 200.

## Success Criteria

- [ ] A successful call leaves no rows for that user in any table and deletes the Clerk user. No other record of the account exists afterwards.
- [ ] A failure partway through leaves the database either fully erased or untouched, never partly erased. A repeat call completes the deletion.
- [ ] The deleted account can't sign in again (manual check on dev Clerk).
- [ ] A sign-in token issued before deletion can't bring the account back. Setup with a token for a deleted Clerk user leaves no `users` row and returns 401, and the sweep removes rows inserted during deletion.
- [ ] Setup for an existing account makes no Clerk API call.
- [ ] The app shows the deletion screen with the approved copy: the subscription notice with a working Manage subscription action, the unsynced warning when it applies, and Delete disabled when offline or when an active workout exists.
- [ ] No upload runs for the account between confirmation and sign-out.
- [ ] After deletion, the device holds no data for that account, the user is signed out on Welcome with the deleted message, and other accounts' local data is unchanged.
- [ ] Any response other than 200 leaves local data intact.
- [ ] #103 can attach its RevenueCat cleanup to both the server and app hooks without restructuring the flow.
- [ ] Worker tests, focused iOS tests, UI screenshot review, and final validation all pass.

## Out of Scope (Deferred)

- **Disaster-restore protection.** With no deletion records, restoring an older Postgres backup would bring back deleted accounts' data. Those accounts have no Clerk identity, so nobody can reach the data, but it would still exist. Address this before enabling operational restore ([sync-and-recovery](docs/sync-and-recovery.md)).
- **RevenueCat customer deletion and disabling billing actions.** Owned by #103, which builds on this spec's hooks.
- **Delete-then-restore Apple sandbox test.** Owned by #104.
- **A grace period or undo window.** Requirements exclude user-facing recovery.
- **Data export before deletion.** CSV/export is a requirements non-goal.
- **Deleting accounts through support or the dashboard.**

## Open Questions

None. All five earlier questions are resolved in [Decisions](#decisions) and [Copy](#copy).
