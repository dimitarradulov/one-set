# Clerk development setup

OneSet uses the native ClerkKit SDK for iOS email-code sign-in. The app includes only a Clerk publishable key; never add a Clerk secret key, database URL, or other service credential to the iOS target.

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

## Later Apple and Google provider work

The current app buttons for Continue with Apple and Continue with Google remain demo routes. Provider configuration and native UI are not part of this email sign-in ticket.

- **Apple:** add the app under Clerk's Native applications, enable Apple for sign-up and sign-in, add the Sign in with Apple capability, and use ClerkKit's native `signInWithApple()` flow. Production/web-based OAuth also needs Apple Services ID and key configuration; private relay email delivery has separate Apple Developer setup. See [Clerk's native Apple guide](https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple).
- **Google:** add the iOS app to Clerk's Native applications and enable Google for sign-up and sign-in. For native OAuth, allowlist the app callback URI `{BUNDLE_ID}://callback` in Clerk's Native applications settings; development instances use shared Google credentials. For production, create a Google Cloud project and OAuth client credentials, then configure the web client ID and secret in Clerk. See [Clerk's Google connection guide](https://clerk.com/docs/guides/configure/auth-strategies/social-connections/google) and [iOS social connection guidance](https://clerk.com/docs/ios/guides/configure/auth-strategies/social-connections/overview).

Keep provider secrets in Clerk/Apple/Google dashboards. Only client identifiers and publishable keys belong in client configuration when the provider's native SDK requires them.
