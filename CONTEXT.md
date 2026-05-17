# OneSet Context

OneSet is a focused HIT training app where onboarding, program preview, and paid training access are distinct parts of the user journey.

## Language

**Assessment**:
A coach-style onboarding intake that gathers a user's goal, training background, recovery, schedule, equipment, limitations, and intensity comfort before recommending a starter program.
_Avoid_: Quiz, survey

## Relationships

- The welcome screen introduces the **Assessment** but is not counted as an assessment step.

## Example dialogue

> **Dev:** "Should the welcome screen show assessment progress?"
> **Domain expert:** "No. Progress starts after the user chooses to begin the **Assessment**."

## Flagged ambiguities

- "onboarding" can mean the full first-run journey or the **Assessment** specifically; resolved: use **Assessment** for the coach-style intake that begins after the welcome screen.
