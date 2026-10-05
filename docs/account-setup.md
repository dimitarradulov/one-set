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

The app resolves setup after session restoration or either email authentication action. Completed setup restores units, frequency, selected bundled program and the existing cycle identity, then opens overview. Only confirmed absence starts preferences. Failed lookup exposes Retry and Sign out. Local unfinished-progress fallback belongs to issue #11; this ticket does not create local persistence.

Lookup is a single consistent, owner-scoped read of `users` and its active owned `user_programs` cycle. It neither creates enrollment/cycles nor reads or edits workout history. The schema already stores all required fields; no migration is needed. Numeric database catalog IDs are mapped explicitly to bundled IDs through Worker configuration; see [development setup](../worker/README.md).

Account changes cancel the view task. The workflow also checks a request generation and the current authenticated account before applying a result, including results from substitutes that ignore cancellation. Sign-out clears all account presentation choices. The trial remains mocked.

For visual inspection use `--ui-account-setup-error`, or launch with `--ui-auth-test --ui-auth-restored --ui-setup-completed` to inspect a restored overview. These substitutions exist only in Debug builds.
