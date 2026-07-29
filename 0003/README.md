# Enhancement 0003 — OPM Module Publishing Workflow

> **Superseded by 0010 (2026-07-26), together with 0011.** This entry accumulated four problems on one id — a naming convention, version agreement, whether a version belongs in identity at all, and how identity reaches an artifact — and its narrative documents stopped tracking its decision log along the way, so `02-design.md` still describes a design that later decisions retired. The work continues, split along the boundary that was always there: **[0010 — Module and Catalog Identity](../0010/)** owns what an artifact's identity *is* and how it gets into the artifact's own bytes (a breaking `core` change), and **[0011 — Module and Catalog Publishing](../0011/)** owns the commands that write it and the registry it goes to (a `cli` feature that depends on 0010). Both successors start fresh decision logs at D1 carrying only current answers, and they restate this entry's measurements inline rather than referencing them — so neither requires reading this one. What stays here is the record of how the design arrived where it did, plus `experiments/` and `research/`, which are the expensive part and the reason this entry was superseded rather than deleted. Read it as history, not as a live design.

> **Compacted 2026-07-29.** The narrative documents (`01`, `02`, `04`, `05`, `06`) were collapsed to stubs describing what each covered and where it went, and the Open Questions block was reduced to one line per question naming the successor that inherited it. The decision log keeps every number, decision, and *Alternatives considered*, with supersessions now marked in place so it is safe to read linearly. Two things were deliberately kept in full: `05-risks.md`'s per-site **Blast Radius** audit, which was measured against real code and is reproduced nowhere else, and everything under `experiments/` and `research/`. The prior text of every collapsed document is in git history.

A module's OPM identity (`metadata.modulePath`, `metadata.name`, `metadata.version`) and the CUE registry coordinates it is actually published under (the `cue.mod/module.cue` `module:` path and the CUE package name) are chosen independently today. The two drift, so code holding a loaded `*module.Module` cannot turn it back into an importable registry reference. This enhancement defines a publishing convention — anchored on the new `metadata.nameSnakeCase` field in `core` — that makes a module's registry path derivable from its metadata, plus the `opm publish` workflow (cli) and kernel helpers (library) that enforce and consume it.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

