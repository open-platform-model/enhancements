# Design: Module and Catalog Publishing

One publish pipeline serves two artifact types, with coordinates derived from the artifact rather than typed by hand. Design Goals and Non-Goals define the boundary; trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **One publish pipeline, two artifact types.** Modules and catalogs differ in which artifact is decoded and which gates apply, not in how coordinates are derived or how the push happens.
- **The artifact is authoritative.** Publish reads an artifact and works out where it goes; it never rewrites an artifact to fit a coordinate someone typed.
- **Published bytes equal committed bytes.** What a consumer evaluates is what the author committed and can `git show`.
- **A wrong version is unsayable rather than merely rejected.** Both artifact types carry a version in source (D12), written by a command whose only job is to write it, with a commit between that and the push, and the tag must name that version (D18).
- **An incomplete artifact cannot be published.** Identity that has not been supplied is caught before the push, not by the first consumer to fetch it.
- **What an author validated against is what a consumer resolves**, and where those differ, publish says so rather than proceeding quietly.
- **A published name has an owner**, established by domain control rather than by OPM arbitrating it. Within the space OPM does own, a path also says what kind of artifact it addresses.
- **Zero-setup consumption.** A canonical path resolves for anyone with a stock CLI, with no registry configuration to edit first.

## Non-Goals

- **What identity *is*.** The shape of `metadata.modulePath`, the presence and meaning of a module version, the catalog's compatibility signal, and the major-keyed FQN all belong to enhancement 0010. This entry writes those fields and pushes the artifact carrying them. (D12 supplies the publish assertion for `#Module.metadata.version`, restored by 0010 D2, and is contingent on that restoration landing. The shape is still 0010's to define.)
- **Read-side verification.** The checks a consumer performs at acquire, materialize, and subscription are 0010's. This entry's checks are producer-side, and are deliberately not the guarantee.
- **Signing, provenance, and attestation.** Out of scope regardless of how the credential question resolves.
- **Artifact discovery**: search, listing, or any index over what is published. It rests on this entry's addressing and namespace guarantees but is its own concern.
- **The CLI's platform-resolution modes**: synthesizing a `#Platform` from a module's catalog dependencies, and honouring `local-module.cue` during development. Adjacent through the same file, but a rendering concern rather than a publishing one.

## High-Level Approach

Six commands over one pipeline, plus a namespace that makes the coordinates worth deriving.

**1. `opm module publish` / `opm catalog publish`.** Decode the artifact, read its identity, derive the registry coordinates from it, run the gates, push. The coordinates are read rather than composed: under 0010 the declared `modulePath` already *is* the registry address, so publish compares it against `cue.mod/module.cue`'s `module:` line and refuses on disagreement rather than assembling an address from parts.

**2. `opm module version set` / `opm catalog version set`.** The version writer, separate from the publisher. Both forms write their artifact's `identity/identity.cue` `Version` field in place, idempotently: modules carry an identity subpackage exactly as catalogs do (D12).

**3. `--version` on publish.** The other writer, for the flow where a release process supplies the version rather than a human. Against an open identity field it fills it; against a concrete one it asserts equality and refuses on mismatch. Either way the artifact that is pushed carries a concrete version, and the value is never invented by the tool.

**4. `opm catalog registry check`.** Verify a *published* catalog out of band: pull it, decode it, and confirm its identity is concrete and agrees with the coordinates it was fetched by. This is the same check a consumer performs, run deliberately against the registry rather than incidentally during a render, so a broken publish can be found without waiting for someone to trip over it.

**5. `opm mod init`: scaffold *and* repair (D20).** Already aliased from `opm module init`, and no longer create-only. Against an existing tree it detects what is missing or non-conformant: an absent or disagreeing `cue.mod/module.cue`, a missing `identity/identity.cue`, or absent `metadata` wiring. It reports each one and offers to repair, asking for confirmation a second time because it writes into a tree it did not author. It states every file it will create or edit, and for an edit both the current value and the replacement, so the confirmation is a judgement rather than a formality.

What it never does is **invent identity**. A tree that states no module path is asked for one; a version is never chosen. That is the same boundary publish holds (D2, D3), moved one command earlier. A repair tool that invents a version has only relocated the invention upstream of the gate that exists to prevent it. This is what makes D16's refusal actionable: publish enforces that `cue.mod` and identity agree and refuses to write either, so something has to be able to write them.

**6. `opm registry login [registry]` (D11; command name per D24).** Authenticate against the registry the CLI already resolves (`--registry`, then `OPM_REGISTRY`, then `config.registry`), writing to the credential store CUE itself reads, because CUE performs the push and a credential written anywhere else is invisible at the moment it is needed.

**7. The compatibility gate on `opm catalog publish` (D9).** For each primitive being published, pull the last published build shipping that `name` at that `apiVersion` and refuse if the new definition is not backwards-compatible with it: enhancement 0010 D27's additive-only rule. It reuses the pull-and-decode the command above already performs. This is the gate that makes 0010's contract keys trustworthy: a key that outlives a catalog release is only as good as the promise that what stands behind it did not change shape.

