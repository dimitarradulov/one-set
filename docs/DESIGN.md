# OneSet Design System

**Product:** OneSet  
**Platform:** React Native + Expo  
**Styling:** Tailwind CSS through NativeWind  
**Design direction:** Serious, focused, premium HIT training app

---

## 1. Design Principles

OneSet should feel like a serious HIT coach and logbook in your pocket.

The visual system should support the product promise:

> Build muscle with fewer, harder, smarter workouts.

### Core design qualities

- **Focused:** no visual clutter, no social-feed feeling, no unnecessary dashboard noise.
- **Serious:** more like a training command center than a wellness habit app.
- **Premium:** polished dark surfaces, restrained accent color, strong typography.
- **Fast to use:** during workouts, the UI should help users log quickly and move on.
- **Calm but intense:** the app should feel powerful without becoming aggressive or stressful.

### Avoid

- Bright orange/red-heavy “calorie burn” fitness branding
- Excessive gradients
- Gamified badges/streak visuals
- Overloaded dashboards
- Random motivational cards
- Too many competing accent colors
- Social fitness aesthetics

---

## 2. Brand Color Direction

The recommended direction is:

> **Dark Performance + Electric Purple**

This gives OneSet a serious, modern, premium feeling while keeping the interface focused and easy to use during training.

Purple should be the brand accent. Dark navy/black should be the main app environment.

---

## 3. Color Palette

## 3.1 Dark Theme — Only Experience

Dark mode is the only supported OneSet theme. Do not design or implement light theme variants.

| Token             |       Hex | Usage                                           |
| ----------------- | --------: | ----------------------------------------------- |
| `background`      | `#090A12` | Main app background                             |
| `surface`         | `#121421` | Cards, panels, bottom tabs                      |
| `surfaceElevated` | `#1A1D2E` | Modals, active workout cards, highlighted areas |
| `surfaceMuted`    | `#202337` | Inputs, secondary cards, disabled surfaces      |
| `border`          | `#2A2D3D` | Card borders, dividers, input borders           |
| `borderStrong`    | `#3A3D52` | Active input borders, emphasized dividers       |
| `textPrimary`     | `#F8FAFC` | Main text                                       |
| `textSecondary`   | `#A1A1AA` | Supporting text                                 |
| `textMuted`       | `#71717A` | Metadata, labels, timestamps                    |
| `primary`         | `#7C3AED` | Main CTA, selected states, progress accents     |
| `primaryPressed`  | `#6D28D9` | Pressed CTA state                               |
| `primarySoft`     | `#2E1B5F` | Soft purple backgrounds, selected cards         |
| `primaryLight`    | `#A78BFA` | Small highlights, icons, secondary accents      |
| `success`         | `#22C55E` | Improved, completed, ready                      |
| `successSoft`     | `#12351F` | Success chip background                         |
| `warning`         | `#F59E0B` | Recovery warnings, possible stall               |
| `warningSoft`     | `#3A2606` | Warning chip background                         |
| `danger`          | `#EF4444` | Pain, form issue, reduce weight                 |
| `dangerSoft`      | `#3B1212` | Danger chip background                          |
| `info`            | `#38BDF8` | Informational notes, optional education         |
| `white`           | `#FFFFFF` | Icons/text on strong colored backgrounds        |

### Dark theme usage

- Main app screens should use `background`.
- Cards should use `surface`.
- Important active workout sections can use `surfaceElevated`.
- Inputs should use `surfaceMuted` with `border`.
- Primary buttons should use `primary`.
- Avoid large full-screen purple backgrounds. Purple is strongest when used selectively.
- Avoid adding light-mode tokens, light-only components, or alternate light-screen variants.

## 5. Typography

OneSet should use a clean, modern sans-serif font with strong readability.

- Bebas Neue - Used for headlines
- Inter - Used for body text

---

## 6. Type Scale

Use a compact but readable mobile type scale.

