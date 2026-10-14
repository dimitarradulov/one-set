# Catalog publishing

The founder maintains the text catalog in `worker/catalog/`. The ten program identities match the existing app and database authoring keys. Keep the numbered program filenames in the intended catalog order and keep program, workout, and slot keys stable when editing names or prescriptions.

## Files and source of truth

- `worker/catalog/programs/01-full-body.yaml` through `10-machine-full-body.yaml` contain display information, workout order, exercise slots, rep ranges, and unilateral scope.
- `worker/catalog/exercises.yaml` contains shared technique, stopping, warmup, rest, and default-rep guidance. An exercise edit applies to every program that uses its key.
- `OneSet/Services/Catalog/BundledProgramCatalog.swift` is generated from these YAML files. Do not edit it by hand.
- `docs/HIT_Workout_Program_Library.md` is the approved content source. Read [the content review register](catalog-content-review.md) for movements without a dedicated technique cue in that source.

The YAML preserves one definitive exercise per slot. A slot's `reps` value is its prescribed target. `scope: each_leg` or `scope: each_side` preserves unilateral interpretation; omit `scope` for ordinary repetitions. Each shared exercise has `default_reps` for use when that exercise is selected as a replacement. The current seed defaults are retained; defaults added for newly represented exercises use the most common rep range assigned to that exercise in the ten programs, breaking a tie by the lower minimum.

Rest durations use the source library's rest bands: large compounds use 150–240 seconds, moderate compounds use 120–180 seconds, and isolation exercises use 90–150 seconds. `rest_seconds` selects a value in the appropriate band; the source does not specify per-exercise durations. Global technique, stopping, and warmup language must remain consistent with the approved library. Do not add exercise-specific advice without a reviewed source.

## Local commands

Run from `worker/` after installing dependencies with `npm ci` (Node 22 or later):

```sh
# Validate the complete authoring source and publish a fresh local fallback.
npm run catalog -- generate-bundled

# Check that the committed Swift fallback matches the YAML source.
npm run catalog -- generate-bundled --check

# Review proposed changes against a configured backend environment.
npm run catalog -- preview --environment development

# Publish the exact source and environment captured by the last successful preview.
npm run catalog -- publish --environment development
```

The command defaults to `worker/catalog` and writes `../OneSet/Services/Catalog/BundledProgramCatalog.swift`. Use `--source <directory>` and `--output <path>` to work with a separate catalog or output location. Preview writes `.oneset-catalog-preview.json` in the current directory; do not commit this review artifact.

Configure each environment outside source control:

```sh
export ONESET_CATALOG_API_DEVELOPMENT='https://<worker-host>'
export ONESET_CATALOG_PUBLISH_TOKEN_DEVELOPMENT='<publisher-token>'
```

Use separate API URLs and publisher tokens for development and production. The publisher token is distinct from user authentication. Preview and publish are separate operations; preview again after any source or backend catalog change. The publisher applies the reviewed catalog transactionally and retries are idempotent.

## Adding or editing content

1. Read the approved program library and content review register.
2. Edit the relevant YAML, preserving stable keys and explicit workout/slot positions. A new movement needs shared text guidance, a rest duration from the applicable source band, and a default rep target.
3. Run `npm run catalog -- generate-bundled`, inspect the generated diff, then run the full Worker catalog tests and typecheck.
4. Configure the intended backend environment and run `preview`. Review additions, edits, removals, restorations, and all affected programs.
5. Run `publish` for that environment. Do not change files between preview and publish.

To remove published content, keep the item in YAML and set `removed: true`; omission is rejected by backend preview. To restore it, remove the marker and preview/publish again. Do not delete or recreate program identities: existing account setup and cycles refer to them. Text catalog publication has no video upload requirement.