OPM modules carry four coordinates the author sets separately: the metadata identity (`metadata.modulePath` + `metadata.name` + `metadata.version`), the CUE registry module path (the `module:` line in `cue.mod/module.cue`), the CUE package name, and the release tag the artifact is actually published under. Nothing binds them, so they diverge in practice (`zot-registry-ttl` is published at `…/zot_registry_ttl`; `web-app` is published at `…/web-app` but its package is `web_app`; and no module's `metadata.version` is checked against its tag at all — in the `modules` repo the tag comes from a separate `versions.yml`). Any code holding only a `*module.Module` therefore cannot reconstruct the path needed to import it, and cannot trust that its declared version names the artifact in hand.

This enhancement establishes the canonical mapping `registry path = metadata.modulePath / metadata.nameSnakeCase @ vMAJOR(version)`, a matching package-name rule, and the invariant that `metadata.version` equals the artifact's release tag — enforced where modules are **consumed** (a `library` check on the registry acquisition path, which the CLI and the operator inherit together and which no publisher can bypass) and made true by construction where they are **produced** (`opm module publish` derives the coordinates from metadata rather than stamping them into the artifact).

`#Catalog` publishes through the same pipeline (D7). Catalogs are the degenerate case on the addressing axis — no `name`, so the registry path *is* `metadata.modulePath` — and the acute case on the version axis, because `version!` carries a `*"0.0.0-dev"` default and every transformer FQN in the catalog inherits whatever it says. Their acquire point is subscription resolution in `library/opm/materialize` rather than `AcquireModuleFromRegistry`: two artifact types, two fetch paths, one invariant. D9 settles where published artifacts live — a central registry that hosts rather than indexes, with owner-scoped module paths (`opmodel.dev/m/<owner>/<name>`) beneath reserved namespace segments — and D8 settles what publish does when the author's dependency graph was locally overridden: report it, never honour it, and refuse without an explicit flag.

## Documents

The six split documents below are mandatory and always present. All but `03-decisions.md` are stubs after the 2026-07-29 compaction.

1. [01-problem.md](01-problem.md) — *Stub.* Identity and registry coordinates drift; the measurements that gave the entry its urgency, restated in both successors
2. [02-design.md](02-design.md) — *Stub.* Canonical `modulePath/nameSnakeCase` mapping — and why it stopped being accurate before supersession
3. [03-decisions.md](03-decisions.md) — **Kept in full.** D1–D27 with alternatives, supersessions marked in place; Open Questions collapsed to successor pointers
4. [04-graduation.md](04-graduation.md) — *Stub.* Gates that were never met
5. [05-risks.md](05-risks.md) — *Partly kept.* Risk narrative stubbed; the per-site **Blast Radius** audit retained in full
6. [06-operational.md](06-operational.md) — *Stub.* PRR-lite answers against the retired design

Pure-CUE schema definitions live in [`schemas/`](schemas/) as compilable files.

## Scope

### In scope

- The canonical mapping from a module's `metadata` to its CUE registry reference (path leaf, package name, version + major), anchored on `core`'s `metadata.nameSnakeCase`.
- **Removing `#Module.metadata.version` (D13):** module source declares no version; the full version exists only as the artifact coordinate, with the major carried in the CUE module path as CUE and Go both do. `metadata.fqn` is redesigned around its absence (shape open — OQ15). This supersedes the version-agreement machinery below for modules and makes `core` identity semantics part of this entry's scope. Per-site consequences: `05-risks.md ## Blast Radius`.
- ~~**The version-agreement invariant (D3):** a module's `metadata.version` and the release tag of the artifact carrying it are the same value.~~ Retired for modules by D13; still live for `#Catalog` pending OQ13.
- **Verification at acquire (`library`, D6):** the registry path refuses a module whose metadata disagrees with the coordinates it was fetched by. This is the primary enforcement point, because it is the one no publisher can bypass.
- The `opm module publish` workflow in `cli`: derive a module's `cue.mod/module.cue` `module:` path, CUE package name, and **release tag** from its metadata before pushing (D4 — derive, never stamp into the artifact).
- **`opm module version set` (D12):** version authoring as a command separate from publishing, and the only writer of `metadata.version`. Publish takes no version input at all, so source and tag have no surface on which to be made to disagree.
- **`opm catalog publish` (D7):** the same pipeline for `#Catalog`, extending D3 and D6 to catalogs. One implementation, two artifact types.
- **The local-override gate at publish (D8):** `cue.mod/local-module.cue` replacements are never honoured by publish, and their presence blocks the push unless explicitly allowed.
- A `library` helper that computes the canonical import reference from a `*module.Module` (consumed by `synth.Instance` and by the publish command), so the render path resolves imported modules from metadata.
- **Where published artifacts live (D9):** a central registry that hosts rather than indexes, with owner-scoped module paths (`opmodel.dev/m/<owner>/<name>`) under reserved namespace segments that keep module space, catalog space, and schema space distinguishable by path alone.
- The migration story for in-repo modules whose published path or version does not yet follow the convention — now universal rather than exceptional, since D9 moves every currently-published module (OQ9).

### Out of scope

- Changing the meaning of `metadata.modulePath` / `metadata.name` / `metadata.version` — those identity fields are unchanged. D3 binds `metadata.version` to the artifact it ships in; it does not redefine what the field means.
- **Version *selection*** — how a consumer pins or ranges a module version. Distinct from version *agreement*, which is in scope: agreement is "the module is what it says it is," selection is "which one do I want."
- The single-build render mechanism itself (`library`'s `simplify-render-single-build` OpenSpec change); this enhancement supplies the addressing contract that change depends on, not the render rewrite.
- Signing and provenance/attestation of published artifacts. Registry **authentication** was also excluded when this entry was only a naming convention, but D9 makes the central registry the write target for `opm module publish`, and the CLI has no credential surface today — the tension is recorded as OQ11 and must be answered before this entry can be promoted.
- Module **discovery** — search, listing, and any index over what is published. It rests on this enhancement's addressing guarantees (D1's mapping is reversible, D3 makes the version trustworthy) but is a separate concern with its own entry.
- The CLI's platform-resolution modes — synthesizing a `#Platform` from a module's catalog dependencies, and honouring `local-module.cue` replacements during development. Adjacent to D8 through the same file, but a rendering concern rather than a publishing one.
- The `#Catalog` *repackage* itself (catalog composition, subscription filters, materialization) — enhancement 0001 owns that and is `implemented`. Catalog **publishing** moved in scope here per D7, because it is the module-publishing pipeline with a different artifact type; `#Catalog` carries the same version-agreement exposure (`version!: #VersionType | *"0.0.0-dev"` — a default that can silently ship a placeholder, with catalog FQNs feeding transformer matching), so D3 and D6 extend to it unchanged.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `core/src/module.cue` | `#Module.metadata.nameSnakeCase` — the canonical identifier this convention builds on (landed 2026-06-17) |
| `core/src/types.cue` | `#SnakeNameType` + `#KebabToSnake` — the snake_case projection helpers |
| `core/SPEC.md` | Normative `#Module` spec; `nameSnakeCase` constraint + rationale |
| `core/src/catalog.cue` | `#Catalog.metadata` — no `name` field, and the `*"0.0.0-dev"` version default D7 brings under the invariant; also records the `identity/version_override.cue` stamping convention (OQ13) |
| `core/src/resource.cue`, `core/src/trait.cue` | Primitive FQNs whose `modulePath` is unrelated to the owning catalog's — the reverse-lookup gap (OQ10) |
| `library/opm/materialize/enumerate.go` | Subscription version enumeration — **the catalog-side D6 enforcement point**: compare the pulled `#Catalog.metadata.version` against the resolved tag |
| `cli/pkg/loader/provenance.go` | `HasLocalModuleReplacement` — the `local-module.cue` detector D8's publish gate reuses (shipped as render provenance in 0006 D7) |
| `cli/` (catalog publish command) | `opm catalog publish` — same pipeline as `opm module publish`, different artifact type (D7); does not exist today |
| `library/opm/helper/synth/render.go` | Consumes the canonical import reference when synthesizing a release package; `:62` derives the import's major line from `metadata.version`, which D3 is what makes trustworthy |
| `library/opm/helper/loader/registry/module.go` | Registry module loader — **the D6 enforcement point**: verify the fetched artifact's metadata against the coordinates it was fetched by |
| `library/opm/kernel/wrappers.go` | `AcquireModuleFromRegistry` — the single call both the CLI and the operator reach the registry through |
| `library/opm/module/module.go` | `*module.Module` — where a recorded registry reference would live (OQ3) |
| `cli/pkg/module/module.go` | `CanonicalModuleRef()` — the D1 mapping, already shipped via enhancement 0006 C1; to be reconciled with the library helper |
| `cli/` (publish command) | `opm module publish` — derives the canonical mapping **and the release tag** before push; does not exist today |
| `modules/Taskfile.yml` | The `versions.yml` → `cue mod publish` path that D4 replaces as a source of truth |
| `opm-operator/internal/moduleacquire/acquire.go` | Wraps `AcquireModuleFromRegistry`; inherits D6's refusal without its own implementation |
