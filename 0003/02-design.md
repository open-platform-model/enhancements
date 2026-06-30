# Design — OPM Module Publishing Workflow

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- Given a module's `metadata` alone, the canonical CUE registry reference (path, package name, version, major) is **deterministically derivable** — no guessing, no per-transform special cases.
- A module's registry coordinates are **enforced at publish time** (cli), so a module that violates the convention never reaches a registry.
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

3. **Publish enforcement (cli).** `opm publish` checks the module's `cue.mod/module.cue` `module:` path and its `package` clause against the canonical mapping before pushing, failing fast on mismatch (and/or generating the conformant `cue.mod` from metadata). This is where the registry path — which the schema cannot see — is bound to identity.

4. **Kernel consumption (library).** A helper computes the canonical reference from a `*module.Module` (reading `metadata.modulePath`, `metadata.nameSnakeCase`, `metadata.version`). `synth.Instance` uses it to write the `import` and the synthesized `cue.mod` dependency, replacing the unreconstructable `modulePath/name` guess. The registry loader is the natural place to additionally *verify* the resolved coordinates match the canonical mapping at load time.

The relationship between the names becomes: one identity (`name`) → one canonical projection (`nameSnakeCase`) → one registry leaf and one package name. Enforcement lives at publish (the only point that controls the `cue.mod` path), and resolution at consume (derivable, because the rule is fixed).

## Schema / API Surface

The headline shape is the canonical-reference computation, expressed in CUE in [`schemas/target.cue`](schemas/target.cue) as `#CanonicalModuleRef` — a pure function from `#Module.metadata` to `{registryPath, packageName, major, importPath, depVersion}`. It is the single normative source both the cli publish check and the library helper mirror. Open Questions in `03-decisions.md` mark the fields still under design (notably enforce-vs-generate and package-name qualification); their `// OQN:` markers live alongside the corresponding fields in `target.cue`.

`core`'s contribution (`#Module.metadata.nameSnakeCase`) has already landed; this enhancement does not change `core` further beyond depending on that field.

## Integration Points

**core** (landed 2026-06-17, recorded here for the dependency chain):

- `core/src/types.cue` — `#SnakeNameType` (constrained string) + `#KebabToSnake` (transformer). New helpers.
- `core/src/module.cue` — `#Module.metadata.nameSnakeCase`. New derived field.
- `core/SPEC.md` — `#Module` Shape / Constraints / Rationale updated (co-update protocol).

**library**:

- `library/opm/helper/synth/render.go` — replace the `modulePath + "/" + name` import-path derivation with the canonical `modulePath + "/" + nameSnakeCase` reference; qualify the import with the package name per the resolved OQ.
- `library/opm/helper/loader/registry/module.go` — optionally verify the resolved `modPath@version` matches `#CanonicalModuleRef` for the loaded metadata; surface a typed mismatch error.
- `library/opm/module/module.go` — if the resolution OQ lands on "record the fetched reference," add a field carrying the registry reference the module was loaded by.

**cli**:

- The `opm publish` command — validate (and/or generate) `cue.mod/module.cue` `module:` and the package clause against `#CanonicalModuleRef`; refuse to push on mismatch.

## Before / After

Reusing the `zot` module from `01-problem.md`'s example:

**Before.** `metadata.name = "zot-registry-ttl"`, published by hand at `opmodel.dev/modules/zot_registry_ttl@v0`. A `*module.Module` for it yields no way to recover `…/zot_registry_ttl`; the render path's `modulePath/name` guess produces `…/zot-registry-ttl@v0` → `module not found`.

**After.** `metadata.nameSnakeCase = "zot_registry_ttl"` (derived). The canonical reference is `opmodel.dev/modules/zot_registry_ttl@v0`, version `v0.1.0`, package `zot_registry_ttl`. `opm publish` verifies the author's `cue.mod` matches this before pushing; the library helper reconstructs the identical reference from metadata, so the render path imports the module correctly. `web-app` migrates from its hyphenated path to `…/web_app@v0` (also fixing its `@v1`/`0.1.0` mismatch), so its path leaf and package both equal `nameSnakeCase`.