| Token     | Size | Line height | Weight | Usage                      |
| --------- | ---: | ----------: | -----: | -------------------------- |
| `display` |   32 |          38 |    700 | Onboarding hero headlines  |
| `h1`      |   28 |          34 |    700 | Main screen title          |
| `h2`      |   24 |          30 |    700 | Section hero title         |
| `h3`      |   20 |          26 |    700 | Card titles, workout names |
| `bodyLg`  |   18 |          28 |    500 | Important body copy        |
| `body`    |   16 |          24 |    400 | Default text               |
| `bodySm`  |   14 |          20 |    400 | Secondary text             |
| `caption` |   12 |          16 |    500 | Labels, metadata, chips    |
| `micro`   |   11 |          14 |    500 | Tiny metadata only         |

### Typography rules

- Use bold typography sparingly for hierarchy.
- Avoid long paragraphs inside workout screens.
- Use short, direct copy during active workouts.
- Important numbers should be large and easy to scan.

---

## 7. Spacing System

Use an 8-point spacing system.

| Token  | Value | Tailwind class   |
| ------ | ----: | ---------------- |
| `xs`   |     4 | `p-1`, `gap-1`   |
| `sm`   |     8 | `p-2`, `gap-2`   |
| `md`   |    12 | `p-3`, `gap-3`   |
| `base` |    16 | `p-4`, `gap-4`   |
| `lg`   |    20 | `p-5`, `gap-5`   |
| `xl`   |    24 | `p-6`, `gap-6`   |
| `2xl`  |    32 | `p-8`, `gap-8`   |
| `3xl`  |    40 | `p-10`, `gap-10` |

### Screen padding

| Screen type                   |  Horizontal padding |
| ----------------------------- | ------------------: |
| Standard app screens          |       `px-5` / 20px |
| Dense workout logging screens |       `px-4` / 16px |
| Onboarding screens            |       `px-6` / 24px |
| Full-width media screens      | `px-0` where needed |

### Vertical rhythm

- Use `gap-4` between normal stacked sections.
- Use `gap-6` between major screen sections.
- Use `gap-2` inside compact cards.
- Use `mt-8` before primary CTA areas when the page is not scroll-heavy.

---

## 8. Border Radius

OneSet should feel modern and soft, but not childish.

| Token  | Value | Tailwind class | Usage                        |
| ------ | ----: | -------------- | ---------------------------- |
| `sm`   |     8 | `rounded-lg`   | Small chips, tags            |
| `md`   |    12 | `rounded-xl`   | Inputs, small cards          |
| `lg`   |    16 | `rounded-2xl`  | Main cards, buttons          |
| `xl`   |    24 | `rounded-3xl`  | Hero cards, modals           |
| `full` |   999 | `rounded-full` | Pills, avatars, icon buttons |

### Default choices

- Cards: `rounded-2xl`
- Buttons: `rounded-2xl`
- Inputs: `rounded-xl`
- Chips: `rounded-full`
- Bottom sheets/modals: `rounded-t-3xl`

---

## 9. Elevation and Shadows

Use shadows carefully. In dark mode, rely more on contrast and borders than heavy shadows.

### Dark mode

- Cards: subtle border, no heavy shadow
- Modals: stronger background contrast
- Active elements: border + purple accent

Example:

```tsx
<View className="border-dark-border bg-dark-surface rounded-2xl border p-4" />
```

## 10. Buttons

## 10.1 Primary Button

Used for the main action on a screen.

Examples:

- Start Assessment
- Start Workout
- Begin Workout
- Continue
- Start 14-day free trial

Style:

```tsx
className = 'h-14 items-center justify-center rounded-2xl bg-brand-primary px-5';
```

Text:

```tsx
className = 'text-base font-semibold text-white';
```

### Primary button rules

- One primary CTA per screen whenever possible.
- Full-width on onboarding and paywall screens.
- Can be card-width on dense workout screens.
- Do not use gradients for primary buttons.

---

## 10.2 Secondary Button

Used for lower-priority actions.

Examples:

- View Program
- Update Assessment
- Review Program Options

Style:

```tsx
className =
  'h-14 items-center justify-center rounded-2xl border border-dark-border bg-dark-surface px-5';
```

Text:

```tsx
className = 'text-base font-semibold text-white';
```

