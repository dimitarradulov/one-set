# Clerk development setup

OneSet uses the native ClerkKit SDK for Apple, Google OAuth, and email-code sign-in. The app includes only a Clerk publishable key; never add a Clerk secret key, database URL, or other service credential to the iOS target.

The resolved `clerk-ios` 1.5.8 package supports iOS 17 and newer and requires Xcode 26 / Swift 6.2. OneSet's iOS target and current Xcode toolchain meet those requirements. The app links only the `ClerkKit` product, which provides the custom native flow.

## Development instance

In the Clerk Dashboard, select the development instance and configure:

1. Enable **Native API** under Native applications.
2. Add the OneSet iOS native application using the Apple App ID Prefix and the app's Bundle ID.
3. Require email, enable email as a sign-in identifier, and choose **Email verification code** for sign-in and sign-up verification. Keep password optional or disable it; OneSet does not collect passwords or profile details.
4. Add the Clerk Frontend API domain as an Associated Domain in Xcode using `webcredentials:{YOUR_FRONTEND_API_URL}`.
5. Configure the app with the instance's publishable key in `OneSetApp` and inject `Clerk.shared` into the SwiftUI environment.

The current development instance reports Native API enabled, email verification codes enabled for sign-in and sign-up verification, and email enabled as a first-factor identifier. Password is enabled but is no longer required; first and last name are optional. The app currently uses the Clerk development publishable key already present in its app configuration. Replace it with a placeholder such as `YOUR_CLERK_PUBLISHABLE_KEY` when setting up a different development instance. Publishable keys identify an instance and are safe for client use; secret keys are not.

## Verify the email sign-in round trip

1. Run OneSet on an iOS simulator or device.
2. Select **Log in**, enter an email belonging to a user in the selected Clerk development instance, and select **Send code**. For a new account, select **Continue with email**, submit an unregistered email, then explicitly choose **Create an account**.
3. Retrieve the email code, enter it, and select **Verify code**.
4. Confirm the signed-in account appears. Force-quit and relaunch the app to confirm Clerk restores the session.
5. Select **Sign out** and confirm the app returns to the email-code form.

Clerk request and verification failures remain visible in the OneSet flow. Use a reachable mailbox for a live check and confirm the account appears after verification. If a new-account attempt reports that more information is required, check that the development instance does not require a password, name, or custom sign-up field.

## Native Apple sign-in

Continue with Apple uses ClerkKit's native `signInWithApple(requestedScopes: [.email])` flow. Clerk handles existing and new identities; OneSet then resolves account setup through the same lookup, local resume, Retry, and sign-out flow as email authentication. The app requests no name/profile fields. Cancellation leaves Welcome available; a failure shows an error and permits another attempt. The mocked trial offer does not activate an entitlement.

Required development configuration:

1. In Clerk Native applications, enable Native API and register the iOS app with `YOUR_APP_ID_PREFIX` and `YOUR_BUNDLE_ID`. The App ID Prefix must match the Apple Developer App ID; it is not always the Team ID.
2. In Clerk SSO connections, add Apple and enable it for sign-up and sign-in. Keep password/name fields optional as above.
3. Enable Sign in with Apple for that App ID in Apple Developer and refresh the provisioning profile for device builds. The app's entitlements include `com.apple.developer.applesignin` with `Default` and the Clerk Associated Domain.
4. Native Apple sign-in exchanges an identity token, so it requires no browser callback URL or custom URL scheme. Hosted/web Apple OAuth separately requires Apple Services ID and key configuration. Private relay email delivery has its own Apple Developer configuration. See [Clerk's native Apple guide](https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple).

The development Frontend API was checked on 2026-10-05: Native API and Apple authentication are enabled. A simulator attempt returned the SDK’s native authorization error asking the user to sign in to an Apple account in Settings. The developer subsequently verified live Apple sign-up, sign-in, and sign-out on a physical iPhone and confirmed that all three work as expected. Session restoration after relaunch remains a separate live verification step below.

To verify live integration, run a signed development build (or a simulator signed in to an Apple account), select **Continue with Apple**, complete Apple's sheet, and confirm OneSet opens preferences for a new setup or restores the existing overview. Relaunch to verify session restoration, then use **Sign out**. Repeat after canceling the sheet and after a recoverable provider failure. A physical device check is required before release. Deterministic journey tests verify routing and recovery, but do not establish Apple token exchange or dashboard registration.

For visual inspection, `./scripts/validate-ui.sh --ui-welcome` opens Welcome and `./scripts/validate-ui.sh --ui-apple-auth-error` opens a deterministic Apple failure state. The failure route injects substitutes only in Debug builds.

## Google sign-in

Continue with Google uses ClerkKit's `signInWithOAuth(provider: .google)` browser flow. The resolved SDK supports Google and automatically transfers a new identity from sign-in to sign-up, handles the callback, and activates the completed session. OneSet verifies completion and the authenticated user before routing through the shared account setup lookup. Existing setup restores its unit, frequency, program and cycle; confirmed missing setup enters preferences. Lookup errors retain Retry. Unfinished local onboarding resumes through the existing account-scoped store, including offline. Session restoration and sign-out use the same Clerk session as Apple and email. Cancellation leaves Welcome without an error; recoverable failures show an error and enable another attempt.

Required development configuration:

1. Enable Native API and register the iOS app in Clerk Native applications with `YOUR_APP_ID_PREFIX` and `YOUR_BUNDLE_ID`. Keep the Associated Domain `webcredentials:YOUR_FRONTEND_API_URL` and configure `YOUR_CLERK_PUBLISHABLE_KEY` as described above.
2. Add Google in Clerk SSO connections and enable it for sign-up and sign-in. Development instances can use Clerk's shared Google credentials. Keep password, name and custom profile fields optional so Google can complete the account.
3. In Native applications → Allowlist for mobile SSO redirect, add `YOUR_BUNDLE_ID://callback`. ClerkKit defaults to this callback and uses the bundle identifier as the callback scheme. `Config/Info.plist` registers `$(PRODUCT_BUNDLE_IDENTIFIER)` under `CFBundleURLTypes`, so different bundle IDs use the matching scheme without a hard-coded callback.
4. For production, create a Google Cloud project and OAuth web client, then configure `YOUR_GOOGLE_CLIENT_ID` and `YOUR_GOOGLE_CLIENT_SECRET` in Clerk with the authorized redirect URI shown in the dashboard. See [Clerk's Google connection guide](https://clerk.com/docs/guides/configure/auth-strategies/social-connections/google) and [iOS OAuth guidance](https://clerk.com/docs/ios/guides/configure/auth-strategies/social-connections/overview). This flow needs no Google iOS SDK or Google secret in the app.

The development environment and dashboard were checked on 2026-10-05: Native API is enabled, the iOS bundle is registered, Google is enabled for authentication using shared development credentials, and the app callback is already allowlisted. No dashboard mutation was needed. The live Google round trip is pending developer verification on an iPhone; injected tests do not establish the provider token exchange.

To verify live integration:

1. Run a signed development build with the configured Clerk instance and development Worker. Select **Continue with Google** and complete Google's browser flow. Confirm preferences open for a confirmed new setup, or the existing overview restores preferences without resetting them.
2. Choose preferences and select Continue to save local progress. Force-quit and relaunch; confirm the Clerk session and saved onboarding return. Sign out and confirm Welcome returns, then relaunch to confirm the session stays signed out.
3. Cancel Google's browser and confirm Welcome remains usable without an error. Retry after a recoverable provider error. A setup lookup error should show Retry instead of entering new-account preferences.

For visual inspection, `./scripts/validate-ui.sh --ui-welcome` opens Welcome and `./scripts/validate-ui.sh --ui-google-auth-error` opens a deterministic Google failure state. The failure route injects substitutes only in Debug builds. The trial offer remains mocked; this authentication flow adds no entitlement or custom account-merging behavior.

Keep provider secrets in Clerk/Apple/Google dashboards. Only client identifiers and publishable keys belong in client configuration when the provider's native SDK requires them.
