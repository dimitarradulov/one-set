# OneSet Product Specification

**Product name:** OneSet  
**Product type:** Mobile fitness app  
**Platform:** React Native + Expo + Expo Router  
**Training philosophy:** High Intensity Training (HIT)  
**Document version:** MVP Product Specification  
**Last updated:** 2026-05-09

---

## 1. Product Vision

OneSet is a serious, focused mobile training app built exclusively around High Intensity Training principles.

The app is not a generic workout tracker, social fitness app, or habit gamification product. Its purpose is to help users perform fewer, harder, better-planned workouts, track their working sets, recover properly, and progress over time.

Core promise:

> Build muscle with fewer, harder, smarter workouts.

Core product idea:

> OneSet gives users a personalized HIT program, guides them through focused workouts, tracks their logbook, and recommends progression based on performance and recovery.

---

## 2. Target Audience

OneSet is designed for beginner to advanced lifters who want efficient muscle-building training based on HIT principles.

Primary audience segments:

- Busy people who want to build muscle without living in the gym
- Beginners who need a clear HIT starting point
- Intermediate lifters who want measurable progression
- Advanced lifters interested in low-volume, high-effort training
- Users who are tired of bloated 5–6 day bodybuilding routines
- Users interested in training inspired by classic HIT principles, but presented in a modern, beginner-friendly app experience

The app should support beginners without dumbing down the product for serious lifters.

---

## 3. Core Product Principles

1. **HIT-only focus**  
   Every program and workout must follow HIT principles: low volume, high effort, progressive overload, controlled form, and sufficient recovery.

2. **Minimal distraction**  
   The app should not include social feeds, streaks, motivational spam, random content, or unnecessary wellness features.

3. **The logbook matters**  
   Progression is based on what the user did last time and what they can improve next time.

4. **Recovery is part of the program**  
   OneSet should not blindly push more workouts. It should respect fatigue, performance drops, and recovery needs.

5. **Rules first, AI later**  
   Training decisions should be made by deterministic, testable rules. AI may later explain those decisions in a coach-like tone.

6. **Preview for free, trial required to train**  
   Users can preview their personalized program for free, but they need an active trial or subscription to start workouts and log progress.

---

## 4. Business Model and Access Model

### 4.1 Monetization Model

OneSet uses a free preview plus subscription trial model.

Access flow:

```txt
Free onboarding
→ Personalized program preview
→ Account creation
→ 14-day free trial to start training
→ Auto-renewing monthly/yearly subscription unless canceled
```

There is no long-term free workout tracking plan.

### 4.2 Trial Model

The 14-day free trial is attached to an auto-renewing subscription.

The user chooses a monthly or yearly plan before starting the trial. The trial starts immediately and grants full access. After 14 days, the subscription automatically converts to the selected plan unless the user cancels.

Paywall copy must clearly state the post-trial price and renewal terms.

Example:

> Free for 14 days. Then €7.99/month unless canceled.

There is no separate manual “trial ended, now subscribe” step. The app store handles conversion automatically.

### 4.3 User Access States

| State | Access |
|---|---|
| Guest / Preview | Onboarding, personalized program preview, first workout preview, HIT principles, limited exercise details |
| Authenticated but no trial | Account/program saved, but cannot start workouts |
| Trial active | Full training access during trial |
| Subscriber active | Ongoing full access |
| Expired / canceled | Preview/account access only; no workout start/logging |

### 4.4 Feature Access

Preview users can:

- Complete onboarding
- View their personalized program
- View first workout preview
- Read HIT principles
- View limited exercise details and basic form videos

Trial/subscriber users can:

- Start workouts
- Log working sets
- Use the logbook
- Complete program cycles
- Receive rules-based progression guidance
- Access the core training experience

Post-MVP subscriber features may include:

- AI post-workout summaries
- Advanced progression explanations
- Advanced substitutions
- More program options
- Charts and deeper analytics
- Founder Lifetime offer during launch

---

## 5. Authentication Strategy

### 5.1 Auth Provider

OneSet uses **Clerk** for authentication.

Supabase stores app-specific user data through an `app_users` table containing `clerk_user_id`.

### 5.2 Auth Placement

Authentication should not be required before onboarding.

Flow:

```txt
User opens app
→ Completes onboarding
→ Sees personalized program
→ Auth prompt appears
```

Auth prompt message:

> Create an account to save your progress

Footer:

> Free to start. No payment required.

Users can close/dismiss the auth prompt. If they close it, they remain in Preview Mode. There is no explicit “Continue in guest mode” CTA.

### 5.3 Guest / Preview Restrictions

If the user dismisses authentication, they can only preview the program. They cannot start a workout, log sets, build a logbook, or access progression features.

When a preview user taps **Start Workout**, show the auth prompt again.

After authentication, when the user tries to start the first workout, show the 14-day free trial paywall.

---

## 6. Onboarding

### 6.1 Onboarding Goal

Onboarding should feel like a serious coach assessment, not a generic fitness quiz.

The user should feel:

> This app understands my training level, recovery, schedule, equipment, goal, and comfort with intensity.

### 6.2 Onboarding Screens

