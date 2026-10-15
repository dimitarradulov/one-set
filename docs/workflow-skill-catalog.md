# OneSet workflow skill catalog

Inspected 2026-10-14. This inventories every `skills/**/SKILL.md` in the two repositories at the pinned commits: **Matt Pocock: 38** (20 engineering, 7 productivity, 4 miscellaneous, 7 in-progress); **Addy Osmani: 25**. These are upstream inventories, not a list of installed OneSet skills. Each linked file supports its skill’s purpose; the route assignments and adaptations are **OneSet proposals**, not measured Jev decisions.

Primary snapshots: [Matt tree](https://github.com/mattpocock/skills/tree/49dd158d1076134a641b33efb035946536778336/skills), [Addy tree](https://github.com/addyosmani/agent-skills/tree/aeac41d4d005999432bb7312f7ff06383a91d59d/skills).

## Suggested cases

- **Discover:** important requirements or architecture remain unresolved.
- **Build:** requirements and dependencies are sufficiently clear.
- **Debug:** existing behavior is broken.
- **Improve:** a stated quality or performance goal needs work.
- **Direct/setup:** research, review, learning, documentation, setup, or releases can start directly when requested. They need not become feature implementations.

A skill appearing in several cases is conditional support, not a mandatory step in every run. Choose one interview, spec writer, task breakdown, testing process and review process; borrow useful checks from the other collection instead of repeating the work.

## Matt Pocock

### Engineering — 20

| Skill | Case | Proposed OneSet use |
|---|---|---|
| [ask-matt](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/ask-matt/SKILL.md) | Router | Reference for Jev’s route selection; avoid running two routers. |
| [code-review](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/code-review/SKILL.md) | Build, Debug, Improve; direct | Check requirements and repository standards before completion. |
| [codebase-design](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/codebase-design/SKILL.md) | Discover, Build, Improve | Design small interfaces around useful behavior; follow OneSet architecture. |
| [diagnosing-bugs](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/diagnosing-bugs/SKILL.md) | Debug | Create a reliable failure signal, isolate the cause, fix and guard it. |
| [domain-modeling](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/domain-modeling/SKILL.md) | Discover, Build, Improve | Clarify workout/session vocabulary and record meaningful domain decisions. |
| [grill-with-docs](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/grill-with-docs/SKILL.md) | Discover | Resolve open decisions and retain glossary/ADR changes. |
| [implement-spec](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/implement-spec/SKILL.md) | Build | Coordinate ready tickets from an approved dependency graph; obey Git rules. |
| [implement](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/implement/SKILL.md) | Build | Implement one clear task and validate/review it; adapt commit behavior. |
| [improve-codebase-architecture](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/improve-codebase-architecture/SKILL.md) | Improve → Discover | Find architecture friction, choose a candidate, clarify the redesign. |
| [pr](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/pr/SKILL.md) | Build, Debug, Improve; direct | Write PR evidence and change risk when preparing a requested PR. |
| [prototype](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/prototype/SKILL.md) | Discover | Answer one design question; adapt UI experiments to native SwiftUI. |
| [research](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/research/SKILL.md) | Discover; conditional others | Delegate primary-source investigation and save cited findings. |
| [retro](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/retro/SKILL.md) | Direct; after any route | Review a completed session and propose better agent guidance/checks. |
| [setup-matt-pocock-skills](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/setup-matt-pocock-skills/SKILL.md) | Setup | Configure tracker/labels/domain docs; reuse existing OneSet setup. |
| [tdd](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/tdd/SKILL.md) | Build, Debug, Improve | Test observable behavior with Swift Testing/XCTest or Worker tooling. |
| [to-spec](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/to-spec/SKILL.md) | Discover → Build | Turn settled discussion into a GitHub specification. |
| [to-tickets](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/to-tickets/SKILL.md) | Discover → Build | Create small end-to-end GitHub tickets with blocking relationships. |
| [triage](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/triage/SKILL.md) | Incoming issues → Discover/Debug/Build | Assess raw reports; do not re-triage ready implementation tickets. |
| [wayfinder](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/wayfinder/SKILL.md) | Discover; huge efforts only | Resolve linked decision tickets until a large effort can be specified. |
| [wizard](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/wizard/SKILL.md) | Setup; conditional any route | Guide only dashboard/credential steps the agent cannot perform. |

### Productivity — 7

| Skill | Case | Proposed OneSet use |
|---|---|---|
| [grill-me](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/grill-me/SKILL.md) | Discover; direct alternative | Discuss without saved domain docs; prefer grill-with-docs inside OneSet. |
| [grilling](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/grilling/SKILL.md) | Discover | Questioning primitive underneath discovery; do not stack duplicate interviews. |
| [handoff](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/handoff/SKILL.md) | Any route; direct boundary | Write portable context for a different agent/directory/session. |
| [teach](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/teach/SKILL.md) | Direct learning | Teach a requested concept in a separate learning workspace. |
| [to-questionnaire](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/to-questionnaire/SKILL.md) | Discover; direct | Draft questions for a trainer/user holding missing knowledge; sending is separate. |
| [wait-what](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/wait-what/SKILL.md) | Any route; direct | Explain an unclear previous message in plain language. |
| [writing-for-agents](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/writing-for-agents/SKILL.md) | Setup; conditional Improve | Write skills, agent rules, and the documents they reference. |

### Miscellaneous — 4

| Skill | Case | Proposed OneSet use |
|---|---|---|
| [git-guardrails-claude-code](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/misc/git-guardrails-claude-code/SKILL.md) | Setup; Claude Code only | Install Claude hooks if requested; not a Codex workflow. |
| [migrate-to-shoehorn](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/misc/migrate-to-shoehorn/SKILL.md) | Improve; TypeScript only | Replace test assertions with shoehorn where relevant in Worker tests. |
| [scaffold-exercises](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/misc/scaffold-exercises/SKILL.md) | Direct; outside product routes | Course-exercise scaffolding; no normal OneSet product use. |
| [setup-pre-commit](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/misc/setup-pre-commit/SKILL.md) | Setup | Husky/lint-staged setup for JS/TS; adapt to existing project checks. |

### In-progress — 7; excluded from automatic routing

| Skill | Case | Proposed OneSet use |
|---|---|---|
| [chief-of-staff](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/chief-of-staff/SKILL.md) | Experimental; direct only | Long-running coordination; do not enable its broad autonomy by default. |
| [claude-handoff](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/claude-handoff/SKILL.md) | Experimental; Claude only | Launch a Claude background continuation; not a native Codex adapter. |
| [loop-me](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/loop-me/SKILL.md) | Experimental; Discover/setup | Specify recurring automation workflows, potentially the future router itself. |
| [setup-ts-deep-modules](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/setup-ts-deep-modules/SKILL.md) | Experimental; setup/Improve | Enforce TypeScript package boundaries; consider for Worker only if needed. |
| [writing-beats](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/writing-beats/SKILL.md) | Experimental; direct writing | Develop an article beat by beat; outside implementation routes. |
| [writing-fragments](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/writing-fragments/SKILL.md) | Experimental; direct writing | Gather writing material; outside implementation routes. |
| [writing-shape](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/in-progress/writing-shape/SKILL.md) | Experimental; direct writing | Shape existing material into an article; outside implementation routes. |

## Addy Osmani — 25

| Skill | Case | Proposed OneSet use |
|---|---|---|
| [api-and-interface-design](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/api-and-interface-design/SKILL.md) | Discover, Build, Improve | Define Swift/Worker contracts, errors, compatibility and access rules. |
| [browser-testing-with-devtools](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/browser-testing-with-devtools/SKILL.md) | Build, Debug, Improve; web only | Use for browser surfaces; native app needs simulator/XCTest instead. |
| [ci-cd-and-automation](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/ci-cd-and-automation/SKILL.md) | Build, Improve; direct setup | Automate repository validation and release checks. |
| [code-review-and-quality](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/code-review-and-quality/SKILL.md) | Build, Debug, Improve; direct | Review quality dimensions; fold useful checks into the chosen review. |
| [code-simplification](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/code-simplification/SKILL.md) | Improve; bounded Build/Debug | Simplify relevant code without changing behavior or widening scope. |
| [constraint-driven-development](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/constraint-driven-development/SKILL.md) | Discover; setup/Improve | Define missing measurable standards; preserve existing OneSet quality rules. |
| [context-engineering](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/context-engineering/SKILL.md) | All four; setup | Load relevant docs/tickets; adapt agent rules without duplicating guidance. |
| [debugging-and-error-recovery](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/debugging-and-error-recovery/SKILL.md) | Debug | Reproduce, localize, fix and verify; choose this or diagnosing-bugs. |
| [deprecation-and-migration](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/deprecation-and-migration/SKILL.md) | Discover, Build, Improve | Plan compatibility and safe data/system transitions; follow database rules. |
| [documentation-and-adrs](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/documentation-and-adrs/SKILL.md) | Discover, Build, Improve; direct | Record significant decisions and update affected documentation. |
| [doubt-driven-development](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/doubt-driven-development/SKILL.md) | Conditional all four | Independent challenge for high-stakes auth, sync or migration decisions. |
| [frontend-ui-engineering](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/frontend-ui-engineering/SKILL.md) | Build, Improve; UI | Adapt accessibility, layout and state guidance to SwiftUI. |
| [git-workflow-and-versioning](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/git-workflow-and-versioning/SKILL.md) | Build, Debug, Improve; direct | Organize branches/commits/PRs under OneSet Git rules. |
| [idea-refine](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/idea-refine/SKILL.md) | Discover | Explore options and select a direction before specifying. |
| [incremental-implementation](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/incremental-implementation/SKILL.md) | Build; Debug/Improve changes | Deliver small runnable slices, checking each before expansion. |
| [interview-me](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/interview-me/SKILL.md) | Discover | Clarify user, purpose and success; alternative to Matt’s interview. |
| [observability-and-instrumentation](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/observability-and-instrumentation/SKILL.md) | Build, Improve; Debug follow-up | Add useful privacy-conscious logs/metrics; feeds later diagnosis. |
| [performance-optimization](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/performance-optimization/SKILL.md) | Improve; Debug regression | Measure, find bottleneck, change, compare; use Instruments for iOS. |
| [planning-and-task-breakdown](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/planning-and-task-breakdown/SKILL.md) | Discover → Build; complex Improve | Plan ordered verifiable tasks; alternative to to-tickets. |
| [security-and-hardening](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/security-and-hardening/SKILL.md) | Conditional all four | Assess auth, sensitive training data, untrusted input and dependency risks. |
| [shipping-and-launch](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/shipping-and-launch/SKILL.md) | Release preparation after any route | Plan rollout, monitoring and recovery; release remains separately authorized. |
| [source-driven-development](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/source-driven-development/SKILL.md) | Conditional all four | Check current Apple/Clerk/Cloudflare/library docs for version-sensitive choices. |
| [spec-driven-development](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/spec-driven-development/SKILL.md) | Discover → Build | Write missing requirements/acceptance criteria; reuse existing specs. |
| [test-driven-development](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/test-driven-development/SKILL.md) | Build, Debug, Improve | Failing behavior test, fix, refactor; choose this or Matt’s tdd. |
| [using-agent-skills](https://github.com/addyosmani/agent-skills/blob/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/using-agent-skills/SKILL.md) | Router | Reference for phase-based selection; Jev replaces duplicate routing. |

## Four adapted examples

**Discover — offline workout sync:** read domain/architecture and existing decisions → `research` for unresolved facts → `grill-with-docs` for remaining choices → `prototype` only for a question needing a runnable answer → `to-spec` → `to-tickets` when multiple sessions are needed → Build. Add `api-and-interface-design` and migration/security guidance where their triggers apply. Use `wayfinder` only if the decision space is too large for ordinary discovery.

**Build — workout history filtering with agreed requirements:** read existing issue and affected storage/UI contracts → `incremental-implementation` → chosen TDD process for meaningful filter/persistence behavior → native SwiftUI guidance and simulator inspection for visible changes → OneSet validation → chosen review. No second specification or interview unless investigation reveals a real unresolved decision.

**Debug — rest timer fails after backgrounding:** chosen debugging skill → reproducible background/resume failure → isolate clock/lifecycle/persisted-deadline cause → failing regression test where practicable → smallest fix → relevant validation and native runtime checks → chosen review. Add instrumentation only if current evidence is insufficient or future diagnosis needs it.

**Improve — slow workout-history scrolling:** `performance-optimization` adapted to Instruments → record baseline with realistic history → identify bottleneck → targeted `code-simplification` or architecture work only if evidence supports it → compare measurements → regression verification and review. A substantial architectural redesign detours through Discover rather than silently broadening the task.

## Adaptation and routing limits

OneSet’s [architecture](agents/architecture.md), [validation](agents/validation.md), [Git workflow](agents/git-workflow.md), [database](agents/database.md), and [domain](agents/domain.md) rules govern every selected workflow. Preserve the existing document layout and GitHub tracker. SwiftUI is native iOS: use Swift/SwiftUI specialist guidance, Swift Testing/XCTest, simulator inspection, accessibility tools and Instruments. Browser DOM, React, npm and Lighthouse recipes do not transfer literally; TypeScript-specific skills may suit `worker/` but cannot impose a TS module layout on the app.

Many Matt skills declare `disable-model-invocation: true`, so their upstream commands are explicit entry points. A future automatic router needs deliberately adapted OneSet workflow definitions that preserve user authorization and project rules. Upstream commits, publishing issues, launching other agents, external messages and releases must not become automatic simply because a route was selected. Addy’s strongest default gates also require adaptation to the task and OneSet validation scope. No installations or live Jev calls were made for this catalog.

If Jev lacks context, the next action should identify the missing fact: read the issue or relevant code, research a dependency, or ask one focused decision question. Low confidence should produce a visible tentative recommendation or local fallback, not automatically turn every request into a long interview. Routing confidence and vendor interview confidence are separate concepts; neither proves the decision is correct.