Around those, three properties:

**Gates that reflect blast radius.** A `cue.mod/local-module.cue` in the tree being published is never honoured: a local path is unresolvable for any consumer, and CUE strips the file anyway. Its *presence* refuses the push. For a module, an explicit flag overrides, because the divergence is scoped to one artifact and its direct consumers, and each replacement is reported next to the registry version that will supersede it. For a catalog, there is no override: a catalog's divergence propagates into the key space of everything built against it, which is not a scope any publisher can assess at the moment they would press the flag.

**A namespace OPM shapes only where it owns the domain (D13).** Path ownership is domain ownership, so OPM arbitrates nothing it does not own. First-party artifacts keep their current paths: `opmodel.dev/modules/<name>`, `opmodel.dev/catalogs/<name>`, `opmodel.dev/core`, plus `opmodel.dev/platforms/<name>` reserved by D14. Publishers with no domain of their own get `community.opmodel.dev/m/<owner>/<name>`, where the owner segment supplies uniqueness structurally so two people can both publish `postgres` without a land grab. Everyone else uses a vanity domain on the central registry or their own registry entirely, with any path they like. The kind segments remain a *first-party layout convention* rather than a global property: free-form third-party paths mean tooling must handle arbitrary shapes regardless.

**A registry that hosts.** The central registry serves artifacts rather than indexing artifacts hosted elsewhere, because CUE resolves a module path to a host through the prefix→host mapping in `CUE_REGISTRY` with no per-domain autodiscovery. A module hosted *elsewhere* (on its author's own registry) is unresolvable for every consumer who has not first edited their own configuration. "Host anywhere" and "resolves for everyone with no setup" are not simultaneously available under that resolution model.

What that argument does **not** constrain is the *path*. A bare host in `CUE_REGISTRY` is a catch-all used "to fetch all modules" (measured, `cue v0.17.1`), which is how the default Central Registry serves arbitrary paths, so a vanity domain like `example.com/k8up`, hosted on OPM's registry, resolves with no configuration edited. Hosting and naming are independent axes, and D13 constrains only the first.

### Where the two artifact types differ

| | `opm module publish` | `opm catalog publish` |
| --- | --- | --- |
| Version in source | full SemVer in `identity.cue` (D12) | full SemVer in `identity.cue` |
| Where the tag comes from | the artifact's own `Version`, or `--version` | the artifact's own `Version`, or `--version` |
| `version set` | writes `identity/identity.cue` | writes `identity/identity.cue` |
| Registry path | `opmodel.dev/modules/<name>` first-party, `community.opmodel.dev/m/<owner>/<name>` otherwise (D13) | `opmodel.dev/catalogs/<name>` first-party, `community.opmodel.dev/catalogs/<owner>/<name>` otherwise |
| Package-name rule | must equal `metadata.name`, so a bare import binds | not applicable: a catalog is imported by subpackage |
| `local-module.cue` present | refuse; explicit flag overrides | refuse, unconditionally |
| Compatibility with the last published build | not applicable: a module ships no contracts | refuse on a non-additive change within an `apiVersion` (D9) |
| Out-of-band verification | N/A | `opm catalog registry check` |

### What publish does not do

Three things are deliberately absent, and each absence is the mechanism rather than an omission.

Publish **does not invent a version**. There is no "bump the patch", no "read the highest tag and increment", no default. A version arrives from an author or from a release process or the command does not run.

Publish **does not edit the artifact to make it publishable**. If identity is not concrete, the answer is a refusal naming the field, not a value filled in on the artifact's behalf.

Publish **does not resolve dependencies differently from a consumer**. There is exactly one resolution (the published one), and where the author's tree would have resolved differently, that is reported before the push rather than reconciled during it.

## Schema / API Surface

The shapes in [`contracts/contracts.cue`](contracts/contracts.cue) describe a publish *decision* rather than a CUE type an artifact carries: they are the contract the command implements, expressed so it can be checked.

- **`#TagRef`**: a release tag and its decomposition, with the constraint that a tag's major matches the artifact path's major. CUE already enforces this half (measured: `cue mod publish v9.1.0` against a `@v3` module fails with `publish version "v9.1.0" does not match the major version "v3"`), so the shape records a check that exists rather than one to build. It does **not** bind the tag to the declared version: that is `#PublishPlan`'s `_versionAgrees` (D18).
- **`#PublishPlan`**: everything publish resolves before it pushes: the artifact path, the tag, the derived registry repository, the gate outcomes, and the tag-names-the-declared-version rule. A plan that does not unify is a push that does not happen.
- **`#IdentityState`**: the three states an identity field can be in (absent, open, concrete), what publish does with each, and the `effective` value the published artifact will carry.
- **`#OverrideGate`**: the `local-module.cue` rule, with the module/catalog asymmetry expressed rather than described.
- **`#FirstPartyPath` / `#CommunityPath`**: the two namespaces OPM operates (D13, D14). Deliberately not a model of every publishable path: a vanity domain or a self-hosted registry may use any valid CUE module path.

## Integration Points

**cli**: the bulk of the work; none of these commands exist today.

- `opm module publish` / `opm catalog publish`: one implementation, two entry points differing in which artifact is decoded and which gates run.
- `opm module version set <semver>` / `opm catalog version set <semver>`: writes `identity/identity.cue`'s `Version`, idempotently, locating it by the path `#IdentityPackage` fixes rather than by a marker attribute (D8). The edit is a surgical AST rewrite that preserves formatting and comments and rebuilds the `&` chain so a `#VersionType` assertion survives, and it writes the **working tree** rather than a copy (D12). Validated in [`experiments/01-version-set-write-back`](experiments/01-version-set-write-back/).
- `opm catalog registry check`: pull, decode, verify.
- The compatibility gate (D9): for each primitive, resolve the last published build at the same `apiVersion`, pull it, and compare structurally. **Measured 2026-08-01** in [`experiments/03-d27-compat-gate`](experiments/03-d27-compat-gate/): `cue.Value.Subsume` was the candidate primitive and **cannot express the rule in either direction** (10/14 and 8/14), because adding a struct field narrows while adding a disjunct widens and D27 calls both additive. The gate is a **three-rule field-wise walk**: recurse structs with the removed/added-field rules, forward-subsume at leaves, and compare defaults explicitly. It scores 14/14 and is level-aware per 0010 D34. It lives in `library` so this command, `opm catalog registry check --compat` (D7) and any CI action share one implementation.
- `cli/pkg/loader/provenance.go`: `HasLocalModuleReplacement` already detects the file for render provenance; publish reads the same detector for a different purpose, so it is reused rather than rewritten.
- `cli/pkg/module/module.go`: the coordinate derivation collapses into a read once `modulePath` is the full address; `majorVersionTag()` / `ensureVPrefix()` lose their caller.
- `opm registry login [registry]`: resolves its target through the existing `ResolveRegistry` precedence and writes to the credential store CUE already reads (D11; command name per D24). Nothing exists today.
- The tag-names-the-declared-version check (D18) and the `cue.mod` agreement check (D16), both also exposed through `opm module vet`.

**catalog repos** (`catalog_opm`; `catalog_kubernetes` and `catalog_opm_experimental` fold into it under 0010 D47, so one publish flow remains)

- `Taskfile.yml`: the copy-and-stamp `publish` task is deleted, not disabled. `task publish VERSION=vX.Y.Z` becomes `opm catalog publish --version X.Y.Z`.
- `.github/workflows/release.yml`: the `publish-cue` job calls the new command; release-please continues to decide the version and hand it over, rather than writing it itself.
- `branch-publish.yml`: unchanged. `.tasks/branch-tag.sh` already derives a correct `-dev` version deterministically (`v<MAJOR>.<NEXT_MINOR>.0-dev.<commit_ct>.g<sha>`, refusing on `main` and on a dirty tree), and it sorts above the releases it descends from and below the next stable (D15).

**modules**

- `modules/Taskfile.yml`: the checksum-driven `publish` task and its `versions.yml` lookup are retired. Nothing replaces the "should this publish?" decision, because under D15 it dissolves: publish reads the authored version and no-ops when the registry already holds it, so a sweep over every module is idempotent.
- `modules/versions.yml`: deleted.
- Each module gains `identity/identity.cue` and the `metadata` wiring that derives from it (D12), generated by `opm module init`.

**library**: the D9 compatibility comparator lives here, so `opm catalog publish`, `opm catalog registry check --compat` (D7) and any CI action share one implementation. This is 0010 D32's argument for placing a check in the kernel. Predecessor selection **moves** rather than being rewritten: `materialize/enumerate.go`'s `enumerateVersions` plus `filter.go:112`'s `highestStable` already do it, and 0010 D14 deletes `filter.go` out from under them.

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

**Publishing a module.** Before, the checksum task derives a tag from a checksum and pushes an artifact whose metadata claims a different version. After, a module carries an identity subpackage exactly as a catalog does (D12, on 0010 D2), so the flow is the same one and `--version` means the same thing:

```
$ opm module version set 2.1.0     # writes identity/identity.cue, in place, idempotently
$ git commit -am "release 2.1.0"   # the seam
$ opm module publish               # derives the tag from what is committed
```

```
$ opm module publish --version 2.1.0
```

The second form is for release automation with no human to review a diff. Against an **open** `Version` it fills it; against a **concrete** one it asserts equality and refuses on mismatch, one meaning on both artifact types, where before it was a writer on one command and a bare coordinate on the other. Publish additionally verifies `metadata.version == id.Version`, because `core` cannot enforce the wiring; the path and its major are checked against `cue.mod/module.cue` before the push, and 0010 D40 checks the declared version's major against the path's.

**Publishing with a local override.** Before: silent success, and an artifact that resolves against dependencies the author never tested. After:

```
$ opm catalog publish
error: cue.mod/local-module.cue is present; a catalog cannot be published from a tree
       configured for local development
  opmodel.dev/core@v1 → ../../core  (would resolve to v1.0.0-alpha.3 when published)
```

For a module the same report is followed by an offer of the explicit flag rather than an unconditional stop.
