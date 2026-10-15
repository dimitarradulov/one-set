# Workflow routing for OneSet

Researched: 2026-10-14. Status: recommendation; no skills installed, router implemented, or live Jev requests made. Sources are upstream source files and official vendor documentation, inspected at their current URLs; these URLs can change. Pin revisions before adopting their contents.

## Recommendation

Combine selected practices into **OneSet workflows**, with Jev as an optional recommendation service. Start with an explicit routing entry point and compare its recommendations with existing agent routing before enabling automatic recommendations. Keep execution, repository rules, authorization, and validation under the coding agent's control.

Use Matt Pocock's discovery, domain language, specifications, and dependency-aware tickets where they solve a real planning problem. Add Addy Osmani's incremental implementation, structured debugging, measured optimization, interface design, and verification practices where applicable. Neither collection is exclusively a planning or implementation framework: both cover those activities. Their upstream routers already demonstrate composition. [Matt's `ask-matt`](https://github.com/mattpocock/skills/blob/main/skills/engineering/ask-matt/SKILL.md), [Addy's `using-agent-skills`](https://github.com/addyosmani/agent-skills/blob/main/skills/using-agent-skills/SKILL.md).

This is an engineering judgment for the current project, not evidence that adding an external router improves OneSet delivery. Prove that improvement before making it a dependency of ordinary development.

## What is verified

### Matt Pocock

The current collection describes small, adaptable, composable skills. Its README distinguishes user-invoked orchestration from model-invoked disciplines: user-invoked skills should not invoke other user-invoked skills. It includes discovery, tickets, implementation, TDD, debugging, architecture, and review; the proposed “Matt = full planning” division understates its scope. [Upstream README](https://github.com/mattpocock/skills).

`ask-matt` already recommends workflow entry points. It distinguishes a same-session implementation from a multi-session specification/ticket graph; bugs and triage have separate entry points. `to-spec` synthesizes the current conversation rather than conducting another interview. Reuse settled decisions instead of restarting discovery for every feature. [Router source](https://github.com/mattpocock/skills/blob/main/skills/engineering/ask-matt/SKILL.md), [`to-spec` source](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md).

OneSet already has adapted [`grill-with-docs`](../.agents/skills/grill-with-docs/SKILL.md), [`to-spec`](../.agents/skills/to-spec/SKILL.md), [`to-tickets`](../.agents/skills/to-tickets/SKILL.md), [`implement-spec`](../.agents/skills/implement-spec/SKILL.md), [`tdd`](../.agents/skills/tdd/SKILL.md), [`code-review`](../.agents/skills/code-review/SKILL.md), and [`triage`](../.agents/skills/triage/SKILL.md). Much of the requested foundation exists locally; copying the full upstream pack would introduce duplicates and potentially overwrite adaptations.

### Addy Osmani

The collection supplies lifecycle commands and automatic skill discovery, with 25 skills at inspection. Its implementation, debugging, API/interface, simplification, security, and observability guidance overlaps with Matt's collection and can be selected individually. [Upstream README](https://github.com/addyosmani/agent-skills).

The useful implementation principle is small vertical slices with verification. Debugging emphasizes reproduction, localization, reduction, correction, and regression protection. Performance work measures a baseline, changes the demonstrated bottleneck, and measures again. [Implementation source](https://github.com/addyosmani/agent-skills/blob/main/skills/incremental-implementation/SKILL.md), [debugging source](https://github.com/addyosmani/agent-skills/blob/main/skills/debugging-and-error-recovery/SKILL.md), [performance source](https://github.com/addyosmani/agent-skills/blob/main/skills/performance-optimization/SKILL.md).

Its performance and testing materials contain substantial web/JavaScript assumptions. Core Web Vitals, React memoization, and Chrome DevTools are not native SwiftUI acceptance criteria. The README also warns that individual skill installs can omit shared reference files. Selective adoption therefore requires inspecting dependencies and adapting examples, rather than copying isolated files blindly. [Performance source](https://github.com/addyosmani/agent-skills/blob/main/skills/performance-optimization/SKILL.md), [installation caveat](https://github.com/addyosmani/agent-skills#quick-start).

Both repositories declare MIT licensing. Preserve attribution and applicable license notices when adapting copied material. [Matt's license](https://github.com/mattpocock/skills/blob/main/LICENSE), [Addy's license](https://github.com/addyosmani/agent-skills/blob/main/LICENSE).

### Jev / TypeSafe AI

Jev accepts state and typed questions; Choice selects an option with probabilities and confidence. It does not write code, hold a conversation, invoke agent tools, or replace a coding agent's generative model. A bridge must consume its decision. [Introduction](https://docs.typesafe.ai/introduction), [coding agents](https://docs.typesafe.ai/introduction/coding-agents).

The supplied TypeScript example matches the documented import, constructor, `choice()` helper, and `systemOne()` structure. However, `result.answers.workflow` is an answer object, not the selected route string. Selection is `result.answers.workflow.choice`; confidence and probabilities remain on the object. The SDK reads `TYPESAFE_API_KEY`; the official quickstart permits omitting a model. This is documentation verification, not a compile or authenticated runtime test of the proposed function. [JavaScript SDK](https://docs.typesafe.ai/sdk/javascript).

Choice confidence is normalized top probability: `c = (p_max - 1/n) / (1 - 1/n)`. With five options, top probability 0.84 produces confidence 0.80. This statistic does not establish observed correctness on OneSet tasks. Choose thresholds from local evaluations, not an arbitrary universal number. Noul exposes a yes probability without a separate confidence field. [Confidence semantics](https://docs.typesafe.ai/confidence).

TypeSafe recommends splitting multi-factor judgments into narrow questions and combining their answers in code. Its skill-suggestion cookbook ranks a catalog, rechecks a shortlist, and allows no suggestion. The cookbook reports fewer wrong and needless skill loads on its own Hermes experiment, but also wrong suggestions that persuaded an agent away from an initially correct choice. Those results do not validate this project's routing. [Atomic questions](https://docs.typesafe.ai/introduction), [skill-suggestion experiment](https://docs.typesafe.ai/cookbooks/skill_suggestion).

The vendor documents literal interpretation, irrelevant-context degradation, adversarial steering, and option-order effects in Jev 1.13. Use explicit criteria, concise relevant state, and perturbation tests. Typed output prevents invented route identifiers; it does not prevent incorrect routing. [Known model limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13).

At inspection, `jev-1.13.0` costs $0.042 per million input tokens, with free output tokens. Published limits are 80 requests/second and 100K tokens/second, explicitly subject to change. A 2,000-token request costs approximately $0.000084; 1,000 such requests approximately $0.084, excluding other costs. Pin the model for evaluation because aliases move. These are published terms, not verified account availability or uptime guarantees. [Models and pricing](https://docs.typesafe.ai/models).

TypeSafe states customer requests/responses are not used for training; its legal page offers zero data retention to enterprise customers. Do not infer default zero retention from the no-training statement. Send sanitized task summaries and metadata, not credentials or identifiable workout/account records. This investigation did not establish a default retention duration, region guarantee, or service SLA. [Data handling](https://docs.typesafe.ai/models), [legal documentation](https://docs.typesafe.ai/legal).

## Proposed routing contract

Use neutral identifiers that describe the required work. Collection names are provenance, not mutually exclusive routes.

| Route | Entry condition | Sequence |
| --- | --- | --- |
| `discover` | Material behavior/architecture decisions are unresolved | Read sources → investigate unknowns → focused clarification/prototype → record decisions → spec/tickets only when needed |
| `build` | Acceptance criteria and dependencies are sufficiently defined | Reuse spec → select ready slice or ticket graph → implement → validate → review |
| `debug` | Existing behavior is broken or regressed | Reproduce → localize → reduce → fix → regression verification → review |
| `improve` | Explicit quality/performance goal with preserved behavior | Establish baseline → scoped change → compare → validate → review |
| `clarify` | Task/context is insufficient or routing remains uncertain | Gather the missing evidence or decision, then reroute |

Keep documentation-only changes and explicit review/research requests as deterministic direct entry points. Add specialist overlays independently: Swift/SwiftUI, UI design, persistence/sync, authentication, Worker/API, database migration. They change required guidance and evidence, not the basic workflow.

For uncertain requests, ask Jev separately about requirements completeness, unresolved decisions, broken existing behavior, and implementation dependencies. Compose a route in code with an explicit precedence policy. Missing dependencies can trigger investigation or a dependency ticket rather than a new product interview. A route is a recommendation, never authorization for deployment, merging, publishing issues, or destructive changes.

The bridge should accept a task summary, settled acceptance criteria, relevant issue/spec pointers, current phase, known dependencies, and relevant affected capabilities. Return a closed route identifier, distributions, model/rubric version, selected overlays, and the policy rule applied. Since Jev does not generate prose, any displayed explanation should be a policy-derived sentence or a clearly attributed coding-agent explanation.

## Adaptation required for OneSet

The [approved requirements](requirements.md), [domain glossary](../GLOSSARY.md), [architecture](agents/architecture.md), and [validation policy](agents/validation.md) remain authoritative. The app is native SwiftUI with a local-first training design, Cloudflare Worker, Neon, and Clerk; React Native routing examples should be replaced. [Project README](../README.md).

- Keep one specification source in GitHub Issues using `gh`; retain `GLOSSARY.md` and `docs/adr/`. Do not introduce competing PRDs, glossaries, or generic constraint documents that restate existing rules. [Tracker guidance](agents/issue-tracker.md), [domain guidance](agents/domain.md).
- Preserve Swift concurrency, injected capabilities, and durable transaction boundaries. Persistence/sync overlays explicitly verify save failure, restart recovery, retry identity, stale responses, account isolation, and migration of pending work. [Architecture](agents/architecture.md).
- Translate browser QA into appropriate simulator/device inspection, accessibility, and supported-size checks; use native profiling and OneSet's latency budgets for SwiftUI performance. Worker/API profiling stays relevant to backend work. [Validation](agents/validation.md), [requirements](requirements.md).
- Use the existing TDD discipline where behavior and test seams justify it. Do not add another TDD skill or force new tests for trivial prose edits. Local TDD currently requires agreement on behavior/seams; adapt unnecessary repeated confirmation to existing session authorization. [Local TDD](../.agents/skills/tdd/SKILL.md).
- Resolve review coverage before automation: the existing review compares committed `HEAD` with a fixed point, so it omits uncommitted edits. Also preserve its separate Standards and Spec axes when adding Addy's quality checks. [Local review](../.agents/skills/code-review/SKILL.md).
- Audit completion actions: local `implement-spec` drives integration branches and eventual merging. Route selection alone must not expand the user's authorized scope. Parallel implementation requires separate worktrees and a committed base. [Implementation skill](../.agents/skills/implement-spec/SKILL.md), [Git workflow](agents/git-workflow.md).

Several local orchestration skills have `disable-model-invocation: true`. Upstream Matt explicitly reserves orchestration skills for users. An automatic router should not silently load them. Either retain explicit invocation or deliberately create authorized OneSet workflow wrappers that compose appropriate model-invoked disciplines; do not assume generic slash commands launch identically in every agent host. [Local discovery wrapper](../.agents/skills/grill-with-docs/SKILL.md), [upstream invocation boundary](https://github.com/mattpocock/skills#reference), [Agent Skills specification](https://agentskills.io/specification).

## Examples to evaluate

These are proposed labels, not measured Jev results.

| Task and context | Expected handling |
| --- | --- |
| Fix a spelling error in documentation | Direct documentation path; review changed text/links |
| Add workout history with clear acceptance criteria, but no durable recording repository exists | Investigate/decompose dependencies first; build history when its foundation is ready |
| Implement an already approved full sync spec with ready tickets | `build` from the dependency graph; do not repeat discovery |
| Rest timer loses its deadline after restart | `debug` plus persistence overlay; tiny diff size does not justify reduced durability validation |
| History scrolling is slow on a supported device | `improve`; native profile and comparable before/after measurements |
| Introduce a workout-program generator | `discover` and check scope first; custom programs are currently deferred |
| Explain why feature models own navigation | Direct explanation/research as needed; no implementation workflow |

## Rollout and evaluation

1. **Define the catalog.** Adapt a small set of project workflows and specialist overlays. Pin upstream revisions, retain attribution, resolve invocation and completion conflicts. Keep universal instructions short and link workflow details.
2. **Establish a baseline.** Label 20–30 representative OneSet tasks with acceptable routes, required overlays, and mandatory evidence. Include settled specs, missing dependencies, ambiguity, non-code work, persistence, API, UI, and adversarial text. Treat this as a pilot, not enough data to claim production reliability.
3. **Evaluate explicit routing.** Compare simple rules, the coding agent's existing router, and Jev on identical context. Keep tuning and held-out cases separate. Measure route agreement, per-route errors, unnecessary interviews/specs, missed overlays, abstention, latency, cost, and user overrides. Repeat paraphrases and option permutations. Wrongly skipping durability checks is a critical failure even if overall agreement is high.
4. **Run automatic recommendations in shadow mode.** Route only new substantial tasks or meaningful scope changes; maintain the current workflow during ordinary follow-ups. Log sanitized decision metadata locally. Do not call Jev on every message or shell operation.
5. **Enable limited execution only if evidence supports it.** Verify behavior in actual agent sessions: correct skills loaded, acceptance criteria honored, required checks run, no duplicate specs, and authorized completion actions. Retain visible recommendations and easy overrides without adding approval pauses to already authorized routine work.

On missing credentials, timeout, rate limiting, invalid results, or low confidence, apply the deterministic/local agent policy and report that Jev was unavailable or abstained. Continue bounded, well-defined authorized work; ask only for a material unresolved decision. Never silently downgrade a task's required verification. Cache by task/context, catalog/rubric, and model version; invalidate on changed requirements. Jev should improve routing when available while leaving ordinary development functional offline.

Addy's evaluation framework distinguishes structural checks, routing/description collisions, and behavioral checks against actual agent output. This is a useful model for evaluating both the catalog and what the agent does after selection. Routing accuracy alone is insufficient. [Skill eval methodology](https://github.com/addyosmani/agent-skills/blob/main/evals/README.md).

The suggested first deliverable is a reviewed workflow catalog plus a labeled evaluation fixture. A CLI/API bridge can follow; a general orchestration framework and MCP server are unnecessary for the pilot. This recommendation remains conditional on local results: Jev's API fits the decision shape, but its value over the existing router is still unproven.
