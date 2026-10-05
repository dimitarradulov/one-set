# Account setup lookup

Implemented by [the Worker](../worker/src/setup.ts) and the app's [HTTP adapter](../OneSet/Services/Account/HTTPAccountSetupService.swift) for [issue #10](https://github.com/dimitarradulov/one-set/issues/10). Other routes in [the API proposal](api-contracts.md) remain proposals.

`GET /v1/me/setup` requires `Authorization: Bearer YOUR_CLERK_SESSION_TOKEN`. Verify the token signature, issuer, validity window, active session claims and any authorized-party claim. Derive ownership solely from verified `sub`; URL parameters and client owner claims cannot select another account. Responses use `Cache-Control: private, no-store`.

Successful completed setup:

```json
{
  "setup": {
    "preferred_unit": "lb",
    "training_days": 5,
    "program_id": "machine-full-body",
    "cycle_id": "11111111-1111-4111-8111-111111111111"
  }
}
```

A confirmed new/unfinished account returns `200 {"setup":null}`. Invalid authentication returns `401` with `{"error":{"code":"AUTH_REQUIRED"}}`. Database/configuration failures return `503 TEMPORARY_FAILURE`; inconsistent active-cycle ownership or an unmapped program returns `503 SETUP_UNAVAILABLE`. Error responses never contain setup or credentials. Missing/malformed successful bodies are failures in the app.

The app resolves setup after session restoration or either email authentication action. Completed setup restores units, frequency, selected bundled program and the existing cycle identity, then opens overview. Confirmed absence resumes unfinished progress saved for that account, or starts preferences. Failed lookup resumes valid local progress when available; otherwise it exposes Retry and Sign out.

Lookup is a single consistent, owner-scoped read of `users` and its active owned `user_programs` cycle. It neither creates enrollment/cycles nor reads or edits workout history. The schema already stores all required fields; no migration is needed. Numeric database catalog IDs are mapped explicitly to bundled IDs through Worker configuration; see [development setup](../worker/README.md).

Account changes cancel the view task. The workflow also checks a request generation and the current authenticated account before applying a result, including results from substitutes that ignore cancellation. Sign-out clears all account presentation choices. The trial remains mocked.

For visual inspection use `--ui-account-setup-error`, or launch with `--ui-auth-test --ui-auth-restored --ui-setup-completed` to inspect a restored overview. These substitutions exist only in Debug builds.

## Unfinished local onboarding

[Issue #11](https://github.com/dimitarradulov/one-set/issues/11) adds an injected [local progress store](../OneSet/Persistence/FileOnboardingProgressStore.swift). Its versioned JSON file in Application Support is replaced atomically, with account IDs as keys. The directory is excluded from device backups so unfinished progress stays on this device. Intermediate steps never call the backend; the same atomic document now holds completed setup and its pending upload. Unreadable or unsupported files surface an error and are not deleted automatically.

The first preferences step is recorded after confirmed absence of completed setup. Units and frequency save together on Continue, before navigating to program selection. Selecting a program saves its ID before opening the mocked trial offer. Reopening resumes the first unfinished step; changing a preference without Continue does not save a checkpoint. Completed backend setup takes priority over unfinished local choices. Continuing from the mocked trial offer saves completed setup before opening overview; reopening restores overview.

Sign-out removes only that account's unfinished onboarding. If removal fails, the app explains the failure and keeps the session. If authentication sign-out fails, the app attempts to restore the removed progress and reports any storage failure. No workout store is touched. Lookup generation and account checks prevent late responses from applying after sign-out or account changes.

Journey tests use a separate preview file, cleared by default. `--ui-progress-keep` retains it across test relaunches; `--ui-progress-reset` clears it explicitly. `--ui-setup-offline` simulates an unavailable backend. `--ui-progress-save-error` opens authenticated preferences with a storage substitute that rejects Continue saves, allowing inspection of the save-error alert. All substitutions remain Debug-only.

## Completed setup save

[Issue #12](https://github.com/dimitarradulov/one-set/issues/12) implements `PUT /v1/me/setup` with the same authentication and response shape as GET. Send only `preferred_unit`, `training_days`, `program_id` and `cycle_id`. Units must be kg/lb, frequency an integer from 2–5, program a configured bundled ID and cycle a UUID generated once on this device. Bodies are limited to 2 KiB; unknown fields and invalid payloads return `400 INVALID_SETUP`. Ownership comes exclusively from the verified token.

Apply [migration 002](database/migrations/002_completed_setup.sql) before deploying this handler. The database command atomically creates first setup under an account-row lock. If the account already has an active or historical cycle, it preserves that state and returns current setup. A retry never creates another cycle or resets established settings. Inconsistent established state still returns `503 SETUP_UNAVAILABLE` and is never replaced with new setup.

At the offer acceptance or dismissal boundary the app atomically writes choices, a stable cycle identity and pending-upload flag before showing overview. Failed local saves retain the trial screen and explain the failure. This additive local document format also reads existing unfinished progress. The HTTP adapter sends the durable payload; a successful acknowledgment is persisted before clearing the pending flag. Failure or interrupted acknowledgment keeps the same payload for retry.

Uploads retry immediately on completion, after authenticated restoration, on foreground entry, every 15 seconds while the signed-in flow is active, and through Retry upload. Offline overview and workout previews remain available. Another device restores setup after successful upload. Existing backend setup wins if another device completed first. Upload results check account and request generation before changing local state; screen navigation does not own the pending upload.

Sign-out with pending completed setup presents Cancel or Sign out and discard. Cancel preserves the record. Confirmed sign-out removes only that account’s onboarding document, including its pending upload; workout data is outside this store. Failed sign-out attempts restore the removed record and report failures. An already-sent request may have reached the backend even if its acknowledgment was lost; discarding local state cannot undo a server commit.

Use `./scripts/validate-ui.sh --ui-setup-upload-pending` and `--ui-setup-upload-discard` for deterministic visible pending/retry and discard-confirmation states. These routes, shared preview backend and identity substitutes are Debug-only. Journey tests clear local data to represent another device while retaining the preview backend; API tests separately establish actual PostgreSQL save and retry behavior.
