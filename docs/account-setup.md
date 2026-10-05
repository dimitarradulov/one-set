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

[Issue #11](https://github.com/dimitarradulov/one-set/issues/11) adds an injected [local progress store](../OneSet/Persistence/FileOnboardingProgressStore.swift). Its versioned JSON file in Application Support is replaced atomically, with account IDs as keys. The directory is excluded from device backups so unfinished progress stays on this device. Only unfinished onboarding is stored; intermediate steps never call the backend. Unreadable or unsupported files surface an error and are not deleted automatically.

The first preferences step is recorded after confirmed absence of completed setup. Units and frequency save together on Continue, before navigating to program selection. Selecting a program saves its ID before opening the mocked trial offer. Reopening resumes the first unfinished step; changing a preference without Continue does not save a checkpoint. Completed backend setup takes priority over unfinished local choices. Overview completion and pending uploads remain work for issue #12; reopening after the mocked trial dismissal currently resumes the saved trial step.

Sign-out removes only that account's unfinished onboarding. If removal fails, the app explains the failure and keeps the session. If authentication sign-out fails, the app attempts to restore the removed progress and reports any storage failure. No workout store is touched. Lookup generation and account checks prevent late responses from applying after sign-out or account changes.

Journey tests use a separate preview file, cleared by default. `--ui-progress-keep` retains it across test relaunches; `--ui-progress-reset` clears it explicitly. `--ui-setup-offline` simulates an unavailable backend. `--ui-progress-save-error` opens authenticated preferences with a storage substitute that rejects Continue saves, allowing inspection of the save-error alert. All substitutions remain Debug-only.
