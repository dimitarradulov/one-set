# OneSet Design System

## 1. Design direction

OneSet is a focused iOS workout app for lifters following guided HIT programs. The interface should feel **strong, quiet, fast, and trustworthy**: high contrast, minimal decoration, compact information density, and obvious interaction states.

The visual system should support the core workout loop without competing with it: see previous performance, enter weight and reps, complete the set, rest, and continue. Reliability and clarity take priority over novelty.

### Principles

1. **Training first** — the active workout is the highest-priority experience. Reduce taps, navigation, and visual noise.
2. **One clear action** — each screen should have an obvious primary next action.
3. **Dense, not cramped** — show useful performance context close to inputs while preserving comfortable touch targets.
4. **State must be unmistakable** — draft, completed, pending sync, unavailable, destructive, and selected states must not rely on color alone.
5. **Progressive disclosure** — keep routine logging compact; reveal instructions, warmups, notes, video, and replacement controls on demand.
6. **Trust through consistency** — inputs, completion controls, timers, status language, and destructive actions behave consistently everywhere.
7. **Dark by design** — the launch theme is intentionally dark, not a light interface inverted after the fact.

---

## 2. Brand foundations

### Core palette

| Token | Hex | Use |
| --- | --- | --- |
| `color.background` | `#1A1A1A` | App background and primary canvas |
| `color.text.primary` | `#E5E5E5` | Primary text, key values, active icons |
| `color.accent` | `#D97706` | Primary actions, active/selected emphasis, progress accents |

The accent is intentionally warm against the neutral charcoal UI. Use it selectively so an orange element reliably signals emphasis or action rather than becoming general decoration.

### Extended neutral tokens

The three brand colors are the source palette; derived neutrals create hierarchy without introducing competing hues.

| Token | Value | Recommended use |
| --- | --- | --- |
| `color.surface.1` | `#222222` | Cards, grouped content, input containers |
| `color.surface.2` | `#2A2A2A` | Elevated/expanded rows, pressed neutral surfaces |
| `color.border` | `#3A3A3A` | Dividers, input outlines, card boundaries |
| `color.text.secondary` | `#A3A3A3` | Metadata, labels, supporting copy |
| `color.text.tertiary` | `#737373` | Disabled/low-priority metadata only |
| `color.accent.pressed` | `#B86105` | Pressed primary action |
| `color.accent.subtle` | `rgba(217,119,6,0.14)` | Selected backgrounds and restrained emphasis |
| `color.overlay` | `rgba(0,0,0,0.64)` | Modal/sheet backdrop where needed |

### Semantic feedback

Prefer icon + copy + shape/state changes over introducing many status colors. When platform-standard semantic colors are needed for errors or destructive actions, use iOS semantic system colors so accessibility behavior remains predictable.

- **Success/completed:** check icon + primary text; accent may reinforce completion.
- **Pending/syncing:** sync/clock icon + “Pending” or “Syncing”; never communicate this only with orange.
- **Error:** platform semantic red + error icon + actionable copy.
- **Disabled:** reduced emphasis, but retain readable contrast and never encode unavailable state through opacity alone.
- **Destructive:** platform semantic red reserved for delete/discard confirmations, not ordinary navigation.

### Color usage rules

- Keep most screens approximately neutral; accent should occupy a small visual share.
- Do not use accent for long body text.
- Do not use `#737373` for essential instructions or small text on `#1A1A1A` without contrast validation.
- Do not place orange text on low-contrast orange-tinted surfaces without testing the final pair.
- Selected state should combine accent with another cue: border, icon, checkmark, weight, or label.

---

## 3. Typography

### Font families

- **Headings / display:** Bebas Neue
- **Body / UI / data:** Montserrat
- **Fallback:** use the closest system sans-serif fallback while custom fonts are unavailable; never block rendering on font loading.

Bebas Neue gives OneSet a condensed athletic display voice. Montserrat provides a geometric sans-serif voice for body copy, controls, and workout data.

### Critical typography rule