1. Welcome / positioning
2. Main goal
3. Training experience
4. HIT experience
5. Days available
6. Session length
7. Equipment access
8. Recovery profile
9. Lifestyle stress
10. Injury / limitation check
11. Training direction / desired result
12. Failure comfort
13. Result calculation
14. Recommended starter program
15. HIT principles education
16. First workout preview

### 6.3 Welcome Screen

Headline:

> Build muscle with fewer, harder, smarter workouts.

Subtext:

> OneSet creates HIT-based training programs built around your experience, recovery, schedule, and equipment.

CTA:

> Start Assessment

Optional small text:

> Takes less than 2 minutes.

> Already have and account? Sign in.

### 6.4 Main Goal

Question:

> What is your main goal right now?

Options:

- Build muscle
- Get stronger
- Recomp my body
- Maintain muscle with less time
- Return after a break

### 6.5 Training Experience

Question:

> How long have you been lifting consistently?

Options:

- New to lifting
- Less than 1 year
- 1–3 years
- 3–5 years
- 5+ years

### 6.6 HIT Experience

Question:

> Have you trained with HIT before?

Options:

- No, this is new to me
- I’ve tried it a few times
- Yes, I understand training to failure
- Yes, I’ve used HIT for a long time

Important rule:

> An advanced lifter who is new to HIT should not automatically receive the most demanding advanced HIT program.

### 6.7 Days Available

Question:

> How many days per week can you realistically train?

Options:

- 1 day
- 2 days
- 3 days
- 4 days
- Not sure

Do not encourage 5–6 training days in MVP.

### 6.8 Session Length

Question:

> How long do you want each workout to be?

Options:

- 20 minutes
- 30 minutes
- 45 minutes
- 60 minutes

The app identity should naturally support 30-minute sessions, but the user can choose.

### 6.9 Equipment Access

Question:

> What equipment do you have access to?

Options:

- Full gym
- Basic gym
- Home gym
- Dumbbells only
- Machines mostly
- Bodyweight only

Definitions:

- **Full gym:** broad machines, cables, free weights, benches, racks, leg press, pulldowns, rows, etc.
- **Basic gym:** limited machines, mostly free weights, benches, racks, maybe some cables.

### 6.10 Recovery Profile

Question:

> How well do you usually recover from hard training?

Options:

- I recover quickly
- Average
- I get sore for days
- I often feel drained
- I’m not sure

### 6.11 Lifestyle Stress

Question:

> How demanding is your current lifestyle?

Options:

- Low stress, good sleep
- Moderate stress
- High stress, poor sleep
- Physically demanding job
- Desk job, mostly sedentary

### 6.12 Injury / Limitation Check

Question:

> Any areas we should be careful with?

Options allow multiple selections:

- Shoulders
- Lower back
- Knees
- Elbows
- Wrists
- Neck
- No limitations

Use safe wording such as “areas to be careful with,” not medical diagnostic language.

### 6.13 Training Direction / Desired Result

This replaces the original technical “Preferred Training Style” question.

Question:

> Which result sounds most like what you want?

Options:

- **Lean Athletic**  
  Defined, capable, muscular without looking bulky.

- **Powerhouse**  
  Bigger traps, neck, back, legs, and dense strength.

- **Classic Balanced**  
  Chest, shoulders, arms, back, and legs developed evenly.

- **Upper-Body Emphasis**  
  More focus on chest, shoulders, arms, and V-taper.

- **Minimalist Muscle**  
  The fewest workouts needed to keep progressing.

- **Let OneSet Choose**  
  Recommended if you’re unsure.

Avoid beginner-confusing terms during onboarding, such as:

- upper/lower split
- body-part split
- consolidated routine
- antagonist split
- pre-exhaust
- rest-pause
- forced reps

The user chooses the desired result. OneSet chooses the appropriate training structure internally.

Avoid promising exact celebrity/wrestler bodies. Use aspirational but realistic language.

### 6.14 Failure Comfort

Question:

> How comfortable are you training close to muscular failure?

Options:

- I prefer to stop with reps in reserve
- I can push hard, but not every set
- I’m comfortable going to failure
- I use advanced intensity techniques

### 6.15 Result Calculation

Show a short assessment moment:

- Analyzing your training level…
- Matching your recovery profile…
- Selecting your HIT frequency…
- Building your starter program…

### 6.16 Recommended Program Screen

Show:

- Program name
- Days/week
- Estimated workout length
- Intensity level
- Recovery demand
- Why the program was chosen
- What happens after the 12-workout cycle

Example CTA:

> Continue

Immediately after this screen, display the auth prompt:

> Create an account to save your progress

Footer:

> Free to start. No payment required.

### 6.17 HIT Principles Education

Show before the first workout/trial training.

Rules:

1. **Warm up properly**  
   Prepare the joints and target muscle before the working set.

2. **One hard working set**  
   Most exercises use one true working set taken close to the target effort.

3. **Progress or recover**  
   Your goal is to beat the logbook when recovery allows it.

4. **Effort matters**  
   Low volume only works when the working set is genuinely hard.

Introduce Effort Level here.

---

## 7. Effort Level

OneSet uses a simple Effort Level scale, not a technical “App Intensity Scale.”

The scale is 1–10, but the app primarily explains levels 8–10.