---

## 10.3 Ghost Button

Used for quiet actions.

Examples:

- Skip Rest
- Maybe Later
- Dismiss
- Cancel

Style:

```tsx
className = 'h-12 items-center justify-center rounded-xl px-4';
```

Text:

```tsx
className = 'text-sm font-semibold text-zinc-400';
```

---

## 10.4 Destructive Button

Used rarely.

Examples:

- Delete Account
- Stop Workout
- Abandon Workout

Style:

```tsx
className = 'h-14 items-center justify-center rounded-2xl bg-status-danger px-5';
```

---

## 11. Cards

Cards are the foundation of the UI.

### Default card

```tsx
className = 'rounded-2xl border border-dark-border bg-dark-surface p-4';
```

### Elevated card

```tsx
className = 'rounded-3xl border border-dark-borderStrong bg-dark-elevated p-5';
```

### Selected card

```tsx
className = 'rounded-2xl border border-brand-primary bg-brand-primarySoft p-4';
```

### Card spacing

- Small card: `p-3`
- Standard card: `p-4`
- Important card: `p-5`
- Hero card: `p-6`

---

## 12. Inputs

Inputs should be large enough for quick mobile use, especially during workouts.

### Standard input

```tsx
className = 'h-14 rounded-xl border border-dark-border bg-dark-muted px-4 text-base text-white';
```

### Active input

```tsx
className = 'h-14 rounded-xl border border-brand-primary bg-dark-muted px-4 text-base text-white';
```

### Workout logging input

For kg, reps, and effort fields:

```tsx
className =
  'h-14 flex-1 rounded-xl border border-dark-border bg-dark-muted px-3 text-center text-lg font-semibold text-white';
```

### Input rules

- Minimum height: 52–56px.
- Use large tap targets.
- During workouts, numeric inputs should be centered and prominent.
- Avoid unnecessary helper text during logging.

---

## 13. Chips and Tags

Use chips for compact metadata.

Examples:

- 2 days/week
- ~30 min
- Beginner HIT
- Effort 8–9
- Ready
- Improved

### Default chip

```tsx
className = 'rounded-full border border-dark-border bg-dark-muted px-3 py-1';
```

Text:

```tsx
className = 'text-xs font-medium text-zinc-300';
```

### Status chips

| Status            | Background     | Text/accent     |
| ----------------- | -------------- | --------------- |
| Improved          | `successSoft`  | `success`       |
| Ready to Increase | `primarySoft`  | `primaryLight`  |
| Matched           | `surfaceMuted` | `textSecondary` |
| Dropped           | `dangerSoft`   | `danger`        |
| Possible Stall    | `warningSoft`  | `warning`       |

---

## 14. Iconography

Use simple outline icons.

### Icon rules

- Default icon size: 20–24px.
- Tab icons: 22–24px.
- Small metadata icons: 14–16px.
- Use purple only for selected/active states.
- Avoid overly playful icons.

---

## 16. Screen-Level Design Guidance

## 16.1 Onboarding Screens

Onboarding should feel like a serious coach assessment.

### Visual direction

- Use the dark theme.
- Use generous spacing.
- One question per screen.
- Large headline, short explanation, clear options.

### Option card

```tsx
className = 'rounded-2xl border border-dark-border bg-dark-surface p-4';
```

Selected option:

```tsx
className = 'rounded-2xl border border-brand-primary bg-brand-primary-soft p-4';
```

### Onboarding layout

```txt
Top: progress indicator
Middle: question + explanation
Main: options
Bottom: primary CTA / next action
```

### Progress indicator

Use a subtle progress bar, not a gamified stepper.

```tsx
className = 'h-1 rounded-full bg-dark-surface-muted';
```

Filled:

```tsx
className = 'h-1 rounded-full bg-brand-primary';
```

---

## 16.2 Home Screen

Home answers:

> What should I do next?

### Structure

1. Header / current program context
2. Main next workout card
3. Recovery/readiness note
4. Last workout summary
5. Cycle progress

### Recommended style

- Dark background
- One dominant next-workout card
- Purple CTA
- Compact secondary cards

