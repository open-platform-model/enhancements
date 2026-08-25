# Class 1: core schema (`opmodel.dev/core`)

**Carrier:** CUE module SemVer, major in the module path. **Surface:** the published definitions of the core package. **Bump:** the stable table, with the commit-type mapping below as the claim layer. **Pre-stable:** the `-alpha.N` line; crossing a major is a separate, stated decision. **Enforcement:** claim only today; OQ6 asks whether definition subsumption can carry a gate.

> **Verbatim from `core/CLAUDE.md ## Repository Rules`.**

- The schema is a published contract. A breaking change to the `core` package is a breaking change for every consumer — prefer additive evolution.
- The CUE module is on major `@v2`, currently shipping `v2.0.0-alpha.N` prereleases (enhancement 0010 — the identity reshape moved the schema off the `@v1` line, which lives on as the protected `v1` maintenance branch, stable at `v1.1.0`). release-please runs in prerelease mode (`prerelease: true`, `prerelease-type: "alpha"`, `bump-minor-pre-major: false` in `release-please-config.json`); a `feat!:` advances the alpha counter **within** the major — it does not bump the major. Crossing a major is a deliberate act: edit `src/cue.mod/module.cue`'s `module:` line and force the version with a `Release-As: X.0.0-alpha.1` footer in the same commit. The two must land together, or `cue mod publish` rejects the tag as not matching the declared major. A future stable cut drops the `-alpha` suffix.

> **Verbatim from `core/CLAUDE.md ### Commit conventions and release impact`.**

## Commit conventions and release impact

Releases are driven entirely by commit message types (Conventional Commits). Use the right type — a misclassified commit will either cut a release nobody needs or hide a change consumers needed to see.

| Commit type                       | Version bump                    | In changelog | Use for                                                       |
| ---                               | ---                             | ---          | ---                                                           |
| `feat:`                           | minor                           | yes          | new construct, new field, additive schema surface             |
| `fix:`                            | patch                           | yes          | wrong constraint, broken default, definition behaving wrong   |
| `perf:`                           | patch                           | yes          | schema compile-time / evaluation cost improvements            |
| `revert:`                         | patch                           | yes          | undo of a prior released change                               |
| `feat!:` / `feat(scope)!:` / `BREAKING CHANGE:` | prerelease (advances `-alpha.N` on `@v2`) | yes | removing/renaming a definition, tightening a published constraint |
| `refactor:`                       | none                            | hidden       | moving files, renaming internal-only identifiers, restructuring |
| `docs:`                           | none                            | hidden       | README, design notes, comments — anything consumers don't see  |
| `style:`                          | none                            | hidden       | formatting-only changes (run `task fmt`)                       |
| `chore:`, `test:`, `ci:`, `build:` | none                           | hidden       | Taskfile, hooks, workflows, repo tooling                       |

**Rule of thumb:** if the published CUE schema is byte-identical before and after the change, it is *not* a `feat:` or `fix:`. File moves, directory restructures, doc tweaks, Taskfile edits, CI hardening — none of these warrant a release. They get `refactor:`, `docs:`, `chore:`, etc., and release-please skips them.

Examples:

- Moving `*.cue` files between directories with no content change → `refactor:`
- Adding a new `#Component` or expanding a definition's field set → `feat:`
- Tightening a regex constraint already in a published definition → `feat!:` (consumers may now fail validation)
- **With a scope, the `!` goes after the scope: `feat(identity)!:`.** The form `feat!(identity):` is NOT valid Conventional Commits syntax — release-please fails to parse it, silently classifies the commit as non-user-facing, and cuts no release (measured 2026-08-10: core PR 45 merged as `feat!(identity): …` and release-please reported "No user facing commits found"). The commit-msg hook does not catch this; check the subject by eye.
- Loosening a regex constraint → `fix:` (was rejecting things it should have accepted)
- Editing `SPEC.md` only → `docs:`
- Editing `Taskfile.yml`, hooks, workflows → `chore:` or `ci:`