| Effort | Meaning |
|---:|---|
| 8 | Hard, about 2 clean reps left |
| 9 | Very hard, about 1 clean rep left |
| 10 | True muscular failure, no clean reps left |

Use beginner-friendly HIT language like “clean reps left,” not technical powerlifting language like RPE/RIR.

### 7.1 Effort by User Level

| User type | Starting effort |
|---|---|
| Beginner / new to HIT | Mostly Effort 8–9 in first cycle |
| Intermediate | Mostly Effort 9–10 depending on exercise |
| Advanced | Effort 10 selectively and intelligently |

### 7.2 Effort Logging

When logging a working set, required fields are:

- kg / weight
- reps

Optional field:

- effort

Effort helps OneSet judge whether progression is valid and provide better recommendations, but it should not make logging feel complicated.

---

## 8. Main Navigation

MVP bottom tabs:

| Tab | Purpose |
|---|---|
| Home | What should I do next? |
| Program | Understand and manage the current plan |
| Logbook | Track workout and exercise history |
| Profile | Account, subscription, assessment, preferences |

Avoid 5+ tabs in MVP.

---

## 9. Home Page

### 9.1 Purpose

The Home page should answer:

> What should I do next?

It should be the training command center, not a feed or content dashboard.

### 9.2 Structure

1. Header / current program context
2. Main card: Next workout
3. Recovery / readiness note
4. Last workout summary
5. Cycle progress

### 9.3 Example Layout

```txt
Today                              [Profile]
Foundation Full-Body HIT

NEXT WORKOUT
Workout A — Full Body
5 exercises • ~30 min
Last trained: 4 days ago
Goal: Beat your logbook

[Start Workout]

Recovery check
You’re likely ready for your next HIT session.

Last workout
Workout B — Full Body
2 exercises improved

Program Progress
Cycle 1 • 3 of 12 workouts completed
```

### 9.4 Preview Mode Home

Preview users can see:

- personalized program
- next workout preview
- start workout CTA

When they tap **Start Workout**, show auth/trial flow.

### 9.5 What Not to Include

Do not include:

- motivational quotes
- streaks
- daily challenges
- social feed
- calories
- step tracking
- random education articles
- aggressive upgrade banners
- large AI chat button

---

## 10. Program Page

### 10.1 Purpose

The Program page should answer:

> What plan am I following, why was it chosen, and what’s coming next?

Home is for action. Program is for context.

### 10.2 Structure

1. Current program overview
2. Cycle progress
3. Why this program was chosen
4. Workout list
5. Program rules
6. Review/change program option

### 10.3 Program Overview

Show:

- Program name
- Days/week
- Estimated session time
- Level
- Short explanation

Example:

```txt
Foundation Full-Body HIT
2 days/week • ~30 min • Beginner HIT

Built for beginners who need simple full-body training, controlled effort, and enough recovery between sessions.
```

### 10.4 Cycle Progress

Use cycles based on completed workouts, not fixed weeks.

Example:

```txt
Cycle 1 • 3 of 12 workouts completed
```

Default cycle length:

> 12 completed workouts

### 10.5 Why This Program Fits You

Show 3–4 reasons based on onboarding.

Example:

- Matches your 2-day schedule
- Built for users new to HIT
- Uses simple full-body sessions
- Keeps recovery demand moderate

### 10.6 Workout List

Each workout card shows:

- workout name
- number of exercises
- estimated duration
- status: Next / Completed / Upcoming
- last completed date if applicable

### 10.7 Workout Preview

Show:

- estimated duration
- target effort
- muscles trained
- exercise list
- basic form/video access

Example:

| Exercise | Working set | Target effort |
|---|---:|---:|
| Leg Press | 1 × 8–12 | 8–9 |
| Chest Press | 1 × 6–10 | 8–9 |
| Pulldown | 1 × 8–12 | 8–9 |

Note:

> Warm-up sets are not counted as working sets.

### 10.8 Program Rules

Show 3–4 simple rules:

1. Warm up before your working set
2. Use one hard working set
3. Beat the logbook when ready
4. Respect recovery

### 10.9 Program Switching

Do not encourage random program hopping.

Use a lower-page option:

> Review Program Options

If selected, guide the user toward:

- keeping current program
- updating assessment
- changing goal/direction
- program recommendation after cycle review

For MVP, prefer **Update Assessment** over free manual switching.

---

## 11. Exercise Videos

### 11.1 MVP Video Decision

OneSet includes exercise videos showing correct form.

Rules:

- Videos are inside the exercise detail screen
- Exercise rows can show a small video/play icon
- Videos should be short, loopable demos, ideally 5–12 seconds
- Videos are muted by default
- Basic form demo videos are free for all users
- Videos should not clutter Home or Program pages

### 11.2 HIT Execution Style

Videos should demonstrate:

- controlled reps
- safe range of motion
- no bouncing
- stable positioning
- effort without form breakdown
- controlled negative

### 11.3 MVP Video Type

For MVP, each exercise has one basic form demo video.

No `type` field is needed because all videos are basic form demos.

Future video types may include common mistakes, advanced breakdowns, or substitution tutorials, but they are not part of MVP.

### 11.4 Video Hosting