**Bebas Neue is display-only.** Do not use it for form labels, instructions, buttons, navigation labels, alerts, or dense workout data. Its condensed all-caps character is strongest in short headings and becomes harder to scan in functional UI.

### Type scale

| Style | Font | Size | Weight | Line height | Use |
| --- | --- | ---: | --- | ---: | --- |
| `display` | Bebas Neue | 40 | Regular | 44 | Welcome / major branded moments |
| `h1` | Bebas Neue | 32 | Regular | 36 | Screen titles |
| `h2` | Bebas Neue | 24 | Regular | 28 | Major section titles |
| `body` | Montserrat | 16 | Regular | 24 | Default readable copy |
| `bodyStrong` | Montserrat | 16 | Medium | 24 | Important values and row titles |
| `label` | Montserrat | 14 | Medium | 20 | Form/component labels |
| `caption` | Montserrat | 12 | Regular | 16 | Metadata and secondary status |
| `metric` | Montserrat | 20 | Medium | Weight, reps, timer, important workout values |
| `button` | Montserrat | 16 | Medium | 20 | Buttons |

### Typography rules

- Prefer sentence case for functional copy.
- Bebas Neue may render headings in uppercase where visually appropriate; do not force body/UI copy to uppercase.
- Use tabular numerals for weights, reps, timers, and historical values if supported by the chosen Montserrat build; verify numeric alignment and timer stability on-device.
- Avoid letter-spacing tricks in body text. For Bebas Neue, keep tracking restrained and test on-device.
- Support Dynamic Type. Do not lock workout rows to a fixed height that clips enlarged text.
- At accessibility sizes, allow metadata and controls to stack vertically rather than shrinking type.

---

## 4. Layout and spacing

Use a **4 pt base grid** with an **8 pt primary rhythm**.

### Spacing tokens

| Token | Value | Use |
| --- | ---: | --- |
| `space.1` | 4 | Tight icon/text relationships |
| `space.2` | 8 | Inline gaps, compact row spacing |
| `space.3` | 12 | Internal component spacing |
| `space.4` | 16 | Standard card padding / screen gutter minimum |
| `space.5` | 20 | Comfortable card padding |
| `space.6` | 24 | Section spacing |
| `space.8` | 32 | Major section separation |
| `space.10` | 40 | Large layout break |
| `space.12` | 48 | Hero/top spacing where appropriate |

### Screen layout

- Standard horizontal screen padding: **16 pt** on compact widths; **20–24 pt** where space permits.
- Keep primary content aligned to one dominant vertical grid.
- Prefer full-width workout rows/cards rather than multiple narrow columns on iPhone.
- Respect safe areas. Sticky workout actions may sit above the bottom safe area with a solid background and divider.
- Avoid decorative whitespace that pushes active workout inputs below the fold.

### Corner radius

| Token | Value | Use |
| --- | ---: | --- |
| `radius.sm` | 8 | Inputs, small chips |
| `radius.md` | 12 | Buttons, compact cards |
| `radius.lg` | 16 | Main cards, sheets |
| `radius.pill` | 999 | Status chips only |

Do not round every container. Use radius to define interactive/grouped surfaces, not as decoration.

---

## 5. Iconography

Use **SF Symbols** as the default iOS icon system.

- Default icon size: 18–20 pt; 24 pt for primary standalone controls.
- Pair ambiguous icons with labels.
- Keep stroke/weight visually compatible with Montserrat Medium.
- Use filled variants primarily for selected/active states.
- Do not create custom icons for standard actions such as back, close, play, settings, history, check, search, or delete unless the system symbol fails the use case.

---

## 6. Core components

### Primary button

Use for the single dominant action: Start workout, Finish, Continue, Select program.

- Height: minimum **52 pt**.
- Background: `color.accent`.
- Label: dark text only if the final contrast passes WCAG; otherwise use the accessible foreground pair established in implementation testing.
- Radius: `radius.md`.
- Pressed: `color.accent.pressed` plus native pressed feedback.
- Loading: retain button width and label context; add progress indicator without causing layout shift.
- Disabled: visible label + reduced emphasis; never make disabled text illegible.

