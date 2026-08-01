# Design — Module and Catalog Publishing

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach should be understandable without deep implementation knowledge. All trade-off reasoning lives in `03-decisions.md`, not here.

## Design Goals

- **One publish pipeline, two artifact types.** Modules and catalogs differ in which artifact is decoded and which gates apply, not in how coordinates are derived or how the push happens.
- **The artifact is authoritative.** Publish reads an artifact and works out where it goes; it never rewrites an artifact to fit a coordinate someone typed.
- **Published bytes equal committed bytes.** What a consumer evaluates is what the author committed and can `git show`.
- **A wrong version is unsayable rather than merely rejected.** For modules there is no version in source to disagree with the tag; for catalogs the version is written by a command whose only job is to write it, with a commit between that and the push.
- **An incomplete artifact cannot be published.** Identity that has not been supplied is caught before the push, not by the first consumer to fetch it.
- **What an author validated against is what a consumer resolves**, and where those differ, publish says so rather than proceeding quietly.
- **A published name has an owner**, and a path says what kind of artifact it addresses.
- **Zero-setup consumption.** A canonical path resolves for anyone with a stock CLI, with no registry configuration to edit first.

## Non-Goals

- **What identity *is*.** The shape of `metadata.modulePath`, the absence of a module version, the catalog's compatibility signal, and the major-keyed FQN all belong to enhancement 0010. This entry writes those fields and pushes the artifact carrying them.
- **Read-side verification.** The checks a consumer performs at acquire, materialize, and subscription are 0010's. This entry's checks are producer-side, and are deliberately not the guarantee.
- **Signing, provenance, and attestation.** Out of scope regardless of how the credential question resolves.
- **Artifact discovery** — search, listing, or any index over what is published. It rests on this entry's addressing and namespace guarantees but is its own concern.
- **The CLI's platform-resolution modes** — synthesizing a `#Platform` from a module's catalog dependencies, and honouring `local-module.cue` during development. Adjacent through the same file, but a rendering concern rather than a publishing one.

## High-Level Approach

Four commands over one pipeline, plus a namespace that makes the coordinates worth deriving.

**1. `opm module publish` / `opm catalog publish`.** Decode the artifact, read its identity, derive the registry coordinates from it, run the gates, push. The coordinates are read rather than composed: under 0010 the declared `modulePath` already *is* the registry address, so publish compares it against `cue.mod/module.cue`'s `module:` line and refuses on disagreement rather than assembling an address from parts.

**2. `opm module version set` / `opm catalog version set`.** The version writer, separate from the publisher. For catalogs it writes `identity.cue`'s `Version` field in place, idempotently. For modules — which declare no version under 0010 — it has nothing to write, and the module form exists only if OQ4 gives it a job.

**3. `--version` on publish.** The other writer, for the flow where a release process supplies the version rather than a human. Against an open identity field it fills it; against a concrete one it asserts equality and refuses on mismatch. Either way the artifact that is pushed carries a concrete version, and the value is never invented by the tool.

**4. `opm catalog registry check`.** Verify a *published* catalog out of band: pull it, decode it, and confirm its identity is concrete and agrees with the coordinates it was fetched by. This is the same check a consumer performs, run deliberately against the registry rather than incidentally during a render — so a broken publish can be found without waiting for someone to trip over it.

**5. The compatibility gate on `opm catalog publish` (D9).** For each primitive being published, pull the last published build shipping that `name` at that `apiVersion` and refuse if the new definition is not backwards-compatible with it — enhancement 0010 D27's additive-only rule. It reuses the pull-and-decode the command above already performs. This is the gate that makes 0010's contract keys trustworthy: a key that outlives a catalog release is only as good as the promise that what stands behind it did not change shape.

Around those, three properties:

**Gates that reflect blast radius.** A `cue.mod/local-module.cue` in the tree being published is never honoured — a local path is unresolvable for any consumer, and CUE strips the file anyway. Its *presence* refuses the push. For a module, an explicit flag overrides, because the divergence is scoped to one artifact and its direct consumers, and each replacement is reported next to the registry version that will supersede it. For a catalog, there is no override: a catalog's divergence propagates into the key space of everything built against it, which is not a scope any publisher can assess at the moment they would press the flag.

**A namespace with owners and kinds.** Published modules live at `opmodel.dev/m/<owner>/<name>`, under a reserved `m` segment that separates module space from catalog space (`opmodel.dev/catalogs/<name>`) and schema space (`opmodel.dev/core`). Owner-scoping supplies uniqueness structurally, so two people can both publish `postgres` without a land grab and without the registry arbitrating. The reserved segments make the namespace *partitionable*, so tooling can tell a module from a catalog from a schema by path alone.

**A registry that hosts.** The central registry serves artifacts rather than indexing artifacts hosted elsewhere, because CUE resolves a module path to a host through the prefix→host mapping in `CUE_REGISTRY` with no per-domain autodiscovery. A module published under its author's own domain is unresolvable for every consumer who has not first edited their own configuration. "Publish anywhere" and "resolves for everyone with no setup" are not simultaneously available under that resolution model.

### Where the two artifact types differ

| | `opm module publish` | `opm catalog publish` |
| --- | --- | --- |
| Version in source | none — the tag is the only version | full SemVer in `identity.cue` |
| Where the tag comes from | `--version`, from a release process or a human | the artifact's own `Version`, or `--version` |
| `version set` | nothing to write (OQ4) | writes `identity/identity.cue` |
| Registry path | `opmodel.dev/m/<owner>/<name>` | `opmodel.dev/catalogs/<name>` |
| Package-name rule | must equal `metadata.name`, so a bare import binds | not applicable — a catalog is imported by subpackage |
| `local-module.cue` present | refuse; explicit flag overrides | refuse, unconditionally |
| Compatibility with the last published build | not applicable — a module ships no contracts | refuse on a non-additive change within an `apiVersion` (D9) |
| Out-of-band verification | — | `opm catalog registry check` |

### What publish does not do

Three things are deliberately absent, and each absence is the mechanism rather than an omission.

Publish **does not invent a version**. There is no "bump the patch", no "read the highest tag and increment", no default. A version arrives from an author or from a release process or the command does not run.

Publish **does not edit the artifact to make it publishable**. If identity is not concrete, the answer is a refusal naming the field, not a value filled in on the artifact's behalf.

Publish **does not resolve dependencies differently from a consumer**. There is exactly one resolution — the published one — and where the author's tree would have resolved differently, that is reported before the push rather than reconciled during it.

## Schema / API Surface

The shapes in [`schemas/target.cue`](schemas/target.cue) describe a publish *decision* rather than a CUE type an artifact carries — they are the contract the command implements, expressed so it can be checked.

- **`#TagRef`** — a release tag and its decomposition, with the constraint that a tag's major matches the artifact path's major. CUE already enforces this half (measured: `cue mod publish v9.1.0` against a `@v3` module fails with `publish version "v9.1.0" does not match the major version "v3"`), so the shape records a check that exists rather than one to build.
- **`#PublishPlan`** — everything publish resolves before it pushes: the artifact path, the tag, the derived registry repository, and the gate outcomes. A plan that does not unify is a push that does not happen.
- **`#IdentityState`** — the three states an identity field can be in (absent, open, concrete) and what publish does with each.
- **`#OverrideGate`** — the `local-module.cue` rule, with the module/catalog asymmetry expressed rather than described.
- **`#RegistryPath`** — the namespace shape: reserved kind segment, owner scope, name leaf.

## Integration Points

**cli** — the bulk of the work; none of these commands exist today.