Use **Bunny Stream** for MVP exercise video hosting to keep costs low.

Store only exercise video metadata in Supabase.

---

## 12. Logbook Page

### 12.1 Purpose

The Logbook should answer:

> Am I progressing?

It should show clear workout history, exercise history, kg/reps/effort records, and progression status.

### 12.2 MVP Decision

Use tables/lists first. Add charts later.

### 12.3 Structure

1. Header
2. Recent progress summary
3. Workouts view
4. Exercises view
5. Workout session detail
6. Exercise detail history

### 12.4 Recent Workouts

Example:

```txt
Recent Workouts

May 8
Workout A — Full Body
5 exercises • 32 min • 3 improved

May 4
Workout B — Full Body
5 exercises • 29 min • 2 improved
```

### 12.5 Workout Session Detail

Show:

| Exercise | Result | Effort | Progress |
|---|---:|---:|---|
| Leg Press | 140kg × 10 | 9 | +2 reps |
| Chest Press | 60kg × 8 | 9 | Same |
| Pulldown | 55kg × 9 | 8 | +1 rep |

### 12.6 Exercise History

Example:

```txt
Leg Press
Best: 160kg × 8
Last: 150kg × 10
Trend: Improving
```

### 12.7 Progression Labels

Use simple labels:

- New
- Improved
- Matched
- Dropped
- Ready to Increase
- Possible Stall

### 12.8 Empty State

For preview users:

> Start your 14-day free trial to build your logbook.

Subtext:

> OneSet tracks your working sets, effort, and progress so you know what to beat next time.

---

## 13. Profile Page

### 13.1 Purpose

The Profile page is the quiet settings and account area.

It should not be a social profile.

No followers, public stats, transformation gallery, achievement wall, or social identity features.

### 13.2 Structure

1. Account info
2. Subscription/trial status
3. Training profile
4. Current program shortcut
5. Preferences
6. Workout settings
7. Limitations
8. Support/legal
9. Sign out/delete account

### 13.3 Preview User Profile

Example:

```txt
Create an account to save your progress

Your program is ready, but you need an account to start workouts, build your logbook, and track progress.

[Create Account]

Free to start. No payment required.
```

### 13.4 Training Profile

Show current onboarding-derived values:

- goal
- experience
- HIT experience
- training days
- session length
- equipment
- recovery
- training direction

CTA:

> Update Assessment

This allows users to change goals, equipment, recovery, or schedule without randomly breaking program logic.

### 13.5 Preferences and Workout Settings

MVP settings:

- units: kg / lb
- theme: system / light / dark
- rest timer auto-start: on/off
- default rest duration
- rest timer sound: on/off
- rest timer vibration: on/off
- rest timer notifications: on/off

---

## 14. Workout Session Flow

### 14.1 High-Level Flow

```txt
Tap Start Workout
→ Access check
→ Workout overview
→ Active exercise screen
→ Warm-up guidance
→ Inline working set logging
→ Auto-start rest timer
→ Next exercise
→ Finish workout
→ Post-workout summary
→ Update logbook and cycle progress
```

### 14.2 Access Check

If Guest / Preview:

- show auth prompt
- return to preview if dismissed

If authenticated but no active trial/subscription:

- show 14-day trial paywall
- return to preview if declined

If trial/subscriber:

- start workout

### 14.3 Pre-Workout Overview

Show:

- workout name
- exercise count
- estimated time
- target effort
- last completed date
- exercise list

Reminder:

> Warm-up sets prepare you. The working set is the one that counts.

CTA:

> Begin Workout

### 14.4 Active Workout Screen

The active workout screen should focus on one exercise at a time.

It should show:

- workout name
- exercise number
- exercise name
- target rep range
- target effort
- previous result
- today’s target
- warm-up guidance
- inline working set row
- form/video shortcut
- history shortcut
- skip option

### 14.5 Inline Logging

Do not use a separate “Log Set” modal/button.

The user logs directly on the active workout screen.

Example:

```txt
Working Set
[140 kg]   [reps]   [Effort 9]   [✓]
```

Behavior:

- weight is prefilled from recommendation/previous working weight when possible
- reps is empty
- effort can default to target effort but remains optional
- user taps checkmark/save
- set is saved
- rest timer auto-starts by default

### 14.6 Warm-Up Sets

Warm-ups are displayed as non-loggable guidance before the working set.

Example if target working weight is 140kg:

```txt
Warm-up
Set 1: 70kg × 8–10
Set 2: 105kg × 4–6

Working Set
[140 kg] [reps] [Effort 9] [✓]
```

Warm-up calculation examples:

| Warm-up count | Scheme |
|---|---|
| 0 | none |
| 1 | 50% |
| 2 | 50%, 75% |
| 3 | 40%, 60%, 80% |

Warm-up weights should be rounded to practical gym increments.

Warm-up volume depends on exercise type:

- heavy compounds: 2–3 warm-ups
- smaller isolation exercises: 0–1 warm-up
- later exercises for same muscle group: fewer warm-ups

Warm-up sets are not logged in MVP.

### 14.7 Rest Timer

After saving the working set, rest timer starts automatically by default.

Rest screen shows:

- timer
- next exercise
- previous logged set

Controls:

