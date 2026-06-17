# Design Decisions — OPM Module Publishing Workflow

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it and leave the original in place.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Canonical module registry reference is derived from metadata via `nameSnakeCase`

**Decision:** A module's canonical CUE registry reference is a pure function of its `#Module.metadata`: registry path = `metadata.modulePath + "/" + metadata.nameSnakeCase`, major qualifier = `vMAJOR(metadata.version)`, dep version = `v<version>`, and the module's CUE package name = `metadata.nameSnakeCase`. This mapping is the single normative rule; both the cli publish check and the library import helper mirror it.

**Alternatives considered:**

- Derive the path leaf from `metadata.name` directly (kebab). Rejected: `name` is not a valid CUE identifier when it contains hyphens, so it cannot serve as a package name, and real modules publish under the snake form (zot at `…/zot_registry_ttl`).
- Apply an ad-hoc transform (snake-case) only at the consumption site (library render). Rejected: it is a guess that cannot be guaranteed correct (the registry path lives in `cue.mod`, which the consumer cannot constrain), and it leaves authoring unconstrained so drift persists.

**Rationale:** `nameSnakeCase` is derived from `name` and is identifier-safe, so it can be both the package name and the path leaf without drift. Making the reference a pure function of metadata is what lets a loaded `*module.Module` be re-imported and lets the render path converge the synth and authored paths.

**Source:** User decision 2026-06-17 (combine `nameSnakeCase` with a future publish workflow in library + cli).

### D2: `nameSnakeCase` is added to `core`'s `#Module.metadata` as a derived field

**Decision:** `core` exposes `metadata.nameSnakeCase` on `#Module` — the snake_case projection of `name` (`#KebabToSnake`), validated by `#SnakeNameType`. Derived from `name`; authors never set it.

**Alternatives considered:**

- Compute the snake form in each consumer (library, cli) independently. Rejected: re-implementing `strings.Replace(name, "-", "_")` in N places invites divergence and gives no single authoritative projection.
- Add a free-standing `registryLeaf` identity field authors set by hand. Rejected: another author-set field is exactly the drift source this enhancement removes; a *derived* projection cannot disagree with `name`.

**Rationale:** A schema-level derived projection gives every consumer one deterministic, always-present identifier to build the canonical reference on, and keeps it in lockstep with `name`.

**Source:** User decision 2026-06-17; landed in `core/src/{types,module}.cue` + `core/SPEC.md` the same day.

---

## Open Questions

- **OQ1: Does `opm publish` *enforce* or *generate* the canonical coordinates?** Status: open. Two modes: (a) enforce — read the author's `cue.mod/module.cue` `module:` path and `package` clause and reject the push if they don't match `#CanonicalModuleRef`; (b) generate — synthesize the conformant `cue.mod` from metadata so the author never writes it. Enforce is less magical and keeps authored source authoritative; generate is more ergonomic but hides the path. Could support both (generate with a `--check`-only mode). Resolving this fixes the cli command's contract.

- **OQ2: How is the import qualified when the package name is needed?** Status: open. CUE resolves a bare `import "path@vN"` to the package matching the last path segment. Under D1 the leaf equals `nameSnakeCase` equals the package name, so a bare import should resolve — but this must be verified against the CUE toolchain (does a snake leaf always bind to the same-named package without a `:pkgName` qualifier?). If not always, the library helper must emit `import alias "path@vN:nameSnakeCase"`. Resolving this pins the exact string `render.go` writes.

- **OQ3: Does the library *derive* the reference from metadata or *record* the fetched reference at load?** Status: open. With D1, deriving from metadata is sufficient *if* every consumed module conforms. Recording the exact `modPath@version` the registry loader fetched by (on `*module.Module`) is strictly more robust for non-conforming third-party modules, at the cost of a new field on the module type. The two compose: derive as the rule, record as the safety net + validation input. Resolving this fixes whether `module.go` gains a field.

- **OQ4: How do existing non-conforming in-repo modules migrate?** Status: open. `web-app` (testdata) is published at a hyphenated leaf `…/web-app@v1` with package `web_app` and `metadata.version 0.1.0` (an `@v1`/`0.1.0` mismatch); it must move to `…/web_app@v0`. Are there other workspace modules whose `cue.mod` leaf ≠ `nameSnakeCase`? Migration renames published identities, so it needs an inventory + a hard-switch vs transition-window call. Resolving this fixes the `affects` fixture work and the rollout sequence.

- **OQ5: How does the convention degrade for third-party modules not published via `opm publish`?** Status: open. A module published by hand (or by other tooling) at a path that violates D1 cannot be imported by the metadata-derived reference. Options: hard error at load (the registry loader's verification per OQ3 surfaces a typed mismatch), or best-effort with the recorded fetched reference (OQ3) as fallback. Resolving this fixes the error contract and how strict the ecosystem is about the convention.
