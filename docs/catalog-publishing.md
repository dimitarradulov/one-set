# Catalog publishing

The catalog publication foundation is implemented in [issue #16](https://github.com/dimitarradulov/one-set/issues/16), and compatible editing and correction behavior in [issue #18](https://github.com/dimitarradulov/one-set/issues/18). The founder maintains the text catalog in `worker/catalog/`; structural changes and whole-program removal use the separate catalog maintenance workflow.

## Files and source of truth

- `worker/catalog/programs/01-full-body.yaml` through `10-machine-full-body.yaml` contain display information, workout order, exercise slots, rep ranges, and unilateral scope.
- `worker/catalog/exercises.yaml` contains shared technique, stopping, warmup, rest, and default-rep guidance. An exercise edit applies to every program that uses its key.
- `OneSet/Services/Catalog/BundledProgramCatalog.swift` is generated from these YAML files. Do not edit it by hand.
- `docs/HIT_Workout_Program_Library.md` is the approved content source. Read [the content review register](catalog-content-review.md) for movements without a dedicated technique cue in that source.

Keep program, workout, exercise, and slot keys stable when editing names or compatible prescriptions. A slot's `reps` value is its prescribed target. `scope: each_leg` or `scope: each_side` preserves unilateral interpretation; omit `scope` for ordinary repetitions. Each shared exercise has `default_reps` for use when it is selected as a replacement. Seed defaults are retained; defaults added for newly represented exercises use the most common rep range assigned to that exercise in the ten programs, breaking a tie by the lower minimum.

Rest durations use the source library's rest bands: large compounds use 150–240 seconds, moderate compounds use 120–180 seconds, and isolation exercises use 90–150 seconds. `rest_seconds` selects a value in the appropriate band; the source does not specify per-exercise durations. Global technique, stopping, and warmup language must remain consistent with the approved library. Do not add exercise-specific advice without a reviewed source.

## Local commands

Run commands from `worker/` after installing dependencies with `npm ci` (Node 22 or later):

```sh
# Generate and validate the bundled offline fallback.
npm run catalog -- generate-bundled

# Check that the committed Swift fallback matches the YAML source.
npm run catalog -- generate-bundled --check

# Review and publish against the configured development Worker.
npm run catalog -- preview --environment development --source catalog
npm run catalog -- publish --environment development --source catalog
```

The generator defaults to `worker/catalog` and writes `../OneSet/Services/Catalog/BundledProgramCatalog.swift`. Use `--source <directory>` and `--output <path>` to work with a separate catalog or output location. The preview file `.oneset-catalog-preview.json` is private to the local working tree and should not be committed.

Configure the catalog publisher outside source control, using the publisher secret set on the matching Worker environment:

```sh
export ONESET_CATALOG_API_DEVELOPMENT='https://<worker-host>'
export ONESET_CATALOG_PUBLISH_TOKEN_DEVELOPMENT='<publisher-token>'
```

The publisher token is distinct from user authentication. Preview and publish are separate operations; rerun preview after any source or backend catalog change. Publish only the source captured by the last successful preview. The Worker applies the reviewed catalog transactionally and retries are idempotent. See [Worker commands](../worker/README.md) for environment and credential setup.

## Authoring and correction

Edit YAML while preserving stable keys and explicit workout/slot order. A new movement needs shared text guidance, a rest duration from the applicable source band, and a default rep target. Run `npm run catalog -- generate-bundled`, inspect the generated diff, and run the Worker catalog tests and typecheck before previewing. Review additions, edits, removals, restorations, and every affected program before publishing.

To correct an earlier publication, restore the desired catalog files from Git and publish them as a new publication:

```sh
git restore --source <commit-with-correct-content> -- catalog
npm run catalog -- preview --environment development --source catalog
# Review the preview, then:
npm run catalog -- publish --environment development --source catalog
```

Restoring catalog files changes catalog text only. It does not rewind cycles, preferences, completion records, or prescriptions already captured by sessions. Existing app installs receive published snapshots on their normal refresh and retain their cached copy while offline. Text catalog publication has no video upload requirement.
