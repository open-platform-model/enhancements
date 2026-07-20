# Enhancement 0003 — OPM Module Publishing Workflow

A module's OPM identity (`metadata.modulePath`, `metadata.name`, `metadata.version`) and the CUE registry coordinates it is actually published under (the `cue.mod/module.cue` `module:` path and the CUE package name) are chosen independently today. The two drift, so code holding a loaded `*module.Module` cannot turn it back into an importable registry reference. This enhancement defines a publishing convention — anchored on the new `metadata.nameSnakeCase` field in `core` — that makes a module's registry path derivable from its metadata, plus the `opm publish` workflow (cli) and kernel helpers (library) that enforce and consume it.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

OPM modules carry four coordinates the author sets separately: the metadata identity (`metadata.modulePath` + `metadata.name` + `metadata.version`), the CUE registry module path (the `module:` line in `cue.mod/module.cue`), the CUE package name, and the release tag the artifact is actually published under. Nothing binds them, so they diverge in practice (`zot-registry-ttl` is published at `…/zot_registry_ttl`; `web-app` is published at `…/web-app` but its package is `web_app`; and no module's `metadata.version` is checked against its tag at all — in the `modules` repo the tag comes from a separate `versions.yml`). Any code holding only a `*module.Module` therefore cannot reconstruct the path needed to import it, and cannot trust that its declared version names the artifact in hand.

This enhancement establishes the canonical mapping `registry path = metadata.modulePath / metadata.nameSnakeCase @ vMAJOR(version)`, a matching package-name rule, and the invariant that `metadata.version` equals the artifact's release tag — enforced where modules are **consumed** (a `library` check on the registry acquisition path, which the CLI and the operator inherit together and which no publisher can bypass) and made true by construction where they are **produced** (`opm module publish` derives the coordinates from metadata rather than stamping them into the artifact).

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
- **The version-agreement invariant (D3):** a module's `metadata.version` and the release tag of the artifact carrying it are the same value.
- **Verification at acquire (`library`, D6):** the registry path refuses a module whose metadata disagrees with the coordinates it was fetched by. This is the primary enforcement point, because it is the one no publisher can bypass.
- The `opm module publish` workflow in `cli`: derive a module's `cue.mod/module.cue` `module:` path, CUE package name, and **release tag** from its metadata before pushing (D4 — derive, never stamp into the artifact).
- A `library` helper that computes the canonical import reference from a `*module.Module` (consumed by `synth.Instance` and by the publish command), so the render path resolves imported modules from metadata.
- The migration story for in-repo modules whose published path or version does not yet follow the convention.

### Out of scope

- Changing the meaning of `metadata.modulePath` / `metadata.name` / `metadata.version` — those identity fields are unchanged. D3 binds `metadata.version` to the artifact it ships in; it does not redefine what the field means.
- **Version *selection*** — how a consumer pins or ranges a module version. Distinct from version *agreement*, which is in scope: agreement is "the module is what it says it is," selection is "which one do I want."
- The single-build render mechanism itself (`library`'s `simplify-render-single-build` OpenSpec change); this enhancement supplies the addressing contract that change depends on, not the render rewrite.
- Registry authentication, credentials, signing, and provenance/attestation of published artifacts.
- Catalog publishing (`#Catalog`) — covered by enhancement 0001's catalog repackage; this entry is about `#Module` publishing. Note that `#Catalog` carries the *same* version-agreement exposure (`version!: #VersionType | *"0.0.0-dev"` — a default that can silently ship a placeholder, with catalog FQNs feeding transformer matching). Whether D3/D6 are specified here and implemented there is OQ7.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `core/src/module.cue` | `#Module.metadata.nameSnakeCase` — the canonical identifier this convention builds on (landed 2026-06-17) |
| `core/src/types.cue` | `#SnakeNameType` + `#KebabToSnake` — the snake_case projection helpers |
| `core/SPEC.md` | Normative `#Module` spec; `nameSnakeCase` constraint + rationale |
| `core/src/catalog.cue` | `#Catalog.metadata.version` — the `*"0.0.0-dev"` default carrying the same exposure (OQ7) |
| `library/opm/helper/synth/render.go` | Consumes the canonical import reference when synthesizing a release package; `:62` derives the import's major line from `metadata.version`, which D3 is what makes trustworthy |
| `library/opm/helper/loader/registry/module.go` | Registry module loader — **the D6 enforcement point**: verify the fetched artifact's metadata against the coordinates it was fetched by |
| `library/opm/kernel/wrappers.go` | `AcquireModuleFromRegistry` — the single call both the CLI and the operator reach the registry through |
| `library/opm/module/module.go` | `*module.Module` — where a recorded registry reference would live (OQ3) |
| `cli/pkg/module/module.go` | `CanonicalModuleRef()` — the D1 mapping, already shipped via enhancement 0006 C1; to be reconciled with the library helper |
| `cli/` (publish command) | `opm module publish` — derives the canonical mapping **and the release tag** before push; does not exist today |
| `modules/Taskfile.yml` | The `versions.yml` → `cue mod publish` path that D4 replaces as a source of truth |
| `opm-operator/internal/moduleacquire/acquire.go` | Wraps `AcquireModuleFromRegistry`; inherits D6's refusal without its own implementation |
