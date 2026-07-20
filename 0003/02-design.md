# Design — OPM Module Publishing Workflow

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- Given a module's `metadata` alone, the canonical CUE registry reference (path, package name, version, major) is **deterministically derivable** — no guessing, no per-transform special cases.
- A module's declared `metadata.version` and the version of the artifact carrying it are **the same value**, so `metadata` can be trusted as a statement about the artifact in hand rather than about the author's intent at some earlier time.
- The convention is **verified where modules are consumed**, not only where they are produced, so it holds for every module regardless of how it was published.
- A module's registry coordinates are **derived at publish time** (cli), so a conformant module is the default outcome rather than something the author has to get right by hand.
- The kernel (library) computes the canonical reference from a `*module.Module` and uses it to import the module in the single-build render path, so the synthesized-CR and authored-`instance.cue` paths converge.
- The convention unifies the three names: `metadata.nameSnakeCase` is simultaneously the registry-path leaf and the CUE package name, collapsing the "three independent spellings" problem to "one identity, one canonical projection."
- Existing in-repo modules migrate to the convention with a clear, mechanical path; non-conforming third-party modules degrade with a legible error rather than a silent wrong-address fetch.

## Non-Goals

- Redefining `metadata.modulePath` / `metadata.name` / `metadata.version`. Identity semantics are unchanged; this enhancement adds a *projection* and a *publishing rule*, not a new identity.
- Implementing the single-build render rewrite (`library`'s `simplify-render-single-build`). This enhancement is the addressing contract that change consumes.
- Registry auth, signing, provenance, or attestation.
- Module version-selection / pinning policy for consumers.
- `#Catalog` publishing (enhancement 0001 owns the catalog repackage).

## High-Level Approach

Anchor the convention on a single canonical identifier and enforce it where modules are produced, then consume it where modules are imported.

1. **Canonical identifier (core, landed).** `core`'s `#Module.metadata` now carries `nameSnakeCase` — the snake_case projection of `name` (`#KebabToSnake`, validated by `#SnakeNameType`). It is CUE-identifier-safe, so it can serve as both a CUE package name and a registry-path leaf. It is derived from `name`, so it cannot drift from identity.

2. **Canonical reference mapping (this enhancement).** Define the module's registry reference as a pure function of metadata:
   - registry path = `metadata.modulePath + "/" + metadata.nameSnakeCase`
   - major qualifier = `vMAJOR(metadata.version)` (e.g. `0.1.0` → `v0`)
   - import path = `<registry path>@<major>`; dep version = `v<version>`
   - CUE package name = `metadata.nameSnakeCase`

3. **Version agreement (this enhancement, D3).** `metadata.version` and the artifact's release tag are the same value. `schemas/target.cue` states this as `#PublishedModuleRef`, which unifies the derived `depVersion` with the artifact coordinates actually in hand — so a mismatched pair is a type error, not a tolerated disagreement.

4. **Verification at acquire (library) — the primary enforcement point.** The registry loader checks the fetched artifact's metadata against the coordinates it was fetched by, and refuses on mismatch with both values named. This is the guarantee that cannot be bypassed: it holds for modules published by `cue mod publish`, by other tooling, or before this enhancement existed, and the CLI and operator inherit it together because both reach the registry through `kernel.AcquireModuleFromRegistry`.

5. **Derivation at publish (cli).** `opm module publish` reads `metadata` and derives *both* the registry path and the release tag from it, so a conformant artifact is produced by construction. This removes `versions.yml` as a competing source of truth: the module file becomes the single place a version is declared.

6. **Kernel consumption (library).** A helper computes the canonical reference from a `*module.Module` (reading `metadata.modulePath`, `metadata.nameSnakeCase`, `metadata.version`). `synth.Instance` uses it to write the `import` and the synthesized `cue.mod` dependency, replacing the unreconstructable `modulePath/name` guess.

The relationship between the names becomes: one identity (`name` + `version`) → one canonical projection (`nameSnakeCase`, `vMAJOR`) → one registry leaf, one package name, one release tag. Publish makes conformance the default; **acquire makes it a guarantee**.

### Why verification at acquire rather than only at publish

An earlier revision of this design put enforcement solely at publish, treating load-time verification as optional. That is not sufficient, for a reason that is structural rather than incidental: `cue mod publish` exists, will keep working, and every module published to date used it. Enforcement that a publisher can route around does not give a *consumer* anything to rely on — and it is the consumer (the render path, the handoff verification, the operator's reconcile) that suffers when the invariant is false.

Publish-side derivation is still worth building; it is what makes the invariant true going forward and removes a class of author error. But it is the ergonomic half, not the guarantee.

## Schema / API Surface

Two shapes in [`schemas/target.cue`](schemas/target.cue):

- **`#CanonicalModuleRef`** — a pure function from `#Module.metadata` to `{registryPath, packageName, major, importPath, depVersion}`. The single normative source both the cli publish command and the library helper mirror.
- **`#PublishedModuleRef`** — the same reference bound to the artifact coordinates in hand (`artifactPath`, `artifactVersion`), with the D3 invariant expressed as unification. A publisher unifies the tag it is about to write; a consumer unifies the reference it fetched by. Both fail identically, and the failure is a conflict naming the two values:

  ```
  _mismatch.artifactVersion: conflicting values "v0.1.3" and "v0.2.0"
  ```

Open Questions in `03-decisions.md` mark the fields still under design; their `// OQN:` markers live alongside the corresponding fields in `target.cue`.

`core`'s contribution (`#Module.metadata.nameSnakeCase`) has already landed; this enhancement does not change `core` further beyond depending on that field.

## Integration Points

**core** (landed 2026-06-17, recorded here for the dependency chain):

- `core/src/types.cue` — `#SnakeNameType` (constrained string) + `#KebabToSnake` (transformer). New helpers.
- `core/src/module.cue` — `#Module.metadata.nameSnakeCase`. New derived field.
- `core/SPEC.md` — `#Module` Shape / Constraints / Rationale updated (co-update protocol).

**library**:

- `library/opm/helper/synth/render.go` — replace the `modulePath + "/" + name` import-path derivation with the canonical `modulePath + "/" + nameSnakeCase` reference. (`render.go:62` also derives the import's major line from `major(Metadata.Version)`, which D3's invariant is what makes trustworthy.)
- `library/opm/kernel` / `library/opm/helper/loader/registry/module.go` — **the primary enforcement point.** After decoding, assert the acquired module's `metadata` agrees with the coordinates it was fetched by (`#PublishedModuleRef`); refuse with a typed error naming both. Placing it on the `AcquireModuleFromRegistry` path means the CLI and the operator inherit it from one implementation.
- `library/opm/module/module.go` — if OQ3 lands on "record the fetched reference," add a field carrying the reference the module was loaded by. Note that `AcquireModuleFromRegistry` already retains a staged `module.Source`, which narrows this question since the load-time context is no longer wholly discarded.

**cli**:

- A new `opm module publish` command — derive `cue.mod/module.cue` `module:`, the package clause, **and the release tag** from `metadata` via `#CanonicalModuleRef`; refuse to push on mismatch. It does not exist today; publishing is raw `cue mod publish`.
- `cli/pkg/module/module.go` — `CanonicalModuleRef()` already implements the D1 mapping (shipped in enhancement 0006's C1). It should be reconciled with, or replaced by, the library helper so the mapping has one implementation rather than two.

**modules** (repo, not listed in `affects` — no code ships there, but the rollout touches it):

- `modules/Taskfile.yml` — retire the `versions.yml` lookup once publish derives the tag from `metadata.version`, or the third source of truth persists.

## Before / After

Reusing the `zot` module from `01-problem.md`'s example:

**Before.** `metadata.name = "zot-registry-ttl"`, published by hand at `opmodel.dev/modules/zot_registry_ttl@v0`. A `*module.Module` for it yields no way to recover `…/zot_registry_ttl`; the render path's `modulePath/name` guess produces `…/zot-registry-ttl@v0` → `module not found`.

**After.** `metadata.nameSnakeCase = "zot_registry_ttl"` (derived). The canonical reference is `opmodel.dev/modules/zot_registry_ttl@v0`, version `v0.1.0`, package `zot_registry_ttl`. `opm publish` verifies the author's `cue.mod` matches this before pushing; the library helper reconstructs the identical reference from metadata, so the render path imports the module correctly. `web-app` migrates from its hyphenated path to `…/web_app@v0` (also fixing its `@v1`/`0.1.0` mismatch), so its path leaf and package both equal `nameSnakeCase`.
