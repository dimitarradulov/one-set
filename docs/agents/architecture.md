# iOS architecture

OneSet uses native SwiftUI with feature-level observable models, domain values, and injected repositories/services. This is lightweight MVVM: one model coordinates a workflow that can span multiple screens. The [architecture research](../swiftui-architecture-research.md) records the alternatives and rationale. [Requirements](../requirements.md) govern behavior; [system design](../system-design.md) and [sync and recovery](../sync-and-recovery.md) define the proposed storage and service design.

## Placement and dependency direction

| Location | Responsibility |
| --- | --- |
| `OneSet/App` | Compose concrete dependencies, own feature lifetimes, interpret development launch routes |
| `OneSet/Features/<Feature>` | SwiftUI screens/components, typed routes, observable workflow models |
| `OneSet/Domain` | Value types, stable identities, pure training rules; independent of SwiftUI and service SDKs |
| `OneSet/Services` | Catalog, identity/access, media, networking, analytics and other capability adapters |
| `OneSet/DesignSystem` | Shared colors, typography, branding and visual modifiers |
| `OneSet/Persistence` and `OneSet/Sync` when implemented | Durable repositories/migrations and upload/retry coordination |

Views call feature models; models use domain values and injected capabilities. Repositories and services remain independent of presentation. Organize new types into individual files within the existing app target. Introduce a package or protocol when a concrete dependency boundary or substitution needs it.

## State ownership and injection

- Mark presentation models `@MainActor @Observable`. Own them once with private `@State` at the app or feature root; pass them explicitly to descendants and use `@Bindable` for editable state.
- Keep focus, expansion and other temporary view state in the owning view. Give small components values, bindings and action closures; add a model when they coordinate a workflow.
- Put navigation actions, selection, validation, asynchronous command coordination and visible errors in the feature model. Store lightweight IDs in typed routes and resolve records through the injected catalog/repository.
- Construct live dependencies at the app boundary. Supply preview or replacement data through initializers. Views and domain types obtain no dependencies from global singleton lookups.
- Use value structs/enums for domain data and `Sendable` snapshots/commands across concurrency boundaries. Use explicit actor isolation for shared mutable state.

The implemented example is [OnboardingModel](../../OneSet/Features/Onboarding/OnboardingModel.swift), owned by [OneSetApp](../../OneSet/App/OneSetApp.swift) and consumed by [OnboardingFlowView](../../OneSet/Features/Onboarding/OnboardingFlowView.swift). The injected [ProgramCatalog](../../OneSet/Services/Catalog/ProgramCatalog.swift) is an immutable bundled catalog; preferences and selection currently last for the app process. Account, workout storage and sync are future features.

## Durable workout commands

When implementing training, make the local repository the source of truth for session records. GRDB is the preferred SQLite access library, subject to the compatibility and durability checks in the research; the app currently has no database dependency.

- Commit session changes, rest deadlines and pending server operations together in a synchronous database transaction. Show successful-save/completion state only after commit; retain input and expose failure when storage fails.
- Own active-session coordination and pending operations beyond a screen's lifetime. Reconstruct sessions from durable data after restart. View task cancellation or navigation must not discard the only save path.
- Run uploads and refresh through a separate sync engine. Preserve sent payloads/base revisions, serialize session uploads, and protect newer edits from delayed acknowledgments/refreshes using operation identity and revision/generation checks.
- Actor isolation protects state access, but `await` permits interleaving. Explicitly order dependent commands and recheck assumptions after suspension; keep atomic database work free of suspension.
- Scope user data by account and retain pending work during account transitions. Keep authentication, media and analytics outside local training transactions; use the specified access rules for new starts and uninterrupted active training.
- Version local migrations independently from API/server schemas. Preserve drafts, captured prescriptions and pending payloads through upgrades. Surface migration failures without deleting the user's store.

For each new durable workflow, verify save failure, restart recovery, retry identity, stale responses, account isolation and migration of pending work. Follow [validation](validation.md) for repository checks and simulator inspection.
