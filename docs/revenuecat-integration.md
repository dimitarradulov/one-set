# RevenueCat integration for OneSet

This milestone replaces the mocked onboarding trial with Apple subscriptions through RevenueCat. Clerk authenticates the OneSet account. The Worker resolves account setup, RevenueCat verifies subscription access, and OneSet checks Pro before creating a new workout session. Program previews, training history, and resuming, finishing, or syncing a session already underway remain available. See [FR-22 and FR-23](requirements.md).

[Review the subscription mockups](mockups/revenuecat.html) for onboarding, checkout, workout previews, and Settings.

## 1. Configure the products and paywall

1. In RevenueCat, open **Product catalog → Products** and create both products in **Test Store**. In App Store Connect, configure the corresponding auto-renewable subscriptions in the same subscription group and service level. Enable **In-App Purchase** for `com.oneset.OneSet`, connect the Apple app and credentials in RevenueCat, and import the Apple products.

   | Plan | Product ID | Renewal period | Target U.S. price | Introductory free trial | RevenueCat package |
   | --- | --- | --- | --- | --- | --- |
   | Monthly | `monthly` | 1 month | $4.99 USD | 7 days for eligible customers | `$rc_monthly` |
   | Yearly | `yearly` | 1 year | $49.99 USD | 7 days for eligible customers | `$rc_annual` |

2. Create the entitlement `oneset_pro` and attach both products from each store. Create the `default` Offering and map the Monthly and Annual packages to their corresponding products. Have the app request this named offering and check that both packages are present.
3. Publish a paywall for `default` with both plans, a visible close action, **Restore Purchases**, and links to terms and privacy. Display Apple's actual localized price, renewal period, and introductory eligibility. Apple allows one introductory offer per Apple Account per subscription group.
4. Under **Project Settings → General**, select **Keep with original App User ID**. Use the same restore behavior in Apple sandbox. If a purchase or restore is refused because it belongs to a different OneSet account, show “This subscription is linked to another OneSet account. Sign in to that account to use Pro.”