- `opm module publish` / `opm catalog publish` — one implementation, two entry points differing in which artifact is decoded and which gates run.
- `opm catalog version set <semver>` — writes `identity/identity.cue`'s `Version`, idempotently, locating it by the path `#IdentityPackage` fixes rather than by a marker attribute (D8). The editing mechanics are unresolved (see OQ1's neighbour question in `03-decisions.md`): a surgical AST rewrite preserves formatting and comments where a reformatting round-trip does not.
- `opm catalog registry check` — pull, decode, verify.
- The compatibility gate (D9) — for each primitive, resolve the last published build at the same `apiVersion`, pull it, and compare structurally. **Measured 2026-08-01** in [`experiments/03-d27-compat-gate`](experiments/03-d27-compat-gate/): `cue.Value.Subsume` was the candidate primitive and **cannot express the rule in either direction** (10/14 and 8/14), because adding a struct field narrows while adding a disjunct widens and D27 calls both additive. The gate is a **three-rule field-wise walk** — recurse structs with the removed/added-field rules, forward-subsume at leaves, compare defaults explicitly — scoring 14/14 and level-aware per 0010 D34. It lives in `library` so this command, `opm catalog registry check --compat` (D7) and any CI action share one implementation.
- `cli/pkg/loader/provenance.go` — `HasLocalModuleReplacement` already detects the file for render provenance; publish reads the same detector for a different purpose, so it is reused rather than rewritten.
- `cli/pkg/module/module.go` — the coordinate derivation collapses into a read once `modulePath` is the full address; `majorVersionTag()` / `ensureVPrefix()` lose their caller.
- Credential handling — nothing exists today (OQ2).

**catalog repos** (`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`)

- `Taskfile.yml` — the copy-and-stamp `publish` task is deleted, not disabled. `task publish VERSION=vX.Y.Z` becomes `opm catalog publish --version X.Y.Z`.
- `.github/workflows/release.yml` — the `publish-cue` job calls the new command; release-please continues to decide the version and hand it over, rather than writing it itself.
- `branch-publish.yml` — the `-dev` pre-release path needs a version that sorts correctly and an answer for the unfilled case; it is the concrete instance of OQ4.

**modules**

- `modules/Taskfile.yml` — `publish:smart` and the `versions.yml` lookup are retired. What replaces the "should this publish?" decision is OQ4.
- `modules/versions.yml` — deleted.

**library** — no new code. Publish decodes artifacts through the existing loaders; the checks that matter to a consumer live on the read paths, which belong to enhancement 0010.

## Before / After

**Publishing a catalog.** Before:

```
$ task publish VERSION=v1.3.0
# copy src/ → .build/
# write .build/identity/version_override.cue  (Version: "1.3.0")
# cue vet .build/
# cue mod publish v1.3.0   ← publishes bytes that never existed in git
```

After:

```
$ opm catalog version set 1.3.0     # writes identity/identity.cue, in place
$ git diff                          # one line; review it
$ git commit -am "release: catalog 1.3.0"
$ opm catalog publish               # reads 1.3.0 from the artifact; pushes it
```

The commit sits between deciding a version and pushing an artifact, so no published artifact carries a version that exists in no commit. Nothing is generated, and the bytes in the registry are the bytes under `git show`.

**Publishing a module.** Before, `task publish:smart` derives a tag from a checksum and pushes an artifact whose metadata claims a different version. After, the module declares no version at all, so:

```
$ opm module publish --version 2.1.0
```

There is nothing in the artifact for `2.1.0` to disagree with. The tag is the version, the CLI records the coordinate it fetched, and the identity that survives — the path and its major — is checked against `cue.mod/module.cue` before the push.

**Publishing with a local override.** Before: silent success, and an artifact that resolves against dependencies the author never tested. After:

```
$ opm catalog publish
error: cue.mod/local-module.cue is present; a catalog cannot be published from a tree
       configured for local development
  opmodel.dev/core@v1 → ../../core  (would resolve to v1.0.0-alpha.3 when published)
```

For a module the same report is followed by an offer of the explicit flag rather than an unconditional stop.
