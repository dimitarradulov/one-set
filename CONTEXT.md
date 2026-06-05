# OneSet Context

OneSet is a focused HIT training app where onboarding, program preview, and paid training access are distinct parts of the user journey.

## Language

**Assessment**:
A coach-style onboarding intake that gathers a user's goal, training background, recovery, schedule, equipment, limitations, and intensity comfort before recommending a starter program.
_Avoid_: Quiz, survey

**Main Goal**:
The user's primary training outcome at the time they begin the **Assessment**.
_Avoid_: Fitness goal, objective

**Assessment Draft**:
The locally saved, editable set of a user's **Assessment** answers before those answers are attached to an authenticated user.
_Avoid_: Onboarding state, temporary answers

**Assessment Intake**:
The 11 answer-collection steps of the **Assessment** before result calculation, program recommendation, education, or workout preview.
_Avoid_: Onboarding flow, full onboarding

**Program Library**:
The documented set of HIT programs that OneSet can recommend or assign.
_Avoid_: Program list, workout templates

**Program Recommendation**:
A pure rules-based selection of one **Program Library** entry from a complete **Assessment Draft**.
_Avoid_: AI recommendation, persisted program assignment

**Starting Effort**:
The initial HIT effort target shown with a **Program Recommendation**.
_Avoid_: Intensity level

**Account Creation Prompt**:
The post-**Program Recommendation** account gate that asks a preview user to create an account before progress can be saved or training can begin.
_Avoid_: Auth prompt, login screen, auth wall

**Email Account Creation**:
The email-and-password path inside the **Account Creation Prompt** for creating a OneSet account.
_Avoid_: Email login, password auth

**Email Verification**:
The provider-required confirmation step that proves a user controls the email address used for **Email Account Creation**.
_Avoid_: OTP screen, code screen

**App User**:
The OneSet-owned user record that links an authenticated person to app-specific training data.
_Avoid_: Clerk user, profile, account row

**Preview Mode**:
The restricted state for a user who has completed the **Assessment** and can inspect their **Program Recommendation** without an account, trial, or subscription.
_Avoid_: Guest plan, free tier

**Result Calculation**:
A short post-**Assessment Intake** transition where OneSet visibly analyzes the completed **Assessment Draft** before showing the **Program Recommendation**.
_Avoid_: Manual review step, questionnaire screen

## Relationships

