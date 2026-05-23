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
- A **Program Recommendation** reads candidate programs from the **Program Library**.
- A **Program Recommendation** does not create or persist the user's active program.

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
