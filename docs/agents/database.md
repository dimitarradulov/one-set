# Database changes

- Update the [DBML](../database/oneset.dbml), [design notes](../database/README.md), and a new reviewed [migration](../database/migrations/) together.
- Represent new changes with new migrations; do not edit an already applied migration.
- Use numbered migration filenames, such as `002_description.sql`.
- Use two-space SQL indentation and `snake_case` table and column names.
- Rehearse schema changes against disposable data and document the checks performed.

The database notes record the initial DBML parsing and disposable PostgreSQL/PGlite checks. Their runner is not included in this checkout; consult those notes when preparing schema validation.