- The welcome screen introduces the **Assessment** but is not counted as an assessment step.
- The **Assessment** contains 11 answer-collection questions.
- The **Assessment Intake** contains exactly those 11 answer-collection questions.
- **Main Goal** is the first question inside the **Assessment**.
- A user selects exactly one **Main Goal**.
- **Main Goal** choices are: Build muscle, Get stronger, Recomp my body, Maintain muscle with less time, and Return after a break.
- Assessment question screens follow one shared interaction pattern: one question, selectable answers, and a separate continue action, including multi-select questions.
- An **Assessment Draft** supports back navigation and answer replacement.
- An **Assessment Draft** stores answers as explicit fields that mirror stable **Assessment** concepts.
- Assessment answers are committed to the **Assessment Draft** only when the user continues from a question.
- Navigating back discards uncommitted answer changes.
- Assessment questions cannot be skipped in the MVP.
- An **Assessment Draft** is synced to the user's account only after authentication.
- Result calculation, recommended program, HIT principles education, and first workout preview happen after the **Assessment Intake**.
- **Result Calculation** is a transient screen, not an answer-collection step.
- **Result Calculation** auto-advances into the **Program Recommendation** without user input.
- **Result Calculation** runs the rules-based recommendation logic against the completed **Assessment Draft** before the **Program Recommendation** screen is shown.
- A **Program Recommendation** requires a complete **Assessment Draft**.
- A **Program Recommendation** preview consumes the prepared recommendation from **Result Calculation** instead of recalculating it.
- A **Program Recommendation** reads candidate programs from the **Program Library**.
- A **Program Recommendation** preview explains the choice with user-facing fit reasons, not internal assessment labels.
- A **Program Recommendation** does not create or persist the user's active program.
- A **Program Recommendation** preview is read-only; it does not support choosing another program from the **Program Library**.
- A **Program Recommendation** preview uses the **Assessment Draft** preferred session length as its estimated workout length.
- A **Program Recommendation** preview expresses intensity as **Starting Effort**.
- The **Program Recommendation** preview continues into the **Account Creation Prompt** before any workout can be started or progress can be saved.
- The **Account Creation Prompt** is addressed in the app route model as `/create-account`.
- The **Account Creation Prompt** supports Apple sign-in and email/password account creation for the MVP.
- Apple sign-in is the primary **Account Creation Prompt** action in the MVP.
- **Email Account Creation** may be implemented before Apple sign-in without removing Apple sign-in from the MVP account creation model.
- The **Account Creation Prompt** does not include Google sign-in in the MVP.
- The first **Account Creation Prompt** implementation is UI-only; live Clerk account creation is a separate implementation story.
- During the UI-only implementation, **Account Creation Prompt** account actions do not advance to the trial paywall.
- The **Account Creation Prompt** is sign-up-first; returning-user sign-in is secondary because the welcome screen already provides the main sign-in entry point.
- During the UI-only implementation, the returning-user sign-in action on the **Account Creation Prompt** does not navigate to another auth flow.
- The **Account Creation Prompt** shows the email/password account creation form by default below the Apple sign-in action, separated by an "OR" divider.
- **Email Account Creation** happens inside the custom OneSet **Account Creation Prompt**, not in a separate generic authentication screen.
- **Email Account Creation** only produces an authenticated account after any provider-required email verification is complete.
- If provider-required, **Email Verification** happens on a dedicated route after the **Account Creation Prompt**.
- **Email Verification** is addressed in the app route model as `/verify-email`.
- Completed **Email Account Creation** creates or links exactly one **App User**.
- An **App User** is identified externally by the authenticated person's stable Clerk user ID.
- Creating an **App User** does not by itself persist the **Assessment Draft** or create the user's training profile.
- Completed **Email Account Creation** advances to the trial gate before training can begin.
- Future user-specific training data belongs to the **App User**, not directly to the external authentication identity.
- A user who dismisses the **Account Creation Prompt** remains in **Preview Mode** and returns to the prior preview surface when possible.
- If the **Account Creation Prompt** has no usable navigation history, dismissal returns to the **Program Recommendation** preview.

## Example dialogue

> **Dev:** "Should the welcome screen show assessment progress?"
> **Domain expert:** "No. Progress starts after the user chooses to begin the **Assessment**."

> **Dev:** "Is **Main Goal** a separate onboarding concept or just generic screen copy?"
> **Domain expert:** "It is the first **Assessment** question and captures the user's current primary training outcome."

> **Dev:** "If the user changes an earlier answer, do we keep both answers?"
> **Domain expert:** "No. The **Assessment Draft** keeps the current answer for each question and recalculates the recommendation later."

> **Dev:** "Is the recommended program screen part of the **Assessment Intake**?"
> **Domain expert:** "No. The **Assessment Intake** stops after the 11 answer-collection questions."

> **Dev:** "Should **Program Recommendation** save the user's selected program?"
> **Domain expert:** "No. It is a pure recommendation; assignment happens later after authentication and access decisions."

## Flagged ambiguities

- "onboarding" can mean the full first-run journey or the **Assessment** specifically; resolved: use **Assessment** for the coach-style intake that begins after the welcome screen.
- "all onboarding screens" can sound like the full first-run journey; resolved: for the current implementation slice it means the 11 **Assessment Intake** question screens only.
- "assessment flow" can mean the 11 question intake or the later calculation/recommendation/education screens; resolved: use **Assessment Intake** only for the 11 answer-collection questions.
- "recommended program" can mean a pure **Program Recommendation** result or a persisted active program; resolved: use **Program Recommendation** for the pure result only.
- "intensity level" can imply a separate intensity scale; resolved: the **Program Recommendation** preview uses **Starting Effort**.
- "continue from the recommended program" can mean either continuing the preview/education sequence or moving to account creation; resolved: the **Program Recommendation** preview continues to the authentication prompt.