If a window between releases contains only hidden-type commits, no release PR is opened. If it mixes one `feat:` with several `refactor:`/`chore:`, a release is cut but the changelog only lists the `feat:`.

> **Verbatim from `core/openspec/changes/core-alpha-release/specs/schema-release/spec.md (unarchived change; the only written core release policy)`.**

## ADDED Requirements

## Requirement: The schema is published only by CI, from a reviewed release

A `core` release MUST be produced by merging the release-please PR, which tags the version and runs the `publish-cue` job gated on `release_created == 'true'`. `cue mod publish` MUST NOT be run against a live registry by hand, including to recover from a failed job — a failed publish is debugged and re-run in CI.

A published version is immutable. A tag CI did not build is a tag nobody reviewed, and it cannot be withdrawn.

### Scenario: A release is cut by merging the release PR

- **WHEN** the accumulated release PR for `v2.0.0-alpha.2` is merged
- **THEN** the tag and GitHub Release are created, and the `publish-cue` job pushes the module

### Scenario: A failed publish is not repaired by hand

- **WHEN** the `publish-cue` job fails
- **THEN** the failure is fixed and the job re-run, and no local `cue mod publish` is issued against the registry

## Requirement: A pre-stable break defaults to advancing the prerelease, and crossing a major is a separate decision

A breaking schema change on a pre-stable major line MUST either advance the prerelease on that line or bump the module major, and it MUST state in its proposal which it does and why. Advancing the prerelease with the module path unmoved is the **default**, not an absolute.

A change MUST bump the module major when the break is one a consumer cannot absorb by re-reading the same import path: when the meaning of an existing field changes, when values every published artifact declares are refused, or when a derived identity consumers store moves. Pre-stable licence makes staying on the line *permissible*; it does not make it correct.

Crossing a major MUST be deliberate and MUST be stated in the proposal, because it changes every consumer's retarget from a dependency bump into an import rewrite. It requires two edits in the **same** commit: `src/cue.mod/module.cue`'s `module:` line, and a `Release-As: X.0.0-alpha.1` footer forcing the version — `versioning: prerelease` advances the prerelease counter within a major and never crosses one on its own. `cue mod publish` refuses a tag whose major disagrees with the declared module path, so the two cannot land apart.

### Scenario: An absorbable break advances the prerelease counter

- **WHEN** `feat!:` commits reshape published definitions, no stable `vX.0.0` exists, and consumers can absorb the break by re-reading the same import path
- **THEN** the release is `vX.0.0-alpha.N+1`, the module path is unmoved, and consumers retarget by a dependency bump

### Scenario: An unabsorbable break bumps the module major

- **WHEN** a change redefines what an existing field means, refuses values every published artifact declares, or moves a derived identity consumers store
- **THEN** the module path moves to the next major, the version is forced to `X.0.0-alpha.1` by a `Release-As:` footer, and the proposal states the import-rewrite cost

### Scenario: The declared major and the tag cannot disagree

- **WHEN** a release is tagged at a major the `module:` line does not declare
- **THEN** `cue mod publish` refuses it, and the release fails rather than publishing a mislabelled artifact

### Scenario: Rollback across a major is an import rewrite

- **WHEN** a consumer needs to reverse a retarget that crossed a major
- **THEN** it restores the previous import path as well as the version pin, and the previous major stays resolvable indefinitely, because a published tag names fixed bytes permanently

## Requirement: A partial tag on the line is not a retarget target

A tag that carries only some of the changes a cut is defined to publish MUST NOT be retargeted to by any consumer. Publication makes a tag resolvable; it does not make it complete.

`v2.0.0-alpha.1` is exactly this case: it was published by the major bump and carries `core-identity-shape` alone, without the contract keying, platform surface or identity package. A resolvable partial tag is more hazardous than no tag, because nothing in the registry distinguishes it from a complete one.

### Scenario: A consumer re-pins to a partial alpha

- **WHEN** a consumer re-pins to an alpha published before every slice of the cut has landed
- **THEN** it compiles against an incomplete schema, and the failure surfaces as missing constructs rather than as a version error