- Skip Rest
- Add 30 seconds

Profile/Workout Settings include:

- auto-start on/off
- default duration
- sound on/off
- vibration on/off
- notifications on/off

Default rest duration:

> 3 minutes

### 14.8 Skipping Exercises

If user skips an exercise, ask reason:

- Equipment unavailable
- Pain/discomfort
- Too fatigued
- Short on time
- Other

Record skip reason.

### 14.9 Workout Interruption Handling

If user closes app mid-workout:

- save session as `in_progress`
- offer Resume Workout on return

If user abandons workout:

- mark as abandoned/incomplete
- do not count toward cycle completion

### 14.10 Post-Workout Summary

Show:

- workout name
- duration
- exercises completed
- progression breakdown
- next-time targets

Example:

```txt
Workout Complete
Workout A — Full Body
Completed in 31 min
5 of 5 exercises completed

Progress
3 improved
1 matched
1 dropped
```

Ask short feedback:

> How did this session feel?

Options:

- Easy
- Good
- Very hard
- Too much

Optional notes field.

---

## 15. Program Cycles

### 15.1 Cycle Model

Avoid fixed “Week X of 8” language.

Use program cycles based on completed workouts.

Default:

> 12 completed workouts per cycle

Home/program progress example:

> Cycle 1 • 3 of 12 workouts completed

### 15.2 Cycle Completion

When the user completes the 12th workout, show Cycle Review.

Cycle Review recommends one of three paths:

1. Continue the same program
2. Repeat with small adjustments
3. Switch programs

---

## 16. Program Recommendation Rules

### 16.1 Source of Truth

Use the program library’s **Best For** sections as the guideline/source of truth for recommendation rules.

### 16.2 Inputs

Recommendation engine uses:

- training experience
- HIT experience
- days available
- session length
- equipment
- recovery profile
- lifestyle stress
- injury limitations
- training direction
- failure comfort

### 16.3 Internal Assessment

Before selecting a program, determine:

- internal training level
- HIT readiness
- recovery capacity
- equipment fit
- desired training direction

### 16.4 Recommendation Hierarchy

```txt
1. Safety / limitations
2. Experience / HIT readiness
3. Recovery capacity
4. Equipment access
5. Available schedule
6. Desired training direction
7. User preference
```

If uncertain, choose the safer program.

### 16.5 Hard Exclusions

Do not recommend advanced programs if the user is:

- beginner
- new to HIT
- low failure comfort
- poor recovery
- has major injury limitations

Do not recommend Athletic Power HIT to:

- beginners
- users with poor recovery
- users with major back/knee/shoulder limitations
- users without full gym access
- users uncomfortable with technical/athletic lifts

Do not recommend Weak-Point Rotation HIT as a first onboarding program unless the user is advanced and explicitly has a weak-point goal. Prefer it as a post-cycle recommendation.

### 16.6 Scoring and Exclusions

For MVP, recommendation tags and exclusions can be hardcoded.

Conceptual flow:

```txt
1. Remove unsafe/unsuitable programs using hard exclusions
2. Score remaining programs based on onboarding tags
3. Recommend the highest-scoring safe option
```

Output should include:

- recommended program
- why it fits
- starting effort
- what happens after the 12-workout cycle

---

## 17. Progression Rules

### 17.1 Default Model

Use double progression by default:

1. Add reps within target rep range
2. Increase weight after reaching the top of the range
3. Rebuild reps at the new weight

### 17.2 Increase Weight

Increase weight when:

```txt
reps reach top of target range
AND effort is 9–10 or effort is missing
AND no pain/form issue
AND no poor recovery warning
```

Suggested MVP weight jumps:

| Exercise type | Increase |
|---|---:|
| Upper body | +2.5kg |
| Lower body | +5kg |
| Isolation | smallest available increase |

Later, allow configurable increments.

### 17.3 Repeat Weight

Repeat the same weight when:

- reps are within target range but below the top
- user reaches top of range but effort is around 8
- user reaches top of range but recovery is poor

If effort is 8 at the top of the range, the user may have stopped too early. Encourage pushing closer to target effort before increasing.

### 17.4 Reduce Weight

Reduce weight if:

- reps fall below the minimum target range for 2 exposures in a row
- reps are far below the target range once
- pain/discomfort is reported
- form is marked poor

Suggested reduction:

> 5–10%

### 17.5 Missing Effort

Effort is optional.

If effort is missing:

- use reps and previous performance as fallback
- do not block recommendations
- gently encourage effort logging because it improves recommendation quality

### 17.6 Stall Detection

Flag possible stall when:

```txt
same exercise shows no meaningful improvement for 3 consecutive exposures
```

Do not flag stall if:

- user recently increased weight
- exercise was skipped
- poor sleep was reported
- user trained too soon
- pain/discomfort was reported
- effort was clearly below target

Flag stronger stall when:

- no improvement for 4–5 exposures
- performance drops twice in a row

### 17.7 Recommend More Recovery

Recommend more recovery when:

- same muscle is trained too soon
- multiple exercises drop in one workout while effort is high
- user repeatedly reports “too much” or “drained”
- cycle-level performance suggests poor recovery

### 17.8 Cycle Review Rules

At cycle review:

