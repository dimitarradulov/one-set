# Catalog publishing

Status: the catalog publication foundation is implemented in [issue #16](https://github.com/dimitarradulov/one-set/issues/16). Compatible editing and correction behavior is covered by [issue #18](https://github.com/dimitarradulov/one-set/issues/18); structural changes and whole-program removal have separate implementation work.

## Agreed scope

- The founder is the only content maintainer for this milestone.
- Author programs and workout templates in readable files. A documented command validates the content, shows the proposed changes, and publishes it to the backend without manual database editing.
- Support initial publication, adding programs, and editing existing content.
- Support removing programs, workout templates, and exercise slots. Removed programs are hidden from new selections; existing followers can continue them and retain their history.
- Removal requires an explicit marker in the content file. Omitting previously published content produces a validation error rather than removing it implicitly.
- Exercise technique, stopping guidance, warmups, and rest guidance are shared wherever an exercise appears. Rep targets and exercise order are prescribed separately in each workout template. The publish preview identifies all programs affected by a shared exercise edit.
- The app downloads published additions and changes from the backend without requiring an App Store release, retaining a local catalog for offline use.
- Video publication is deferred for this milestone.
- Publish complete text prescriptions: exercise order, rep targets, technique instructions, stopping guidance, warmups, and rest durations.
- Template changes apply to future sessions, including within an existing cycle. Started and completed sessions retain their captured content. Offline users continue with cached content until updates can be downloaded.
- Added or removed workout days apply from the user's current training week onward. Completed work and history are preserved; earlier training weeks are not reopened. Removed workout days stop being required.
- Earlier catalog content can be restored and republished, including making a removed program available again. Catalog restoration preserves training records.
- Author content as one YAML file per program and a shared exercise file, tracked in Git. Run a preview command to validate and review changes, then a separate publish command to apply them.
- Check for catalog updates when the app opens or returns to the foreground, without periodic polling. Continue using saved content while checking or offline; active sessions retain their captured content.

This elaborates [FR-26](requirements.md) and the [catalog publication proposal](system-design.md#catalog-publication). The initial content comes from the [program library](HIT_Workout_Program_Library.md). Use the terms in [GLOSSARY.md](../GLOSSARY.md).

## Proposed implementation

- Give programs, workout templates, exercises, and exercise slots stable authoring keys independent of their editable names. Preserve identity across compatible edits; allocate new identity for a different movement or repurposed slot. Translate these keys to database identities without maintaining a per-program deployment configuration.
- Convert the initial ten programs from the library into YAML and generate the bundled fallback from the same reviewed source. Keep program display information and unilateral rep interpretation intact when delivering backend content.
- Validate references, unique keys, exercise order, rep ranges, required text prescriptions, and explicit removals before publication. Show additions, changes, removals, restorations, and affected programs, including those affected by shared exercise edits.
- Preview against the chosen backend environment. Publish exactly the reviewed content; if either the source files or backend catalog changed after preview, require a fresh preview. Apply the complete catalog change in one transaction so failed publication cannot expose partial content. Retrying identical publication should produce no additional changes.
- Keep publication credentials outside the iOS app and separate from ordinary user access. Document local credential setup and environment selection using placeholders.
- Retain removed content and stable historical references. New selection excludes removed programs; restoration and continued access for existing followers use the retained identity.
- Deliver a complete, internally consistent text catalog and replace the local cached catalog atomically after successful validation. Failed or incompatible downloads retain the last usable copy. An installed bundled catalog supplies the initial offline fallback.
- Preserve cycle progress explicitly when workout structure changes, rather than inferring it solely from the edited sequence. Added days must not reopen earlier weeks; removed days must not become outstanding requirements. Started-session content remains usable even if its template is removed while the session is active.
- Correct a bad publication by restoring earlier files and running preview/publish again. This restores catalog content only; it does not roll back user data or undo sessions already performed using the intervening content.

## Implementation acceptance

- Publish the initial ten programs with complete text prescriptions and no required videos.
- Add a program and make it selectable/restorable in the app without an app release or manual database/configuration edits.
- Edit a rep range and shared exercise instructions; the preview identifies affected programs and the app receives the published change.
- Remove and restore a program explicitly; it disappears from new selections while existing followers and history remain supported.
- Remove or add a workout day without rewriting completed work or reopening earlier weeks.
- Reject invalid or accidentally omitted published content before any catalog mutation; a failed transaction leaves the previous catalog intact.
- Reopen the app offline using saved catalog content, and preserve active-session content through a subsequent catalog update.
- Restore earlier source files and republish without changing training records.

## Current implementation

The Worker serves authenticated catalog snapshots with an `ETag`, and the founder's CLI validates YAML, requests a backend preview, and publishes only the reviewed source. Stable authoring keys map catalog entries to persistent database identities. Preview reports program, workout, slot, and shared-exercise changes; shared exercise impact is listed by program name and stable key. The database stores the complete publication snapshot and updates it atomically, while session prescriptions remain captured separately.

For a compatible correction, preserve stable authoring keys, edit the YAML, preview and inspect all reported effects, then publish. To restore an earlier version, use `git restore --source <commit> -- catalog` from `worker/`, preview that source against the current backend, and publish it as a new publication. This changes catalog content only; it does not roll back user settings, cycles, completion records, or captured session prescriptions. See [Worker commands](../worker/README.md) for environment and credential setup.
