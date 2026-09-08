# Operational Concerns — OPM Module Publishing Workflow

> **Stub.** This entry is superseded; its narrative documents were collapsed on 2026-07-29. The PRR-lite answers below described a design that later decisions retired. The full prior text is in git history.

## What this document covered

The five PRR-lite prompts, answered against the design as it stood before D13/D16/D17/D19 reshaped it:

- **Observability** — two new diagnostic surfaces, both replacing a late, hard-to-attribute `module not found` / `no matching transformer` with an early error naming expected versus actual coordinates: a publish-time validation error in the CLI, and a load-time mismatch error from the registry loader in `library`.
- **Semver** — `core`'s `nameSnakeCase` additive and already shipped; `library` and `cli` changes internal or new surface. The only consumer-visible break was migrating non-conforming published module identities.
- **Deprecation** — no definitions or functions removed. What was retired is the *practice* of authoring a registry path independently of identity.
- **Rollback** — every slice individually revertible except the migration, which has persistent effect once identities are republished.
- **Cross-repo order** — core → library → cli → migration, each hand-off being a published artifact or a shared Go helper.

The core sequencing insight outlived the entry and is carried forward: the invariant has to be checked where modules are **consumed**, so the CLI and the operator inherit one implementation from `library` rather than maintaining their own.

## Where it went

- **[0010 — Module and Catalog Identity](../0010/)** — `06-operational.md`
- **[0011 — Module and Catalog Publishing](../0011/)** — `06-operational.md`