## Requirement: The published schema is internally coherent before it is tagged

Before a release is cut, `SPEC.md` MUST describe one schema: an invariant stated in more than one section MUST be stated identically, category claims MUST agree with the sections they classify, every cross-reference MUST resolve to a name that exists, and no section MUST describe behaviour a landed change replaced.

Inventory checking is not coherence checking. `task spec:check` verifies that tracked constructs have sections and that sections name live constructs; it cannot detect two sections disagreeing.

### Scenario: A stale cross-reference blocks the cut

- **WHEN** a `SPEC.md` section refers to a field renamed or deleted by a landed change
- **THEN** the release is not cut until it is corrected, even though `task spec:check` passes

### Scenario: A design problem found during the pass is not resolved in the release

- **WHEN** the coherence pass surfaces a design inconsistency rather than an editorial one
- **THEN** it is raised as a new change, and the release waits

## Requirement: Every worked example evaluates against the shipped schema

Every illustrative shape in `SPEC.md`, in `docs/`, and in the authoring doc comments inside `src/*.cue` MUST be evaluated against the schema being published, not reviewed by reading.

A stale example in a normative document is a false statement about a published contract, and the stale ones look correct.

### Scenario: An example carrying a superseded shape is caught

- **WHEN** a `SPEC.md` example declares a module path in a form the current schema refuses
- **THEN** evaluation fails and the example is corrected before the tag is cut

## Requirement: The published artifact is verified to resolve

After publication, the released version MUST be verified by resolving it from a tree that did not build it and evaluating a minimal artifact in the new shape.

### Scenario: A scratch consumer compiles against the new release

- **WHEN** a fresh tree adds `opmodel.dev/core@v2` at the published version and evaluates a minimal `#Module`
- **THEN** it resolves and evaluates, confirming the artifact is complete as published rather than only as built

## Tag format and branch builds (applies to every CUE module class)

> **Verbatim from `core/docs/publishing.md ## Tag format`.**

## Tag format

Two formats, one per channel.

```text
Stable (main, cut by release-please):
  v<MAJOR>.<MINOR>.<PATCH>
  e.g. v0.4.0

Branch (every commit on a non-main branch):
  v<MAJOR>.<MINOR>.<PATCH>-0.dev.<commit_ct>.g<short_sha>
  e.g. v1.0.0-0.dev.1785961206.g6b10e87
```