[Product setup](https://www.revenuecat.com/docs/projects/configuring-products) · [Paywall display](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls) · [Restore behavior](https://www.revenuecat.com/docs/projects/restore-behavior) · [Apple introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions)

### Restore after account deletion

The intended way to move a subscription to a new OneSet account is to finish deleting the original account, then sign into the new account and choose **Restore Purchases** with the same Apple Account. While the original account exists, sign in to that account to use Pro.

The account deletion flow is a release dependency. Disable billing actions for the departing account and clear its local access. RevenueCat deletion runs inline in `DELETE /v1/me` through the server hook `cleanupSubscription(clerkUserId)` in [account-deletion.ts](../worker/src/account-deletion.ts), after owned data is erased and before the Clerk identity is deleted. It is safe to repeat: treat a 404 on the customer as already deleted. No retry record is kept and no background job runs. If the call fails, `DELETE /v1/me` responds `503 TEMPORARY_FAILURE` and the user's own repeat attempt retries it. For API v2, a customer lookup returning 404 after the deletion request confirms the customer record is absent. On device, the `AccountDeletionCleanup` step list in [LocalAccountErasure.swift](../OneSet/Persistence/LocalAccountErasure.swift) is where billing actions for the departing account are disabled and its local access is cleared. The deleted OneSet account cannot sign back in because its Clerk identity is deleted.

Apple continues billing until the Apple subscription ends. Verify in Apple sandbox that restoring to a second OneSet account is refused while the first still owns the purchase, and succeeds without a new purchase after deletion completes. RevenueCat's deletion confirmation establishes customer absence. The restore test establishes whether the subscription can move. Publish the move instructions after the test passes.

[RevenueCat customer deletion](https://www.revenuecat.com/docs/dashboard-and-metrics/customer-profile#delete-customer) · [Account deletion design](system-design.md#security-and-operational-boundaries)

## 2. Add the Swift package and configure the build

1. In Xcode, use **File → Add Package Dependencies** to add `https://github.com/RevenueCat/purchases-ios-spm.git`. Add **RevenueCat** and **RevenueCatUI** to the **OneSet** target. The API review used version `5.103.2`. Record the resolved version in the project and package resolution files when implementing. Build the integrated app and run the checks in §5.
2. Define `REVENUECAT_API_KEY` per configuration and read it through the `RevenueCatAPIKey` entry in [Config/Info.plist](../Config/Info.plist) using `$(REVENUECAT_API_KEY)`. Use the public Test Store key in Debug and the public Apple app key for Apple sandbox, TestFlight, and App Store checks. Keep RevenueCat secret keys on the server.
3. Continue using the development Worker and Clerk instance while building and testing. Before enabling real App Store purchases, confirm the launch archive uses a production HTTPS `ONESET_API_BASE_URL`, a publishable key for the matching production Clerk instance, and the RevenueCat Apple public key for `com.oneset.OneSet`. The Worker must accept that Clerk issuer and resolve setup against the production account store. Verify those settings in the archive and follow a fresh account through setup to the trial and Settings screens. Enable live billing only after this check and the receipt ownership checks in §5 pass.

### Test purchases and public access

Use one RevenueCat project for both Test Store and Apple purchases. Allow sandbox access for your test account while developing. Before public launch, set **Sandbox Testing Access** to **Nobody**. The public build's workout access check must require a verified production entitlement. Keep saved test access separate from saved production access.

The Apple public key supports both Apple sandbox and App Store purchases. Before launch, test with your sandbox purchase and the public launch settings. Confirm it leaves workouts locked and cannot create a saved offline access record for the public build.

[Swift Package installation](https://www.revenuecat.com/docs/getting-started/installation/ios#install-via-swift-package-manager) · [Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store) · [Sandbox Testing Access](https://www.revenuecat.com/docs/projects/sandbox-access)

## 3. Own subscription access at the app boundary

### Account and receipt ownership

Use one app-scoped owner for RevenueCat configuration, account selection, purchases, and restores. Begin with the resolved Clerk user ID as the identified RevenueCat App User ID. Configure the SDK only after authenticated account setup resolves. Use an identified login when the selected account changes and check that the SDK account matches before starting an operation.

Have the owner approve paywall purchases and restores through `onPurchaseInitiated` and `onRestoreInitiated`. Route Settings restore through the same owner. Capture the account and its selection generation at initiation, recheck verified inactivity before purchase, and let only one purchase or restore run at a time. Release the operation on success, failure, cancellation, or transition to pending approval. Defer explicit sign-out and SDK identity switches while an interactive operation is running. If Clerk loses or changes identity independently, immediately remove the old account's controls and in-memory access, then wait until the operation clears before activating the next SDK identity. Ignore late callbacks from earlier selections, even when the same account signs back in.

Keep pending approval visible for the initiating account across relaunch. Show **Waiting for purchase approval** and provide a status check. Keep checkout unavailable while that payment or a confirmed charge is still unresolved. Test a first pending purchase after a switch or relaunch on a different account. Decide whether OneSet needs a separate permanent billing ID based on the result. If the Clerk ID fails the test, confirm a supported way to attach the original OneSet account with RevenueCat, implement it, and repeat the test before enabling live purchases. If an account migration changes the Clerk subject after launch, preserve the original billing association through a verified mapping.

[Identify customers](https://www.revenuecat.com/docs/customers/identifying-customers) · [Paywall initiation hooks](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls#intercepting-an-initiated-purchase) · [Purchase errors](https://www.revenuecat.com/docs/test-and-launch/errors)

### One access decision for workouts and checkout

Have OneSet await the same access check for each account and share a check already in progress. Await the account connection before deciding. Refresh when the app returns to the foreground and after purchases and restores. Apply updates only to the active account selection.

| Result | Action |
| --- | --- |
| Pro verified through a future date | Allow a new workout, including offline with valid saved access. |
| A fresh check verifies no active Pro | Offer checkout if no payment or approval is pending. |
| Access cannot be confirmed | Show retry or account recovery. Keep checkout unavailable until the current check verifies inactivity. |

Apply the decision in the shared [start workout command](../OneSet/Features/Onboarding/OnboardingModel%2BWorkouts.swift) and at the trial and Settings checkout entry points. Resume an existing session under the existing ownership rules. For a new session, capture the account, program, cycle, workout occurrence, and preview request before checking. Recheck these immediately before saving, and check whether a session now exists. Use the same result handling in both workout preview routes. After checkout, return to the still-valid preview so the user can tap **Start** again. The access check governs new local sessions. Protected media requests and historical uploads follow the [server rules](system-design.md#authentication-and-subscription).

### Save the last verified expiry

Persist the last accepted observation in OneSet-owned storage, keyed by account and billing environment. Record when the result was checked and the verified expiry or inactive status. Write only for the current account selection. A newer server-verified active result replaces the expiry. A newer server-verified inactive result clears access and prevents an older response from restoring it.

Failed checks and on-device-only verification leave the last confirmed expiry in place and cannot extend it. Read the saved record after the matching signed-in account is established. Allow an offline start only before the verified expiry. Require a fresh check before checkout even if a saved result says inactive. Remove saved subscription access on confirmed sign-out or account deletion. Session recovery, completion, and sync continue under their existing rules.

[CustomerInfo](https://www.revenuecat.com/docs/customers/customer-info) · [Trusted Entitlements](https://www.revenuecat.com/docs/customers/trusted-entitlements)

## 4. Connect the trial, checkout, and Settings

1. Wire the account-scoped service into [OneSetApp](../OneSet/App/OneSetApp.swift). Inject it through [AppDependencies](../OneSet/App/AppDependencies.swift). Provide preset active, inactive, checking, failed, and pending states for previews and tests. Keep development preview routes and automated tests off RevenueCat.
2. Use the shared start decision from [OnboardingFlowView](../OneSet/Features/Onboarding/OnboardingFlowView.swift) and [CompletedSetupTabsView](../OneSet/Features/Onboarding/CompletedSetupTabsView.swift). Clear the old path's subscription presentation when the account changes.
3. On the trial screen, show a spinner while access is checked. Once Pro is confirmed, use the existing [local setup save and upload flow](../OneSet/Features/Onboarding/OnboardingModel.swift) and open the program. Check that the account, selected program, and trial route still match. Complete setup once, whether verification follows initial load, a purchase, restore, or a later update. If the check confirms inactivity, show the payment option. On failure, replace the spinner with **Try Again**. Keep **Continue Without Trial** available.
4. Use RevenueCatUI's `PaywallView` for the named offering. Have the OneSet parent screen own Close, Restore Purchases, and the path to Manage Subscription, including when an offering is missing or RevenueCatUI falls back to its default paywall. After Apple confirms a purchase, show the spinner on the parent screen until OneSet verifies Pro. If verification fails, **Try Again** checks access without reopening checkout. If setup save fails after Pro is verified, let the user retry the save.
5. Replace the [Subscription placeholder](../OneSet/Features/Onboarding/SettingsNavigationView.swift) with **Restore Purchases** and **Manage Subscription**. Use the shared account owner for restore and Apple's subscriptions screen for management. Show restore and verification status in Settings.

## 5. Verify before release

| Where | What to verify |
| --- | --- |
| Automated app tests | Cover active, inactive, failed, and pending checks in the trial, both workout preview routes, and Settings. Exercise stale replies after an account or program change, attempts to start while a check is in progress, and return to Preview after purchase. Relaunch offline before and after expiry, including after a failed verification. Cover verified inactivity replacing saved access, setup-save retry after confirmed payment, and resuming, finishing, and syncing after expiry. |
| Test Store | Buy both packages. Verify each maps to `oneset_pro` and allows a new workout after verification. Cover checkout cancellation, missing packages, invalid entitlement mapping, and missing or unsupported paywalls. |
| Apple sandbox | Verify both plans' local price, trial eligibility, renewal terms, changes between plans, and management. Restore through Settings and the paywall. Exercise no active purchase, account switching during purchase or restore, involuntary sign-out, and same-account re-entry. Have account A start a first purchase requiring approval, then switch to B or relaunch as B before approval. Confirm A alone gets Pro. Test one Apple Account with two OneSet accounts and two Apple Accounts with one OneSet account. Verify the app checks access before checkout. Complete the delete-then-restore test, including pending and failed deletions, before publishing recovery instructions. |
| TestFlight and App Store | Verify the release archive's Worker URL, Clerk instance, RevenueCat key, and bundle ID. Follow a fresh account through setup to the trial screen and Settings in TestFlight. Before public launch, confirm the sandbox-only purchase cannot unlock a workout or save public offline access with sandbox grants disabled. During the App Store rollout, verify a production purchase, restoration, management, and a gated workout start. |

Update the affected expectations in `testMockedTrialAcceptanceRetriesUploadWithoutGrantingEntitlement` and `testCompletedAccountRestoresOverviewFromEmail`. Re-run `testTrialBypassOpensSelectedProgramOverviewAndSwitchesRotationWeeks`, `testFailedCompletionSaveKeepsTrialAndDoesNotPersistOverview`, `testPreviewResumesActiveWorkout`, `testProgramChangeBlocksStartFromOpenPreview`, and `testAccountChangeResetsBothTabStacksAndSelectsProgram`.

Run the [full repository validation](agents/validation.md) after implementation. Inspect the trial, both workout preview routes, and Settings on iPhone and iPad.