### Secondary button

For non-primary actions such as Preview, Replace, Add note, Manage subscription.

- Surface or transparent background.
- `color.text.primary` label.
- 1 pt `color.border` outline when boundary is useful.
- Minimum 44 pt touch height; prefer 48–52 pt for standalone actions.

### Text button

Use for low-emphasis actions such as Skip, Not now, Restore purchases.

- Montserrat 14–16 Medium.
- Minimum 44 × 44 pt hit target even when visual text is smaller.
- Do not use orange for every text link; reserve accent for priority/selection.

### Inputs

Workout numeric entry is a primary interaction and should feel immediate.

- Minimum height: **52 pt**.
- Surface: `color.surface.1`.
- Border: `color.border`; focused state uses accent border plus another focus cue where appropriate.
- Numeric value: `metric` style.
- Unit appears persistently adjacent to or inside the field; never rely on placeholder text for units.
- Weight and reps should remain visually distinct and consistently ordered.
- Empty fields must not look completed.
- Validation occurs without clearing entered values.

### Cards

Use cards only when they establish a meaningful group: program, workout/day, exercise, history session.

- Background: `color.surface.1`.
- Radius: `radius.lg` for program/workout cards; `radius.md` for compact workout rows.
- Padding: 16 pt typical.
- Border: optional 1 pt `color.border`; do not combine strong shadow + border + tinted background.
- Dark theme elevation should rely mainly on surface contrast and borders, not heavy shadows.

### Chips / status pills

Use sparingly for short states such as `IN PROGRESS`, `PENDING`, or rep ranges.

- Montserrat 12 Medium.
- Height: 28–32 pt.
- Do not place long sentences in chips.
- Completion must include icon/text, not color alone.

### Dividers

- 1 physical pixel where possible.
- `color.border` or a lower-opacity equivalent.
- Prefer spacing over dividers when grouping is already clear.

---

## 7. Navigation

Launch navigation is deliberately minimal:

- **Program**
- **History**
- **Settings** accessed from the Program area rather than promoted to a third primary tab unless testing shows discoverability problems.

Use native iOS navigation behavior and predictable back gestures. Avoid custom gesture-only navigation.

### Tab/navigation treatment

- Inactive: secondary text/icon.
- Active: primary text plus accent/filled icon treatment.
- Do not hide the current location solely through a thin orange line.
- During an active workout, prioritize workout context and completion controls over global navigation; prevent accidental program switching when the product state does not permit it.

---

## 8. Screen patterns

### Program overview

Hierarchy:

1. Program name (`h1`)
2. Compact program context/frequency
3. Week selector
4. Day/workout cards
5. Settings entry as secondary utility

Workout card content should prioritize: day/workout name → completion state → completed/total exercises → disclosure to preview. Avoid oversized hero art; this screen is an operational dashboard.

### Week selector

- Horizontally scrollable when needed.
- Minimum 44 pt target.
- Selected week uses accent + text/shape cue.
- Keep Week 9+ labels stable rather than compressing into ambiguous numbers.

### Workout preview

Show exercise order and rep targets first. Video availability, guidance, and warmups are supporting information. **Preview must look distinct from an active workout** so users do not mistake browsing for recording.

Primary action: `Start workout`.

### Active workout

This is the design system's most important pattern.

Each compact exercise row should contain:

- exercise name;
- rep target;
- previous performance/context;
- weight input;
- reps input;
- explicit completion control;
- expand/disclosure control for guidance, warmups, video, note, and replacement.

Recommended hierarchy inside a row:

`Exercise name` → `target / previous` → `today's inputs` → `complete`.

Do not make video thumbnails or long coaching text dominate the collapsed state. The user must be able to log an entire workout efficiently without expanding any exercise.

#### Exercise states