### Next workout card

Use elevated surface:

```tsx
className = 'rounded-3xl border border-dark-borderStrong bg-dark-elevated p-5';
```

CTA:

```tsx
className = 'mt-5 h-14 rounded-2xl bg-brand-primary';
```

---

## 16.3 Program Screen

Program answers:

> What plan am I following, why was it chosen, and what’s coming next?

### Structure

1. Program overview
2. Cycle progress
3. Why this program fits you
4. Workout list
5. Program rules
6. Review/change option

### Style notes

- Use calm, structured cards.
- Avoid making program switching too visually prominent.
- Exercise rows can show small video icons.
- Keep the page informational, not promotional.

---

## 16.4 Active Workout Screen

This is the most important functional screen.

It should feel focused, minimal, and fast.

### Structure

1. Workout name and exercise count
2. Current exercise name
3. Target rep range and effort
4. Previous result
5. Warm-up guidance
6. Inline working set logging
7. Form video shortcut
8. Skip option

### Logging row

```txt
[140 kg] [reps] [Effort 9] [✓]
```

### Design rules

- Keep one exercise as the primary focus.
- Make kg/reps fields large.
- Use purple for the save/check action.
- Do not use a separate log-set modal.
- Keep warm-ups visually secondary.
- Avoid charts or analytics during the workout.

---

## 16.5 Rest Timer Screen

Rest timer should feel calm and functional.

### Structure

1. Large timer
2. Next exercise
3. Previous logged set
4. Skip Rest
5. Add 30 seconds

### Timer visual

- Large number: 48–64px
- Purple circular/progress accent optional
- Keep background dark and distraction-free

---

## 16.6 Logbook Screen

Logbook answers:

> Am I progressing?

### MVP style

Use tables/lists first. Charts can come later.

### Structure

1. Recent progress summary
2. Recent workouts
3. Exercises view
4. Session details
5. Exercise history

### Status colors

- Improved: green
- Matched: gray
- Dropped: red
- Ready to Increase: purple
- Possible Stall: amber

### Rule

The logbook should feel like a serious training record, not a fitness dashboard full of decorative charts.

---

## 16.7 Profile Screen

Profile should be quiet and settings-focused.

### Structure

1. Account info
2. Subscription/trial status
3. Training profile
4. Current program shortcut
5. Preferences
6. Workout settings
7. Limitations
8. Support/legal
9. Sign out/delete account

### Style notes

- No social identity features.
- No public stats.
- No transformation gallery.
- Keep it calm and utilitarian.

---

## 17. Component Recipes

## 17.1 Primary CTA

```tsx
<Pressable className="bg-brand-primary active:bg-brand-primaryPressed h-14 items-center justify-center rounded-2xl px-5">
  <Text className="text-base font-semibold text-white">Start Workout</Text>
</Pressable>
```

## 17.2 Dark Card

```tsx
<View className="border-dark-border bg-dark-surface rounded-2xl border p-4">
  <Text className="text-lg font-bold text-white">Workout A</Text>
  <Text className="mt-1 text-sm text-zinc-400">5 exercises • ~30 min</Text>
</View>
```

## 17.3 Selected Option Card

```tsx
<Pressable className="border-brand-primary bg-brand-primarySoft rounded-2xl border p-4">
  <Text className="text-base font-semibold text-white">Build muscle</Text>
  <Text className="mt-1 text-sm text-zinc-400">Gain size with efficient HIT training.</Text>
</Pressable>
```

## 17.4 Status Chip

```tsx
<View className="bg-status-successSoft rounded-full px-3 py-1">
  <Text className="text-status-success text-xs font-semibold">Improved</Text>
</View>
```

## 17.5 Workout Logging Row

```tsx
<View className="flex-row items-center gap-2">
  <TextInput className="border-dark-border bg-dark-muted h-14 flex-1 rounded-xl border px-3 text-center text-lg font-semibold text-white" />
  <TextInput className="border-dark-border bg-dark-muted h-14 flex-1 rounded-xl border px-3 text-center text-lg font-semibold text-white" />
  <Pressable className="bg-brand-primary h-14 w-14 items-center justify-center rounded-xl">
    <Text className="text-lg font-bold text-white">✓</Text>
  </Pressable>
</View>
```

