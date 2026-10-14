# Domain Docs

## Before exploring

Read [GLOSSARY.md](../../GLOSSARY.md) for OneSet's domain vocabulary and the relevant decisions in [docs/adr/](../adr/). Use the glossary's canonical terms in issues, proposals, code, and tests.

OneSet has a single domain context:

```text
/
├── GLOSSARY.md
└── docs/adr/
    └── 0001-program-removal-preserves-followers.md
```

If a root `GLOSSARY-MAP.md` is introduced, follow it to the glossary for each relevant context and read both system-wide and context-specific ADRs. Proceed with the available documentation when a glossary or ADR directory is absent; create them lazily when a term or decision is resolved.

## When terms or decisions change

Use `/domain-modeling` to sharpen ambiguous terms, stress-test relationships with concrete scenarios, and cross-check claims against the code. Capture resolved terms in `GLOSSARY.md` as they arise, using the [glossary format](../../.agents/skills/domain-modeling/GLOSSARY-FORMAT.md). Keep definitions concise and specific to OneSet's domain; product requirements and implementation decisions belong in their respective documents.

Offer an ADR only when the decision is hard to reverse, surprising without context, and the result of a real trade-off. Use the [ADR format](../../.agents/skills/domain-modeling/ADR-FORMAT.md): a short title and a paragraph recording the context, decision, and reason, with sequential `0001-slug.md` numbering. Add sections only when they help explain the decision.

If a proposal conflicts with an existing ADR, identify the ADR and explain why it should be reconsidered before changing the decision.