The branch build shares the base version of the highest existing release and is
ranked below it by the leading `0.` — see [Why branch builds carry a leading
`0`](#why-branch-builds-carry-a-leading-0).

Where:

| Field | Source | Notes |
| --- | --- | --- |
| `MAJOR` | `cue.mod/module.cue` module suffix (`@v1`) | matches the published module identity |
| `MINOR`/`PATCH` | base version of the highest release tag for this major, stable or prerelease | the branch build shares the release channel's base so it can be ranked *below* it; falls back to `MAJOR.0.0` when the major has no release yet |
| `commit_ct` | `git show -s --format=%ct <SHA>` | committer Unix seconds, baked into the SHA — see Determinism |
| `short_sha` | `git rev-parse --short=7 <SHA>` | seven hex chars, prefixed with `g` |

The `g` prefix on the SHA mirrors `git describe`. It exists for one reason: a 7-char hex SHA can happen to be all digits (roughly 4% of commits). Without the prefix that segment would parse as numeric in SemVer 2.0, and numeric identifiers rank below alphanumeric ones at the same position — flipping sort order based on SHA character class. The `g` makes every SHA segment uniformly alphanumeric, so they always compare lexically.

> **Verbatim from `core/docs/publishing.md ## Why branch builds carry a leading `0``.**

## Why branch builds carry a leading `0`

The invariant: **a branch build must never be the version a query selects**, under `@vN`, `@vN.M`, or an explicit range that admits prereleases. Resolving any of those to an unreleased branch commit silently ships in-flight work to every consumer.

It is tempting to lean on Go/CUE's rule that `@vN` ignores prereleases when a stable version exists, and let branch builds preview the next minor. Two things defeat that:

1. **A major can live for a long time with no stable release.** `@v1` ships only `v1.0.0-alpha.N` today, so there is nothing for `@v1` to prefer and it must take the highest prerelease. `v1.0.0-dev.*` beats every `v1.0.0-alpha.N`, because prerelease identifiers compare lexically and `alpha` < `dev`. Moving the branch build to the next minor is *strictly worse*: `v1.1.0-dev.*` beats `v1.0.0-alpha.3` on the base version alone, before prerelease identifiers are consulted at all.
2. ~~**Range subscriptions deliberately admit prereleases.**~~ **Retired in `v2.0.0-alpha.3`** — a `#Platform` subscription now names one build as a scalar `version` and resolves nothing, so no query of that kind can select a branch build by accident. It is kept here struck through rather than deleted because it was a load-bearing half of the original argument: while platform filters were ranges that admitted prereleases, a next-minor branch build won any range whose top minor had no release of its own. The conclusion below stands on point 1 alone, and stands unchanged.

So the branch build shares the base version of the highest existing release and is ranked below it there. SemVer 2.0 §11.4.3 is the lever: *a numeric identifier always has lower precedence than an alphanumeric one at the same position*. Leading the prerelease with `0` puts every branch build under every named channel on that base:

```text
v1.0.0-0.dev.1785961206.g6b10e87  <  v1.0.0-alpha.1  <  v1.0.0
```

One rule, every phase, every query kind. `0` is a valid numeric identifier — the SemVer prohibition is on *leading* zeroes (`01`), which the registry rejects outright (see the validation table).

A branch build may still outrank an *older* release on a lower base — `v1.1.0-0.dev.*` is above `v1.0.0`. That is expected and harmless: resolution selects the maximum, and the maximum is always the newest release (`v1.1.0-alpha`), never the branch build.

The cost is that "track latest dev" has no range-based form: `@v1.0` resolves to the newest alpha, since branch builds now sort below it. Pinning an exact `-0.dev.` tag is the only way to follow a branch. That is the intended trade — an unreleased build should be opted into explicitly, never inherited by someone who wrote `@v1`.

> **Verbatim from `core/docs/publishing.md ## Consumer resolution`.**

## Consumer resolution

CUE's resolver (`cue mod get`, `cue mod tidy`) follows Go-module semantics: pre-release tags are excluded from `@latest` and major-only queries, but **included** when a query specifies the same `MAJOR.MINOR`.

Verified against CUE 0.16.1:

| Query | Resolves to |
| --- | --- |
| `cue mod get opmodel.dev/core@latest` | latest stable (e.g. `v0.3.0`) |
| `cue mod get opmodel.dev/core@v0` | latest stable |
| `cue mod tidy` (no pin) | latest stable |
| `cue mod get opmodel.dev/core@v0.4` | **highest release on v0.4** — branch builds sort below every named channel on that base, so they are never selected here |
| `cue mod get opmodel.dev/core@v0.4.0-0.dev.<ts>.g<sha>` | exact pin |

Platform subscriptions no longer resolve anything: since `v2.0.0-alpha.3` a `#Platform` names the catalog build it materializes as a scalar (`version: "1.0.0-alpha.7"`), so a branch build reaches a platform only by being written into it. The table above is therefore the whole of the selection surface — it governs `cue.mod` dependency resolution, and nothing else queries a range.

So two pin styles are blessed by this strategy:

```cue
// Track the release channel
deps: "opmodel.dev/core@v2": v: "v2.0.0-alpha.1"

// Follow a specific branch build — exact pin only, by design
deps: "opmodel.dev/core@v2": v: "v2.0.0-0.dev.1785961206.g6b10e87"
```

There is deliberately no range-based "track latest dev" pin. Consuming an unreleased build is an explicit act: query the OCI tag list, pick the tag, write it down. See [Why branch builds carry a leading `0`](#why-branch-builds-carry-a-leading-0).
