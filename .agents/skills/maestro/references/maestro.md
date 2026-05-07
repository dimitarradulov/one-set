# Maestro Reference

Official docs: https://docs.maestro.dev/

## What Maestro Is

Maestro is a YAML-based UI automation framework for mobile and web. It works at
the UI layer, so the same approach applies across Android, iOS, React Native,
Flutter, and web apps.

## Flow Structure

- A Flow is a YAML test script that describes a user journey.
- A Flow usually has a config section, then `---`, then the command list.
- Common config keys include `appId`, `name`, `tags`, and `env`.
- Commands are declarative steps such as `launchApp`, `tapOn`, and
  `assertVisible`.

Example:

```yaml
appId: com.example.app
name: Login Flow
tags:
  - smoke
env:
  USERNAME: john
---
- launchApp:
    clearState: true
- tapOn: Username
- inputText: ${USERNAME}
- tapOn: Login
- assertVisible: Welcome
```

## Core Commands

- `launchApp`: launch the app under test; supports `clearState`, `clearKeychain`,
  permissions, and launch arguments.
- `tapOn`: tap by text, id, or coordinate; supports repeats and delays.
- `inputText`: type text into focused fields; Maestro also provides random input
  commands like `inputRandomEmail` and `inputRandomText`.
- `assertVisible`: wait up to the default assertion timeout for an element to
  appear.
- `assertNotVisible`: wait for an element to disappear.
- `extendedWaitUntil`: use when the default assertion wait is too short.
- `scroll`: perform a basic vertical scroll.
- `scrollUntilVisible`: scroll until a target element becomes visible.
- `back`: Android and Web only.
- `openLink`: open a URL or deep link.

## Selectors

- A plain string is shorthand for `text`.
- Use selector objects when you need precision, for example by `id`, `index`,
  `point`, `enabled`, `checked`, `focused`, or `selected`.
- `text` and `id` support regular expressions.
- `css` is web only.
- Prefer stable ids when the app exposes them.

Example:

```yaml
- tapOn:
    id: login_button
- assertVisible:
    text: "Welcome"
    enabled: true
```

## Flow Control

- `runFlow` reuses another Flow file or an inline command list.
- `when` gates commands by `visible`, `notVisible`, `platform`, or `true`.
- `repeat` handles fixed or conditional loops.
- `runScript` executes an external JavaScript file and captures output.
- `evalScript` evaluates a single-line JavaScript expression inline.

Use `runFlow` for reusable journeys such as login, onboarding, or permission
handling. Use `when` sparingly; separate flows are usually easier to maintain
when the paths diverge significantly.

## Wait Strategy

- Rely on `assertVisible` and `assertNotVisible` for normal UI settling.
- Use `extendedWaitUntil` only when the UI is expected to take longer than the
  default wait window.
- Avoid padding tests with arbitrary sleeps unless the docs for a command call
  for it.

## CLI

- `maestro test flow.yaml` runs a Flow locally.
- `maestro test -c` watches flows and reruns them on save.
- `maestro start-device` starts a simulator or emulator.
- `maestro hierarchy` prints the current view hierarchy.
- `maestro record` captures a recording of the run.

## Platform Notes

- Maestro supports Android, iOS, React Native, Flutter, and web.
- `clearState` is not available for web.
- `inputText` does not support Unicode characters on Android.
- `openLink` may require platform-specific handling for deep links and browser
  behavior.

## Docs To Check First

- Flow structure: https://docs.maestro.dev/maestro-flows
- Selectors: https://docs.maestro.dev/api-reference/selectors
- Commands index: https://docs.maestro.dev/api-reference/commands
- CLI overview: https://docs.maestro.dev/maestro-cli
