---
name: hit-program-designer
description: Design a new OneSet HIT program from a goal the user describes (for example "athletic sprinter look, 3 days, machines"), get approval, then author it into worker/catalog and publish it to the development catalog with the catalog CLI. Use when the user asks to create, generate, or design a new program or routine for the catalog.
---

# HIT program designer

Turn a described goal into a OneSet program that follows the house rules, show it for approval, then author, validate, publish and commit it. Use the glossary's terms: a **program** contains **workout templates**, which contain **exercise slots**, each with a **prescription**.

There are two approval gates. Never skip either one, and never treat an earlier approval as covering the next gate.

1. **Design approval:** before any file is written.
2. **Publish approval:** after the preview output is shown, before `publish` runs.

## 1. Intake

Read the user's description and collect anything missing in **one** round of questions, each with a recommended default:

| Input | Default if unstated |
| --- | --- |
| Goal or look | Required: ask. |
| Days per week | 3 |
| Equipment profile | Mixed gym (machines plus free weights) |
| Session length | 35-45 min |
| Priority or excluded muscles, injuries | None |
| Program name | Propose one: plain, descriptive, two or three words, not a trademark or a person's name. |

If the user already gave enough to proceed, skip the questions and say which defaults you used.

## 2. Load context

From the repository root:

```sh
node .agents/skills/hit-program-designer/scripts/catalog-overview.mjs
```

This prints every program with its active slots, rep ranges, supersets and parity, plus every exercise with its key, default reps, rest and use count, the banners in use, and the next program file number.

Then read:

- [references/hit-principles.md](references/hit-principles.md): lineage, house rules, design heuristics and goal mapping.
- The "Global Training Rules" section of [the program library](../../../docs/HIT_Workout_Program_Library.md).
- [Catalog publishing](../../../docs/catalog-publishing.md), if you haven't already this session.

## 3. Draft the program

Present the design in chat, not in files:

1. **Goal mapping:** primary, secondary and maintenance muscles, plus one sentence on what the program will not deliver (for example, a look but not sport performance).
2. **Program header:** name, proposed key (`kebab-case`, unique), `format`, `emphasis` (one sentence, styled like the existing "Best for" and "Visual goal" lines) and suggested weekly layout. Keep `recommended_weeks: 8`: the catalog tests pin it.
3. **One table per workout template:** order, exercise, reps, TF/MMF and superset pairing. Give each workout a name and a banner from the banners in use (`arms`, `back-pull`, `chest-push`, `general-gym`, `lower-body`, `shoulders`, `upper-body`). A new banner needs app artwork, so don't introduce one.
4. **Self-check:**
   - A table of weekly direct working sets per muscle group, showing that priorities get the most.
   - Working sets per session, within the bounds in the reference.
   - No duplicate slot within a workout.
   - Every superset is a valid adjacent pre-exhaust pair.
   - Calves and trunk are covered.
   - The **closest existing program** and how this one differs. If it overlaps too much, recommend editing that program instead and stop.
5. **New exercises:** prefer existing exercises. When a new one is truly needed, list it with its proposed key, name, default reps, rest band, TF/MMF and an existing-exercise fallback. Say plainly that it will publish without a video and will be added to the content review register.

Ask for design approval. Iterate until the user explicitly approves. Only a clear yes to this design counts.

## 4. Author

1. **Branch:** start from an up-to-date `main` with `git fetch origin && git status`. If the checkout has unrelated uncommitted changes, create a sibling worktree per [Git workflow](../../../docs/agents/git-workflow.md). Otherwise create `claude/program-<key>` from `origin/main`. Dashboard publications commit to `main`, so starting behind it makes the preview show unrelated changes.
2. **Program file:** create `worker/catalog/programs/<NN>-<key>.yaml`.
   - Mirror the structure of [11-hit-upper-lower-rotation.yaml](../../../worker/catalog/programs/11-hit-upper-lower-rotation.yaml).
   - Workout keys are `<program-key>-<workout-slug>`.
   - Slot keys are `<workout-key>-<exercise-key>`.
   - Positions start at 1.
   - Reps use `reps: {minimum: N, maximum: M}`.
   - Use `scope: each_leg` or `scope: each_side` for unilateral slots.
   - Superset pairs use slot keys.
   - Use a slot `stopping_guidance` only when the prescription differs from the exercise default.