Continue same program if:

```txt
60%+ of tracked exercises improved
AND fewer than 25% are stalled
```

Repeat with adjustments if:

```txt
30–60% of exercises improved
OR 25–40% are stalled
OR recovery feedback is mixed
```

Recommend changing programs only when:

- fewer than 30% of exercises improved
- several key lifts stalled/dropped
- recovery or schedule mismatch is detected
- user consistently misses workouts
- user repeatedly reports poor recovery
- user changes goal/training direction

### 17.9 Cycle Review Evaluation Hierarchy

```txt
1. Safety / pain / limitations
2. Adherence
3. Recovery
4. Progress
5. Goal fit
6. Readiness to advance
```

### 17.10 Safety Override

Safety always overrides progression.

If the user reports:

- pain
- joint discomfort
- form breakdown
- dizziness
- unusual symptoms

Do not increase weight. Recommend reducing load, substituting the exercise, or resting without giving medical diagnosis.

---

## 18. Rules Engine and AI Strategy

### 18.1 Core Decision

Use a hybrid approach:

> Rules create the recommendation. AI explains it like a coach.

### 18.2 MVP Rules Engine

MVP uses deterministic rules for:

- progression status
- personal best detection
- rep range progression
- weight increase suggestions
- basic stall detection
- recovery spacing warnings
- cycle review recommendations

Core logic should be:

- consistent
- predictable
- testable
- cheap
- fast
- safe

### 18.3 AI Layer

AI is post-MVP/Pro and should be used mainly for:

- post-workout summaries
- “what should I do next?” explanations
- advanced coaching notes
- human-friendly interpretation of rule-based outputs

AI should not initially directly decide:

- exact weight jumps
- program changes
- injury/medical advice
- overtraining diagnoses
- complex recovery conclusions
- form correction

---

## 19. Notifications

### 19.1 MVP Decision

Do not support workout reminders in MVP.

Do not support:

- daily habit reminders
- streak notifications
- motivational notifications
- trial nudges
- educational tips
- comeback notifications
- recovery reminders

Only support functional rest timer notifications.

### 19.2 Rest Timer Notification

Trigger:

> Rest timer ends while app is backgrounded/minimized.

Example copy:

> Rest complete. Next exercise is ready.

Ask notification permission contextually when the user starts their first workout/rest timer.

Prompt:

> Enable rest timer alerts?

Subtext:

> We’ll notify you when your rest timer ends if you leave the app during a workout.

Include Profile/Workout Settings toggle:

> Rest timer notifications: On/Off

---

## 20. Legal and Safety

### 20.1 MVP Legal Items

Include:

- one-time fitness disclaimer
- safe pain/form copy
- Terms of Service
- Privacy Policy
- Fitness Disclaimer
- Delete Account
- clear subscription/trial terms

### 20.2 Fitness Disclaimer

Show before the user starts their first workout/trial training.

Suggested copy:

> OneSet provides general fitness and training guidance. It is not medical advice. Consult a qualified professional before starting a new exercise program, especially if you have injuries, medical conditions, or concerns. Stop exercising if you feel pain, dizziness, chest pain, or unusual discomfort.

Button:

> I Understand

### 20.3 Safe Workout Logic

If pain or poor form is reported:

- do not increase weight
- suggest reducing load, stopping the exercise, substituting, or resting
- do not diagnose

Avoid claims like:

- prevents injury
- fixes back pain
- diagnoses recovery
- treats overtraining

Use safer wording:

- training guidance
- recovery suggestions
- progression recommendations
- areas to be careful with
- not medical advice

### 20.4 Privacy Policy

Privacy Policy must explain:

- what data is collected
- why it is collected
- where it is stored
- third parties used: Clerk, Supabase, RevenueCat, Bunny Stream, PostHog, and any crash reporting tools if added
- how users can delete account/data

---

## 21. Technical Stack

| Area | Tool |
|---|---|
| Mobile app | React Native + Expo + Expo Router |
| Auth | Clerk |
| Database | Supabase / Postgres |
| Subscriptions | RevenueCat |
| Video hosting | Bunny Stream |
| Analytics | PostHog |

### 21.1 Access Control

RevenueCat is the source of truth for subscriptions/trials/entitlements.

Supabase mirrors latest known RevenueCat entitlement/access state for:

- fast backend checks
- analytics
- protecting workout-start/logging APIs

If RevenueCat and Supabase disagree, trust RevenueCat.

### 21.2 User Linking

Use Supabase `app_users` table containing `clerk_user_id`.

All user-specific training data should reference `app_users.id`, not Clerk IDs directly everywhere.

---

## 22. Data Model

### 22.1 app_users

