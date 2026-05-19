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

## Relationships

- The welcome screen introduces the **Assessment** but is not counted as an assessment step.
- The **Assessment** contains 11 answer-collection questions.
- **Main Goal** is the first question inside the **Assessment**.
- A user selects exactly one **Main Goal**.
- **Main Goal** choices are: Build muscle, Get stronger, Recomp my body, Maintain muscle with less time, and Return after a break.
- Assessment question screens follow one shared interaction pattern: one question, selectable answers, and a separate continue action.
- An **Assessment Draft** supports back navigation and answer replacement.
- Assessment answers are committed to the **Assessment Draft** only when the user continues from a question.
- Navigating back discards uncommitted answer changes.
- Assessment questions cannot be skipped in the MVP.
- An **Assessment Draft** is synced to the user's account only after authentication.
- Result calculation, recommended program, HIT principles education, and first workout preview happen after the **Assessment** questions.

## Example dialogue

> **Dev:** "Should the welcome screen show assessment progress?"
> **Domain expert:** "No. Progress starts after the user chooses to begin the **Assessment**."

> **Dev:** "Is **Main Goal** a separate onboarding concept or just generic screen copy?"
> **Domain expert:** "It is the first **Assessment** question and captures the user's current primary training outcome."

> **Dev:** "If the user changes an earlier answer, do we keep both answers?"
> **Domain expert:** "No. The **Assessment Draft** keeps the current answer for each question and recalculates the recommendation later."

## Flagged ambiguities

- "onboarding" can mean the full first-run journey or the **Assessment** specifically; resolved: use **Assessment** for the coach-style intake that begins after the welcome screen.
