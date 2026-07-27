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
- `#Catalog` publishes through the **same pipeline** as `#Module`, so version agreement and acquire-side verification are one implementation with two artifact types rather than two conventions maintained separately (D7).
- What an author validated against is what a consumer resolves: publish never honours a dev-time dependency replacement, and says so rather than proceeding quietly (D8).

## Non-Goals

- ~~Redefining `metadata.modulePath` / `metadata.name` / `metadata.version`. Identity semantics are unchanged; this enhancement adds a *projection* and a *publishing rule*, not a new identity.~~ **Withdrawn 2026-07-26 by D13.** Module identity *is* now in scope: `metadata.version` is removed from `#Module` and `metadata.fqn` is redesigned around its absence. The non-goal was written when this entry was a naming convention; it cannot survive a decision that the version does not belong in identity at all. `metadata.modulePath` and `metadata.name` keep their meanings (D9 changes the *value* of `modulePath` for the fleet, not its semantics).
- Implementing the single-build render rewrite (`library`'s `simplify-render-single-build`). This enhancement is the addressing contract that change consumes.
- Registry auth, signing, provenance, or attestation.
- Module version-selection / pinning policy for consumers.
- The `#Catalog` *repackage* — catalog composition, subscription filters, materialization semantics. Enhancement 0001 owns those and is `implemented`. Catalog **publishing** is in scope here (D7).
- Module *discovery* — search, listing, and any index over what is published. That is a separate concern built on top of this enhancement's addressing guarantees, not part of it.

## High-Level Approach

> **Revised 2026-07-26 by D13.** Steps 3, 4, and part of 5 below describe the *version-agreement* design, which D13 retires for `#Module` by removing `metadata.version` outright: with one version in the system there is nothing to agree. They are retained because they still describe the **catalog** side (OQ13 open) and because the reasoning that produced them is what led to D13. The addressing half — steps 1, 2, 6 — is unchanged and remains the live design. See `05-risks.md ## Blast Radius` for the full per-site consequence of the removal.

Anchor the convention on a single canonical identifier and enforce it where modules are produced, then consume it where modules are imported.

1. **Canonical identifier (core, landed).** `core`'s `#Module.metadata` now carries `nameSnakeCase` — the snake_case projection of `name` (`#KebabToSnake`, validated by `#SnakeNameType`). It is CUE-identifier-safe, so it can serve as both a CUE package name and a registry-path leaf. It is derived from `name`, so it cannot drift from identity.

2. **Canonical reference mapping (this enhancement).** Define the module's registry reference as a pure function of metadata:
   - registry path = `metadata.modulePath + "/" + metadata.nameSnakeCase`
   - major qualifier = `vMAJOR(metadata.version)` (e.g. `0.1.0` → `v0`)
   - import path = `<registry path>@<major>`; dep version = `v<version>`
   - CUE package name = `metadata.nameSnakeCase`

3. **Version agreement (this enhancement, D3).** `metadata.version` and the artifact's release tag are the same value. `schemas/target.cue` states this as `#PublishedModuleRef`, which unifies the derived `depVersion` with the artifact coordinates actually in hand — so a mismatched pair is a type error, not a tolerated disagreement.

4. **Verification at acquire (library) — the primary enforcement point.** The registry loader checks the fetched artifact's metadata against the coordinates it was fetched by, and refuses on mismatch with both values named. This is the guarantee that cannot be bypassed: it holds for modules published by `cue mod publish`, by other tooling, or before this enhancement existed, and the CLI and operator inherit it together because both reach the registry through `kernel.AcquireModuleFromRegistry`.

5. **Derivation at publish, authoring in a separate command (cli, D12).** `opm module publish` reads `metadata` and derives *both* the registry path and the release tag from it, so a conformant artifact is produced by construction. It takes **no version input at all** — no `--version`, no override, no assertion flag. Writing a version is a different command: `opm module version set <semver>` edits the declaration in place in committed source, is idempotent, and keeps `cue.mod`'s `@vN` in step on a major change. The release sequence is therefore `version set` → review → commit → `publish`, with the commit sitting between deciding a version and pushing an artifact. The point is not that a wrong version is *rejected* at publish but that it is **unsayable**: with no version parameter, the command offers no surface through which source and tag can be made to disagree. Together this removes `versions.yml` as a competing source of truth — the module file becomes the single place a version is declared, and the only thing that writes it is `version set`.

6. **Kernel consumption (library).** A helper computes the canonical reference from a `*module.Module` (reading `metadata.modulePath`, `metadata.nameSnakeCase`, `metadata.version`). `synth.Instance` uses it to write the `import` and the synthesized `cue.mod` dependency, replacing the unreconstructable `modulePath/name` guess.

7. **The same pipeline for catalogs (D7).** `opm catalog publish` derives a catalog's coordinates from `#Catalog.metadata` and applies the identical version-agreement invariant. The catalog case is *simpler* on the addressing axis and *only* about version: `#Catalog` has no `name` field, so its registry path is `metadata.modulePath` verbatim — there is no leaf to project, no package-name spelling to disagree with, and no `nameSnakeCase` analogue. What it adds instead is a default (`version!: #VersionType | *"0.0.0-dev"`) that lets an unversioned catalog publish successfully while claiming a placeholder.

8. **Verification at acquire, for catalogs (D6 extended by D7).** Catalogs are not fetched through `AcquireModuleFromRegistry` — they arrive through subscription resolution in `library/opm/materialize`, which enumerates versions and pulls the selected build. That pull is therefore the catalog's acquire point, and it is where the fetched `#Catalog.metadata.version` is compared against the tag that was resolved. Two artifact types, two fetch paths, one invariant.

The relationship between the names becomes: one identity (`name` + `version`) → one canonical projection (`nameSnakeCase`, `vMAJOR`) → one registry leaf, one package name, one release tag. Publish makes conformance the default; **acquire makes it a guarantee**.

### Where the two artifact types differ

| | `#Module` | `#Catalog` |
| --- | --- | --- |
| Identity fields | `modulePath` + `name` + `version` | `modulePath` + `version` (no `name`) |
| Registry path | `modulePath` + `/` + `nameSnakeCase` | `modulePath` verbatim |
| Package-name rule | must equal `nameSnakeCase` (D1/D5) | not applicable |
| Version exposure | `version!` is required — an author must state one | `version!` carries a `*"0.0.0-dev"` **default** — silence publishes a placeholder |
| Fetch path (acquire point) | `kernel.AcquireModuleFromRegistry` | subscription resolution in `opm/materialize` |
| Blast radius of a wrong version | instance UUID, `spec.module.version`, synthesized import major | every transformer FQN in the catalog → matcher misses → `no matching transformer` |

The rightmost column is why catalogs are not a smaller version of the same problem. A module's stale version misdirects one artifact; a catalog's stale version invalidates the FQN of every transformer it ships, because `#Catalog`'s pattern constraint stamps `metadata.version: M.version` onto each one (0001 D18).

### Why verification at acquire rather than only at publish

An earlier revision of this design put enforcement solely at publish, treating load-time verification as optional. That is not sufficient, for a reason that is structural rather than incidental: `cue mod publish` exists, will keep working, and every module published to date used it. Enforcement that a publisher can route around does not give a *consumer* anything to rely on — and it is the consumer (the render path, the handoff verification, the operator's reconcile) that suffers when the invariant is false.

Publish-side derivation is still worth building; it is what makes the invariant true going forward and removes a class of author error. But it is the ergonomic half, not the guarantee.

## Schema / API Surface

Four shapes in [`schemas/target.cue`](schemas/target.cue) — two per artifact type, in the same producer/consumer pairing:

- **`#CanonicalModuleRef`** — a pure function from `#Module.metadata` to `{registryPath, packageName, major, importPath, depVersion}`. The single normative source both the cli publish command and the library helper mirror.
- **`#PublishedModuleRef`** — the same reference bound to the artifact coordinates in hand (`artifactPath`, `artifactVersion`), with the D3 invariant expressed as unification. A publisher unifies the tag it is about to write; a consumer unifies the reference it fetched by. Both fail identically, and the failure is a conflict naming the two values:

  ```
  _mismatch.artifactVersion: conflicting values "v0.1.3" and "v0.2.0"
  ```

- **`#CanonicalCatalogRef`** — the catalog analogue (D7). Degenerate on the addressing axis, since `registryPath` is `modulePath` itself; it exists so the publish command and the materialize-side check share one derivation of `major`, `importPath`, and `depVersion` rather than open-coding the `"v" + version` prefix that `01-problem.md` records going wrong once already.
- **`#PublishedCatalogRef`** — the same binding to artifact coordinates in hand, failing identically to its module counterpart.

Open Questions in `03-decisions.md` mark the fields still under design; their `// OQN:` markers live alongside the corresponding fields in `target.cue`.

`core`'s contribution (`#Module.metadata.nameSnakeCase`) has already landed; this enhancement does not change `core` further beyond depending on that field.

## Integration Points

The per-site consequence list for D13 — every file and line that changes, and the verified list of what does **not** — lives in `05-risks.md ## Blast Radius — removing `metadata.version` (D13)`. What follows is the design-level summary.

**core** (`nameSnakeCase` landed 2026-06-17; the D13 work is new and breaking):

- `core/src/types.cue` — `#SnakeNameType` (constrained string) + `#KebabToSnake` (transformer). New helpers. **Landed.**
- `core/src/module.cue` — `#Module.metadata.nameSnakeCase`. New derived field. **Landed.**
- `core/src/module.cue:22` — **delete `version!`** (D13).
- `core/src/module.cue:23` + `core/src/types.cue:26-28` — **redesign `fqn` and `#ModuleFQNType`** so neither carries a version. Shape is OQ15.
- `core/src/module.cue:36` — the `module.opmodel.dev/version` label loses its source; drop it or re-source it outside the module value.
- `core/SPEC.md` — `#Module` Shape / Constraints / Rationale updated (co-update protocol). D13 touches §255, §291-292, §304, §306-307, including the semver-with-colon rationale and the `SHA1(fqn)` determinism argument. **Load `core-schema-edit` before editing.**
- This is a **breaking** change to a published dependency every module and both catalogs consume.

**library**:

- `library/opm/helper/synth/render.go` — replace the `modulePath + "/" + name` import-path derivation with the canonical `modulePath + "/" + nameSnakeCase` reference. (`render.go:62` also derives the import's major line from `major(Metadata.Version)`, which D3's invariant is what makes trustworthy.)
- `library/opm/kernel` / `library/opm/helper/loader/registry/module.go` — **the primary enforcement point.** After decoding, assert the acquired module's `metadata` agrees with the coordinates it was fetched by (`#PublishedModuleRef`); refuse with a typed error naming both. Placing it on the `AcquireModuleFromRegistry` path means the CLI and the operator inherit it from one implementation.
- `library/opm/materialize` — **the catalog-side enforcement point** (D7 extending D6). `enumerate.go` lists a subscription's published versions and the pull that follows selects one; the decoded `#Catalog.metadata.version` is compared against that resolved tag there, because no other code path fetches a catalog. Today the comparison does not exist, so a catalog claiming `0.0.0-dev` materializes without complaint and its transformers carry FQNs naming a version that was never published.
- `library/opm/module/module.go` — if OQ3 lands on "record the fetched reference," add a field carrying the reference the module was loaded by. Note that `AcquireModuleFromRegistry` already retains a staged `module.Source`, which narrows this question since the load-time context is no longer wholly discarded.

**cli**:

- A new `opm module publish` command — derive `cue.mod/module.cue` `module:`, the package clause, **and the release tag** from `metadata` via `#CanonicalModuleRef`; refuse to push on mismatch. Takes no version argument (D12). It does not exist today; publishing is raw `cue mod publish`.
- A new `opm module version set <semver>` command (D12) — the sole writer of `metadata.version`. Edits the field in place in the module's source, idempotently, and updates `cue.mod/module.cue`'s `@vN` when the major changes so the two stay consistent with `#CanonicalModuleRef`. It performs an in-place source edit rather than a temp-copy or supplemental-file stamp, because those break artifact-bytes-equals-source-bytes and make local rendering compute a different instance UUID than published rendering. The editing mechanics — surgical AST rewrite versus a reformatting round-trip, and which source shapes defeat a field-level editor — are what `experiments/05-in-place-version-stamping/` is for.
- `opm catalog version set <semver>` (D12 via D7) — the same command for the catalog artifact type. Where a catalog's version is authored is still OQ13's question, so this bullet fixes the command, not its target file.
- A new `opm catalog publish` command (D7) — the same command with `#CanonicalCatalogRef` and no package-name check. Shares the artifact-shape gate, the coordinate derivation, the version-agreement check, and the D8 local-override gate; differs only in which artifact it decodes.
- The D8 gate, shared by both — detect `cue.mod/local-module.cue` replacements before pushing, report each one against the registry version that will supersede it, and refuse without the explicit allow flag. `cli/pkg/loader/provenance.go` already carries `HasLocalModuleReplacement` (enhancement 0006 D7 render provenance); publish reads the same file for a different purpose, so the detector is reused rather than rewritten.
- `cli/pkg/module/module.go` — `CanonicalModuleRef()` already implements the D1 mapping (shipped in enhancement 0006's C1). It should be reconciled with, or replaced by, the library helper so the mapping has one implementation rather than two.

**modules** (repo, not listed in `affects` — no code ships there, but the rollout touches it):

- `modules/Taskfile.yml` — retire the `versions.yml` lookup once publish derives the tag from `metadata.version`, or the third source of truth persists.

## Before / After

Reusing the `zot` module from `01-problem.md`'s example:

**Before.** `metadata.name = "zot-registry-ttl"`, published by hand at `opmodel.dev/modules/zot_registry_ttl@v0`. A `*module.Module` for it yields no way to recover `…/zot_registry_ttl`; the render path's `modulePath/name` guess produces `…/zot-registry-ttl@v0` → `module not found`.

**After.** `metadata.nameSnakeCase = "zot_registry_ttl"` (derived). The canonical reference is `opmodel.dev/modules/zot_registry_ttl@v0`, version `v0.1.0`, package `zot_registry_ttl`. `opm publish` verifies the author's `cue.mod` matches this before pushing; the library helper reconstructs the identical reference from metadata, so the render path imports the module correctly. `web-app` migrates from its hyphenated path to `…/web_app@v0` (also fixing its `@v1`/`0.1.0` mismatch), so its path leaf and package both equal `nameSnakeCase`.
