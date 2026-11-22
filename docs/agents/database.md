# Database changes

- Update the [DBML](../database/oneset.dbml), [design notes](../database/README.md), and a new reviewed [migration](../database/migrations/) together.
- Represent new changes with new migrations; do not edit an already applied migration.
- Use numbered migration filenames, such as `002_description.sql`.
- Use two-space SQL indentation and `snake_case` table and column names.
- Rehearse schema changes against disposable data and document the checks performed.

The database notes record the initial DBML parsing and disposable PostgreSQL/PGlite checks; that original standalone runner is not in this checkout. Current schema behavior is exercised by PGlite suites that replay the checked-in migrations: `npm --prefix worker test` (for example [progress tests](../../worker/tests/progress.test.ts)) and `npm --prefix admin test` ([dashboard integration](../../admin/tests/dashboard.integration.test.ts)). Load a new migration in those fixtures when it changes behavior they cover.