3. **New exercises:** append them to `worker/catalog/exercises.yaml` in alphabetical key order.
   - Copy the shared `instructions` and `warmup_guidance` text from an existing exercise of the same kind.
   - Use the matching standard `stopping_guidance`: the MMF sentence ("Continue until you cannot complete another full rep...") or the TF sentence ("Stop when you cannot complete another rep without losing position...").
   - Pick `rest_seconds` from the band in the reference and set `default_reps`.
   - Do not write movement-specific technique claims.
   - Add the exercise name to the list in [catalog content review](../../../docs/catalog-content-review.md) and update its count.
4. **Library document:** in [the program library](../../../docs/HIT_Workout_Program_Library.md):
   - Add a row to the Program Selection Guide.
   - Add an unnumbered `# <Program name>` section at the end, like the HIT Upper / Lower Rotation, with frequency, emphasis and the workout tables. The numbered `# N. Name` headings are pinned by tests to the original ten.
   - Follow [documentation conventions](../../../docs/agents/documentation.md) and avoid em dashes.
5. **Generate and test,** from `worker/`:

   ```sh
   npm ci                      # only if node_modules is missing
   npm run catalog -- generate-bundled
   npm run typecheck
   npm test
   ```

   The catalog tests pin counts. Update only the assertions the new content changes:
   - In `worker/tests/catalog-source.test.ts`: add the program key and its active slot count to `expectedCounts`, update the total workout count, and update the exercise count if exercises were added.
   - In `worker/tests/catalog-e2e.test.ts`: update the program count and the exercise count.

   Rerun until everything passes. Inspect `git diff` for unrelated changes and run `git diff --check`.

## 5. Preview

Publish to **development** only. Production is used only if the user explicitly names it in this conversation, and its Worker may not be deployed yet; see the production section in [worker/README.md](../../../worker/README.md).

The publisher needs `ONESET_CATALOG_API_DEVELOPMENT` and `ONESET_CATALOG_PUBLISH_TOKEN_DEVELOPMENT` in the environment. Check that they are set without printing their values:

```sh
test -n "$ONESET_CATALOG_API_DEVELOPMENT" && test -n "$ONESET_CATALOG_PUBLISH_TOKEN_DEVELOPMENT" && echo set
```

If they're missing, tell the user to export them in their shell (placeholders are in [catalog publishing](../../../docs/catalog-publishing.md)). Never ask for the token in chat, never write it to a file, and never echo it. Then stop until they confirm.

From `worker/`:

```sh
npm run catalog -- preview --environment development --source catalog
```

**Guard:** every listed change must be one of `add program`, `add workout`, `add exercise slot`, `add superset` for the new program's key, or `add shared exercise` for an approved new exercise. If anything else appears (an `update`, a `remove`, a `restore`, or changes to another program), the repository is out of sync with the published catalog. Stop, show the unexpected lines, and tell the user to pull the latest `main`. Do not publish.

## 6. Publish

Show the user the preview's change list and affected programs, then ask: publish this program to the development catalog? Wait for an explicit yes. Publishing makes the program visible to every app user of that environment.

```sh
npm run catalog -- publish --environment development --source catalog
```

After `Published catalog to development: <publication-id>`:

1. Write `worker/catalog/.publication.json` as `{"publication_id": "<publication-id>", "source_fingerprint": "<source_fingerprint from worker/.oneset-catalog-preview.json>"}`, pretty-printed with two-space indentation and a trailing newline, matching the existing marker.
2. Run `npm run catalog -- generate-bundled --check` to confirm the bundled fallback matches.
3. Never commit `worker/.oneset-catalog-preview.json`. It is gitignored.

If publish fails with a stale preview, rerun preview, reapply the guard and ask again.

## 7. Commit and report

Stage explicit paths only:

- the program YAML
- `exercises.yaml` (if changed)
- `.publication.json`
- `OneSet/Services/Catalog/BundledProgramCatalog.swift`
- the library document
- the content review register (if changed)
- the two test files

Commit on the task branch with a message describing the new program and the attribution line from the current conversation instructions. Ask before pushing or opening a pull request. Merge promptly: the published catalog already contains this program, so the next dashboard publication will commit it to `main` anyway, and an unmerged branch would then conflict.

Report:

- the program key and file
- the publication ID and environment
- any new exercises that still need a video and a technique cue
- the checks that ran and their results
- the branch and commit, and whether anything was pushed

If the user rejects the design at any point, leave no files behind.