```ts
app_users {
  id: uuid
  clerk_user_id: text
  email: text
  display_name: text
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.2 user_training_profiles

```ts
user_training_profiles {
  id: uuid
  user_id: uuid

  main_goal: 'build_muscle' | 'get_stronger' | 'recomp' | 'maintain_with_less_time' | 'return_after_break'

  training_experience: 'new' | 'less_than_1_year' | '1_to_3_years' | '3_to_5_years' | '5_plus_years'

  hit_experience: 'none' | 'tried_before' | 'understands_failure' | 'long_time_hit'

  days_available_per_week: 1 | 2 | 3 | 4
  preferred_session_length: 20 | 30 | 45 | 60

  equipment_access: 'full_gym' | 'basic_gym' | 'home_gym' | 'dumbbells_only' | 'machines_mostly' | 'bodyweight_only'

  recovery_profile: 'fast' | 'average' | 'sore_for_days' | 'often_drained' | 'not_sure'

  lifestyle_stress: 'low' | 'moderate' | 'high' | 'physical_job' | 'desk_job'

  training_direction: 'lean_athletic' | 'powerhouse' | 'classic_balanced' | 'upper_body_emphasis' | 'minimalist_muscle' | 'let_oneset_choose'

  failure_comfort: 'reps_in_reserve' | 'push_hard_not_every_set' | 'comfortable_to_failure' | 'advanced_intensity'

  created_at: timestamp
  updated_at: timestamp
}
```

### 22.3 user_limitations

```ts
user_limitations {
  id: uuid
  user_id: uuid
  area: 'shoulders' | 'lower_back' | 'knees' | 'elbows' | 'wrists' | 'neck'
  created_at: timestamp
}
```

### 22.4 programs

```ts
programs {
  id: uuid
  name: text
  slug: text
  level: 'beginner' | 'intermediate' | 'advanced'
  description: text
  short_description: text
  default_cycle_workout_count: integer // default 12
  recommended_days_per_week_min: integer
  recommended_days_per_week_max: integer
  estimated_session_minutes_min: integer
  estimated_session_minutes_max: integer
  recovery_demand: 'low' | 'moderate' | 'high' | 'very_high'
  equipment_requirement: 'full_gym' | 'basic_gym' | 'home_gym' | 'machines_mostly' | 'dumbbells_only' | 'bodyweight_only'
  is_active: boolean
  created_at: timestamp
  updated_at: timestamp
}
```

Use only `beginner`, `intermediate`, and `advanced` for MVP. Avoid `late_beginner` in the database enum.

### 22.5 workouts

```ts
workouts {
  id: uuid
  program_id: uuid
  name: text
  slug: text
  description: text | null
  sequence_order: integer
  estimated_minutes_min: integer
  estimated_minutes_max: integer
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.6 exercises

```ts
exercises {
  id: uuid
  name: text
  slug: text
  primary_muscle_group: text
  secondary_muscle_groups: text[]
  equipment_type: 'machine' | 'barbell' | 'dumbbell' | 'cable' | 'bodyweight' | 'band' | 'other'
  movement_pattern: 'squat' | 'hinge' | 'press' | 'pull' | 'row' | 'curl' | 'extension' | 'raise' | 'calf' | 'core' | 'neck' | 'other'
  difficulty: 'beginner' | 'intermediate' | 'advanced'
  default_rep_min: integer
  default_rep_max: integer
  default_target_effort: 8 | 9 | 10
  form_cues: text[]
  common_mistakes: text[]
  is_active: boolean
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.7 workout_exercises

```ts
workout_exercises {
  id: uuid
  workout_id: uuid
  exercise_id: uuid
  sequence_order: integer
  working_sets: integer // MVP usually 1
  target_rep_min: integer
  target_rep_max: integer
  target_effort: 8 | 9 | 10
  warmup_set_count: 0 | 1 | 2 | 3
  warmup_scheme: 'none' | '50' | '50_75' | '40_60_80'
  notes: text | null
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.8 exercise_videos

For MVP, no `type` field is needed.

```ts
exercise_videos {
  id: uuid
  exercise_id: uuid
  bunny_video_id: text
  playback_url: text
  thumbnail_url: text
  duration_seconds: integer
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.9 user_programs

```ts
user_programs {
  id: uuid
  user_id: uuid
  program_id: uuid
  status: 'active' | 'completed' | 'paused' | 'replaced'
  current_cycle_number: integer
  cycle_workout_target: integer
  completed_workouts_in_cycle: integer
  assigned_reason: text
  started_at: timestamp
  completed_at: timestamp | null
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.10 workout_sessions

```ts
workout_sessions {
  id: uuid
  user_id: uuid
  user_program_id: uuid
  workout_id: uuid
  status: 'in_progress' | 'completed' | 'abandoned'
  started_at: timestamp
  completed_at: timestamp | null
  duration_seconds: integer | null
  perceived_session_difficulty: 'easy' | 'good' | 'very_hard' | 'too_much' | null
  user_notes: text | null
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.11 logged_sets

MVP logs working sets only.

```ts
logged_sets {
  id: uuid
  workout_session_id: uuid
  workout_exercise_id: uuid
  exercise_id: uuid
  set_type: 'working'
  weight_kg: numeric
  reps: integer
  effort: integer | null // 1–10, optional
  form_status: 'good' | 'poor' | null
  pain_reported: boolean
  skipped: boolean
  skip_reason: 'equipment_unavailable' | 'pain_discomfort' | 'too_fatigued' | 'short_on_time' | 'other' | null
  created_at: timestamp
  updated_at: timestamp
}
```

### 22.12 progression_recommendations

```ts
progression_recommendations {
  id: uuid
  user_id: uuid
  exercise_id: uuid
  logged_set_id: uuid | null
  workout_session_id: uuid | null
  status: 'new' | 'improved' | 'matched' | 'dropped' | 'ready_to_increase' | 'possible_stall'
  recommendation_type: 'increase_weight' | 'repeat_weight' | 'reduce_weight' | 'more_recovery' | 'substitute_exercise' | 'continue'
  recommended_weight_kg: numeric | null
  recommended_rep_target_min: integer | null
  recommended_rep_target_max: integer | null
  reason: text
  created_at: timestamp
}
```

### 22.13 cycle_reviews

```ts
cycle_reviews {
  id: uuid
  user_id: uuid
  user_program_id: uuid
  cycle_number: integer
  workouts_completed: integer
  exercises_tracked: integer
  improved_exercise_count: integer
  stalled_exercise_count: integer
  dropped_exercise_count: integer
  personal_best_count: integer
  recovery_assessment: 'good' | 'mixed' | 'poor'
  adherence_assessment: 'good' | 'mixed' | 'poor'
  recommendation: 'continue_same_program' | 'repeat_with_adjustments' | 'switch_program'
  recommended_program_id: uuid | null
  summary: text
  created_at: timestamp
}
```

### 22.14 user_settings

```ts
user_settings {
  id: uuid
  user_id: uuid
  units: 'kg' | 'lb'
  theme: 'system' | 'light' | 'dark'
  rest_timer_auto_start: boolean
  default_rest_seconds: integer
  rest_timer_sound: boolean
  rest_timer_vibration: boolean
  rest_timer_notifications: boolean
  exercise_video_autoplay: boolean
  created_at: timestamp
  updated_at: timestamp
}
```

Defaults:

```ts
{
  units: 'kg',
  theme: 'system',
  rest_timer_auto_start: true,
  default_rest_seconds: 180,
  rest_timer_sound: true,
  rest_timer_vibration: true,
  rest_timer_notifications: true,
  exercise_video_autoplay: false
}
```

### 22.15 user_subscriptions

RevenueCat is source of truth. Supabase mirrors latest known state.

```ts
user_subscriptions {
  id: uuid
  user_id: uuid
  revenuecat_customer_id: text
  entitlement_status: 'none' | 'trial_active' | 'active' | 'expired' | 'cancelled' | 'billing_issue'
  plan: 'monthly' | 'yearly' | 'founder_lifetime' | 'none'
  trial_started_at: timestamp | null
  trial_ends_at: timestamp | null
  current_period_started_at: timestamp | null
  current_period_ends_at: timestamp | null
  store: 'apple' | 'google' | 'stripe' | 'none'
  external_subscription_id: text | null
  created_at: timestamp
  updated_at: timestamp
}
```

Access check:

```txt
Can start workout = entitlement_status is trial_active or active
```

---

## 23. Analytics

Use **PostHog** for product analytics.

Track key events such as:

- onboarding_started
- onboarding_completed
- program_recommended
- auth_prompt_viewed
- account_created
- trial_paywall_viewed
- trial_started
- workout_started
- working_set_logged
- workout_completed
- cycle_completed
- logbook_viewed
- subscription_started
- subscription_cancelled

Do not over-instrument sensitive health-related detail in MVP. Be clear in the Privacy Policy that PostHog is used.

---

## 24. MVP Scope

### 24.1 MVP Includes

- Coach-style onboarding
- Personalized program recommendation
- Preview mode
- Clerk authentication
- RevenueCat 14-day trial + subscription
- Home page
- Program page
- Workout session flow
- Inline working set logging
- Non-loggable warm-up guidance
- Configurable rest timer
- Rest timer notifications only
- Logbook tables/lists
- Basic rules engine for progression
- 12-workout cycle tracking
- Cycle Review
- Exercise detail screens
- Basic form videos via Bunny Stream
- Profile/settings/legal
- PostHog analytics

### 24.2 Post-MVP

- AI post-workout summaries
- Charts in Logbook
- Advanced substitutions
- Advanced program switching
- Full program library browsing
- Advanced cycle reviews
- Common mistake videos
- Advanced technique tutorials
- AI explanation layer
- More analytics
- Crash reporting
- Founder Lifetime launch offer

---

## 25. What OneSet Must Avoid

Do not build OneSet like a generic fitness/wellness app.

Avoid:

- social feeds
- public profiles
- daily streaks
- random badges
- calories burned focus
- step tracking
- water tracking
- motivational quote spam
- excessive notifications
- huge dashboards
- overcomplicated analytics in MVP
- AI making unsafe training decisions
- medical claims
- program hopping encouragement

OneSet should feel like:

> A serious HIT coach and logbook in your pocket.

---

## 26. Final Product Summary

OneSet is a focused HIT training app where users complete a coach-style assessment, receive one personalized starter program, preview it for free, create an account to save progress, start a 14-day trial to train, and then follow a low-volume HIT program through 12-workout cycles.

The core app experience is:

```txt
Open app
→ See next workout
→ Perform controlled warm-ups
→ Log one hard working set
→ Rest
→ Continue
→ Review progress
→ Beat the logbook next time
```

The MVP should prove one thing:

> Users are willing to follow a serious HIT program, log their working sets, and pay for structured progression guidance.