---

## 18. Motion and Interaction

Use subtle motion only.

### Recommended animation behavior

- Button press: slight opacity/scale feedback
- Screen transitions: native navigation defaults
- Option selection: quick color/border transition
- Timer: smooth progress movement
- Modal/bottom sheet: standard slide-up

### Avoid

- Bouncy gamified animations
- Confetti for workout completion
- Excessive loading animations
- Distracting workout-screen motion

---

## 19. Imagery and Video

Exercise videos should be functional, not decorative.

### Video rules

- Short loopable demos: 5–12 seconds
- Muted by default
- Inside exercise detail screen
- Available through a small play icon during workouts
- Do not clutter Home or Program pages

### Image style

If using photos in onboarding or marketing screens:

- Real gym setting
- Serious training feel
- Controlled movement
- No exaggerated influencer look
- Avoid overly glossy stock fitness imagery

---

## 20. Accessibility

### Tap targets

Minimum recommended tap target:

> 44 × 44px

Preferred for key workout actions:

> 52–56px height

### Contrast

- Ensure text meets readable contrast on dark surfaces.
- Avoid muted gray text for important instructions.
- Purple text on dark backgrounds should be used carefully; prefer purple backgrounds with white text for CTAs.

### Text sizing

- Do not use text smaller than 12px except for rare metadata.
- Workout logging values should be large and easy to read.

### Color reliance

Do not communicate status by color alone. Pair status colors with text labels:

- Improved
- Dropped
- Ready to Increase
- Possible Stall

---

## 21. Theme Policy by App Area

| Area                | Recommended theme                      |
| ------------------- | -------------------------------------- |
| Splash / welcome    | Dark                                   |
| Onboarding          | Dark                                   |
| Recommended program | Dark                                   |
| Main app            | Dark                                   |
| Workout session     | Dark                                   |
| Rest timer          | Dark                                   |
| Logbook             | Dark                                   |
| Profile/settings    | Dark                                   |
| Paywall             | Dark                                   |

---

## 22. Copy Tone in UI

The visual design should be supported by direct, coach-like copy.

### Tone

- Clear
- Calm
- Serious
- Helpful
- Not hype-heavy
- Not shame-based

### Good examples

- `Goal: Beat your logbook`
- `You’re likely ready for your next HIT session.`
- `Warm-up sets prepare you. The working set is the one that counts.`
- `Repeat this weight and aim for more clean reps next time.`

### Avoid

- `Destroy your limits!`
- `No excuses!`
- `Crush calories!`
- `You failed!`
- `Never miss a day!`

---

## 23. Practical MVP Design Defaults

Use these defaults when designing/building screens:

| Element                  | Default                 |
| ------------------------ | ----------------------- |
| Screen padding           | `px-5`                  |
| Card radius              | `rounded-2xl`           |
| Card padding             | `p-4`                   |
| Primary button height    | `h-14`                  |
| Input height             | `h-14`                  |
| Main background          | `dark.background`       |
| Main card background     | `dark.surface`          |
| Elevated card background | `dark.elevated`         |
| Primary CTA              | `brand.primary`         |
| Bottom tabs              | 4 tabs max              |
| Workout input text       | `text-lg font-semibold` |
| Section spacing          | `gap-4` or `gap-6`      |
| Hero card radius         | `rounded-3xl`           |

---

## 24. Final Design Summary

OneSet should look and feel like:

> A premium dark-mode HIT training command center with a clean logbook, direct workout flow, and electric purple brand accent.

The app should not look like a generic fitness marketplace, social workout app, wellness tracker, or calorie-burn dashboard.

The strongest visual direction is:

```txt
Deep dark background
+ structured elevated cards
+ electric purple CTAs
+ clear status colors
+ large workout logging controls
+ minimal distractions
```

The design should help users do one thing well:

> Train hard, log the working set, recover, and beat the logbook next time.
