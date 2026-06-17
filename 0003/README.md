# Enhancement 0003 — OPM Module Publishing Workflow

A module's OPM identity (`metadata.modulePath`, `metadata.name`, `metadata.version`) and the CUE registry coordinates it is actually published under (the `cue.mod/module.cue` `module:` path and the CUE package name) are chosen independently today. The two drift, so code holding a loaded `*module.Module` cannot turn it back into an importable registry reference. This enhancement defines a publishing convention — anchored on the new `metadata.nameSnakeCase` field in `core` — that makes a module's registry path derivable from its metadata, plus the `opm publish` workflow (cli) and kernel helpers (library) that enforce and consume it.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

OPM modules carry three names the author sets separately: the metadata identity (`metadata.modulePath` + `metadata.name`, kebab-case), the CUE registry module path (the `module:` line in `cue.mod/module.cue`), and the CUE package name. Nothing binds them, so they diverge in practice (`zot-registry-ttl` is published at `…/zot_registry_ttl`; `web-app` is published at `…/web-app` but its package is `web_app`; `metallb` aligns all three). Any code holding only a `*module.Module` therefore cannot reconstruct the path needed to import that module — which the single-build render path (`library`'s `simplify-render-single-build`) now requires. This enhancement establishes the canonical mapping `registry path = metadata.modulePath / metadata.nameSnakeCase @ vMAJOR(version)`, a matching package-name rule, and the publish-time enforcement (cli) plus metadata-derived resolution (library) that make a module resolvable from its metadata alone.

## Documents

The six split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md) — Module identity and registry coordinates drift; the import path is not recoverable from a loaded module
2. [02-design.md](02-design.md) — Canonical `modulePath/nameSnakeCase` mapping, enforced at publish and consumed by the kernel
3. [03-decisions.md](03-decisions.md) — Append-only decision log + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable files.

## Scope

### In scope

- The canonical mapping from a module's `metadata` to its CUE registry reference (path leaf, package name, version + major), anchored on `core`'s `metadata.nameSnakeCase`.
- The `opm publish` workflow in `cli`: validate (and/or generate) a module's `cue.mod/module.cue` `module:` path and CUE package name against the canonical mapping before pushing to a registry.
- A `library` helper that computes the canonical import reference from a `*module.Module` (consumed by `synth.Release` and by the publish command), so the render path resolves imported modules from metadata.
- The migration story for in-repo modules whose published path does not yet follow the convention.

### Out of scope

- Changing the meaning of `metadata.modulePath` / `metadata.name` / `metadata.version` — those identity fields are unchanged.
- The single-build render mechanism itself (`library`'s `simplify-render-single-build` OpenSpec change); this enhancement supplies the addressing contract that change depends on, not the render rewrite.
- Registry authentication, credentials, signing, and provenance/attestation of published artifacts.
- SemVer / version-selection policy for modules (how a consumer pins or ranges a module version).
- Catalog publishing (`#Catalog`) — covered by enhancement 0001's catalog repackage; this entry is about `#Module` publishing.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `core/src/module.cue` | `#Module.metadata.nameSnakeCase` — the canonical identifier this convention builds on (landed 2026-06-17) |
| `core/src/types.cue` | `#SnakeNameType` + `#KebabToSnake` — the snake_case projection helpers |
| `core/SPEC.md` | Normative `#Module` spec; `nameSnakeCase` constraint + rationale |
| `library/opm/helper/synth/render.go` | Consumes the canonical import reference when synthesizing a release package |
| `library/opm/helper/loader/registry/module.go` | Registry module loader; candidate site to record/validate the canonical reference at load |
| `library/opm/module/module.go` | `*module.Module` — where a recorded registry reference would live |
| `cli/` (publish command) | `opm publish` — the workflow that enforces / derives the canonical mapping before push |
