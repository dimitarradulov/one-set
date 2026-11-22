# Sources of truth

Start with [README.md](../../README.md) for current project status and reading order.

| Subject | Source |
| --- | --- |
| Approved product behavior | [Requirements](../requirements.md) |
| Domain terms | [GLOSSARY.md](../../GLOSSARY.md) |
| Workout programs | [Program library](../HIT_Workout_Program_Library.md); the published catalog is authored in [worker/catalog](../../worker/catalog/) |
| Proposed UI | [DESIGN.md](../../DESIGN.md) |
| Proposed implementation | [System design](../system-design.md), [sync and recovery](../sync-and-recovery.md), [API contracts](../api-contracts.md) |
| Database schema and design | [Database notes](../database/README.md), [DBML](../database/oneset.dbml), [migrations](../database/migrations/) |
| On-device storage schema | GRDB migrations in [WorkoutRepository](../../OneSet/Persistence/WorkoutRepository.swift), versioned independently of the Postgres migrations |

Requirements govern product behavior. Keep implementation proposals distinct from approved requirements, and label assumptions needing validation.

Use the terms defined in GLOSSARY.md: a **workout template** prescribes work; a **session** records an attempt.