- **Ready:** empty/current draft inputs, neutral surface.
- **Draft:** entered values remain visibly editable; no completion check.
- **Completed:** check icon + completed values; use accent as reinforcement, not the only signal.
- **Expanded:** surface elevation/contrast changes; content opens inline or in a sheet depending on density.
- **Skipped at finish:** explicit skipped label in final/history representation, not visually confused with incomplete draft.

#### Completion control

Prefer a labeled or unmistakable check control with at least a 44 pt target. A tiny checkbox beside dense numeric inputs is too error-prone for gym use.

### Rest timer

Rest is secondary to logging and must not lock the screen.

- Compact persistent bar/card after a completed set.
- Timer uses `metric` style.
- Show `Skip` and adjustment access without making them more prominent than the countdown.
- Timer state survives navigation/relaunch; visual design should communicate continuity rather than modal interruption.
- When rest completes, use notification/haptic behavior when permitted and update the bar to a clear ready state.

### Finish workout

Present:

- completed/total exercises;
- duration;
- optional collapsed Add note;
- clear Finish confirmation.

If work is incomplete, communicate the count before confirmation. Do not use guilt-oriented language for partial completion.

### History

Start with a chronological session list. Each row should expose date, workout/program context, and completion summary without requiring charts. Session detail prioritizes actual exercises and recorded weight/reps.

Edits must look like deliberate history correction, not like starting a new workout. Destructive deletion belongs behind a clear confirmation and should never visually resemble ordinary row actions.

### Exercise replacement

Flow: exercise menu → Replace → search → select → scope.

Scope choice should be explicit:

- **This workout only**
- **Remember for this program**

Do not preselect the broader persistent option in a way that can silently change future workouts.

---

## 9. Onboarding pattern

Use focused sequential screens with a visible but quiet progress indicator.

Visual hierarchy per step:

1. short Bebas Neue heading;
2. concise Montserrat explanation;
3. primary selection/content;
4. persistent Continue action when appropriate;
5. secondary back/dismiss action.

Keep each step centered on one decision. Avoid feature-tour carousels and permission prompts unrelated to the current task. Notification permission should be contextual to enabling rest alerts, not part of generic onboarding.

---

## 10. Interaction and motion

Motion should communicate state, not personality for its own sake.

### Timing

- Micro feedback: **100–150 ms**.
- Standard state transition: **180–240 ms**.
- Sheet/navigation motion: use native iOS behavior.
- Avoid long spring animations during workout logging.

### Recommended motion

- Set completion: immediate check/state change; timer appears without blocking input.
- Expand exercise: short height/content transition while preserving scroll position.
- Week selection: subtle selection transition; do not animate the entire program screen.
- Sync: small non-blocking status change; never use a full-screen success animation for routine sync.

Respect Reduce Motion. No critical state may depend on animation being perceived.

### Haptics

Use native haptics sparingly:

- successful working-set completion;
- destructive confirmation where appropriate;
- timer completion when app state permits.

Do not haptic on every field tap or navigation action.

---

## 11. Accessibility

Target **WCAG 2.2 AA** principles while following current iOS accessibility conventions.

### Required behavior

- Minimum interactive target: **44 × 44 pt**.
- Support Dynamic Type and content reflow.
- Provide VoiceOver labels, values, hints, and logical reading order.
- Do not communicate completed/pending/error/selected state by color alone.
- Maintain visible units (`kg`, `lb`, `reps`) in text accessible to assistive technology.
- Ensure focused inputs and validation errors are announced meaningfully.
- Videos require usable text instructions so unavailable media never blocks understanding.
- Respect Reduce Motion and increased contrast settings where applicable.
- Test the custom font combination at accessibility sizes; fall back to system text behavior if custom typography harms legibility.

### Contrast caution

The supplied primary text `#E5E5E5` on background `#1A1A1A` provides strong contrast. Derived secondary/tertiary colors and all accent foreground combinations must be verified in implementation rather than assumed accessible.

---

## 12. Content and UX copy

OneSet copy should be **short, literal, and action-oriented**.

Prefer:

- `Start workout`
- `Set saved`
- `Rest 2:30`
- `5 of 7 exercises completed`
- `Finish or discard your current workout first.`
- `Saved on this device · Sync pending`

Avoid:

- motivational filler during logging;
- ambiguous labels such as `Done` when the object/action is unclear;
- technical sync terminology users do not need;
- implying cloud backup when a workout exists only on the device;
- aggressive language around failure, missed workouts, or partial sessions.

---

## 13. System states

Every data-bearing screen should define these states before implementation:

| State | Design expectation |
| --- | --- |
| Loading | Preserve layout where possible; avoid blocking active workout data already stored locally |
| Empty | Explain what will appear and give the relevant next action |
| Offline | Keep locally available functionality usable; label unavailable network-only actions |
| Pending sync | Non-blocking status with retry path when needed |
| Sync failure | Retain user data; explain retry/action without implying loss |
| Auth expired during workout | Do not interrupt active logging; defer account action |
| Missing video | Keep text instructions and logging available |
| Validation error | Keep entered value visible; identify the exact correction |
| Destructive confirm | Name what is being removed and whether recovery exists |

---

## 14. Design tokens — starter specification

```text
color.background       = #1A1A1A
color.surface.1        = #222222
color.surface.2        = #2A2A2A
color.border           = #3A3A3A
color.text.primary     = #E5E5E5
color.text.secondary   = #A3A3A3
color.text.tertiary    = #737373
color.accent           = #D97706
color.accent.pressed   = #B86105

font.display           = "Bebas Neue"
font.body              = "Montserrat"

space.1 = 4
space.2 = 8
space.3 = 12
space.4 = 16
space.5 = 20
space.6 = 24
space.8 = 32
space.10 = 40
space.12 = 48

radius.sm   = 8
radius.md   = 12
radius.lg   = 16
radius.pill = 999

target.minimum = 44
button.height  = 52
input.height   = 52
```

These should become semantic SwiftUI tokens rather than repeated literal values throughout views.

---

## 15. SwiftUI implementation guidance

- Centralize color, type, spacing, radius, and component styles in a small design-system module.
- Prefer semantic names (`textPrimary`, `surfaceRaised`, `actionPrimary`) over visual names (`lightGray`, `orange`).
- Wrap Bebas Neue and Montserrat in Dynamic Type-aware text styles.
- Use native controls/behaviors where they improve accessibility, keyboard behavior, focus, navigation, sheets, alerts, and haptics.
- Build reusable components around product semantics: `WorkoutCard`, `ExerciseRow`, `PerformanceInput`, `RestTimerBar`, `SyncStatus`, `WeekSelector`, and `SessionRow`.
- Components must expose states explicitly rather than hiding business state inside visual modifiers.
- Snapshot/test important states at compact widths, largest supported Dynamic Type sizes, offline mode, and long localized strings.

---

## 16. Design QA checklist

Before a screen is considered ready:

- Is the primary action obvious within two seconds?
- Can the core task be completed without relying on color alone?
- Are all tap targets at least 44 pt?
- Does the screen survive large text without clipping or horizontal truncation of essential values?
- Are units always visible and unambiguous?
- Are loading, empty, offline, error, pending, completed, and destructive states designed?
- Does active-workout logging remain usable without opening guidance/video?
- Does any network or authentication state unnecessarily block local workout logging?
- Is accent orange reserved for meaningful emphasis rather than decoration?
- Is Bebas Neue limited to short display headings?
- Does the interface clearly distinguish preview, draft, completed, skipped, and historical states?
- Are destructive actions explicit about permanence?

---

## 17. Design-system boundary

This file defines OneSet's launch visual and interaction language. It does **not** add product scope. Nutrition, social features, charts, custom programs, extra working-set logging, and other deferred features should not create speculative components in the launch design system.

When a new pattern is needed, first determine whether an existing component can represent the state clearly. Add a new component or token only when it solves a repeated product need rather than a one-off visual preference.
