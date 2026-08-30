# Problem Statement: Module and Catalog Publishing

There is no OPM publish command, and the version an artifact ships under is decided by something that never reads it. This document lays out the observable current state and the gap; solutions belong in `02-design.md`.

## Current State

**There is no OPM publish command.** Neither `opm module publish` nor `opm catalog publish` exists. Every artifact in the registry today was pushed by `cue mod publish`, wrapped in a repo-local task that decides the version by its own rules.

For **modules**, that wrapper is `modules/Taskfile.yml`'s checksum-driven `publish` task. (This document originally called it `publish:smart`; corrected 2026-08-04: that is the task name in a deployment repository outside the workspace, named out of band, which runs the same pattern against Flux artifacts. `modules/` has `publish`, `publish:one` and `publish:dry`.) It computes a content checksum over each module's `.cue` files excluding `cue.mod/`, compares it against a stored checksum in `modules/versions.yml`, bumps the version recorded there on any difference, publishes at the bumped tag, and stores the new checksum. The module's own source is never read for a version and never written to.

For **catalogs**, the wrapper is `task publish VERSION=vX.Y.Z` in each catalog repo. It copies `src/` to a transient build directory, writes an `identity/version_override.cue` pinning a concrete SemVer into the copy, vets the copy, and publishes it. The committed tree resolves the version to a `0.0.0-dev` sentinel; the artifact carries the real value. As `catalog_opm/CLAUDE.md` puts it: "The source tree is never mutated, and publishing the dev sentinel is refused."

Dependency resolution at publish is CUE's. `cue.mod/local-module.cue` (the sanctioned dev-time mechanism for pointing a dependency at a local checkout) is stripped by CUE when the artifact is built, so the published artifact resolves against published dependencies regardless of what the author validated against.

The registry namespace is flat. Modules live at `opmodel.dev/modules/<name>`, alongside a test fixture at `opmodel.dev/library/testdata/modules/web-app` and a set of legacy `opmodel.dev/<name>/v1alpha1` paths. Catalogs live at `opmodel.dev/catalogs/<name>`. Nothing distinguishes a module path from a catalog path from a schema path except knowing which is which.

The CLI has no credential surface: no login command, no credential-helper handling, no token storage. It inherits whatever the CUE SDK's resolver finds in the ambient environment.

## Gap / Pain

**The version an artifact ships under is decided by something that never reads the artifact.** the checksum task derives a tag from a checksum diff, so the tag advances with every content change while whatever the source says about itself stays put. The result is measurable: `jellyfin` `v2.0.1` and `v2.0.2` both ship metadata claiming `2.0.0`, and `seerr` `v1.0.2` claims `1.0.0`. `versions.yml` is itself wrong on its own terms, recording `v2.1.0`/`v1.2.0` against highest published tags of `v2.0.2`/`v1.0.2`. Three answers to "what version is this", none of them authoritative.

**Publishing writes bytes into the artifact that do not exist in source.** The catalog flow is explicit about it: a transient file is generated into a copy of the tree. That is a coherent pattern when an artifact is a *build output*; a CUE module's artifact **is** its source, so the consequence is that a local checkout and its published self evaluate differently. Measured 2026-07-25 against a live registry: the same catalog resolves to `…/transformers/foo@0.0.0-dev` from a checkout and `…/transformers/foo@1.0.0` from the registry. Both trees `cue vet` clean.

**Publish accepts an artifact with no identity in it.** Measured 2026-07-26 (cue v0.17.1): `cue mod publish v1.2.0 --dry-run` succeeded on a tree whose identity fields were declared but unfilled. And `cue vet` *without* `-c` reports `some instances are incomplete` and **exits 0**, so a task that vets before publishing does not catch it either. Nothing between an unfinished tree and the registry.

**Publish is silent about a divergence it is in a position to name.** An author who used `local-module.cue` to develop against a local catalog validated their work against one set of bytes and published something that will resolve against another. CUE strips the file, so nothing in the artifact records that a replacement was in play, and nothing in the output names it. The one moment at which someone could be told "what you tested and what you shipped resolve differently" is the publish, and it passes in silence.

The dev loop compounds this. Measured (cue v0.17.1, live registry, three-link chain `instance → module → catalog` with each artifact carrying an origin marker): CUE honours `local-module.cue` only for the **main** module, so a replaced dependency's own `local-module.cue` is ignored. Replacing only the module yields local module bytes resolved against the **published** catalog, with nothing in the output naming the discarded replacement. The chain can be reconstructed by hand: a main-module `local-module.cue` with one entry per hop resolves every link locally, and `cue mod tidy` preserves the multi-entry file rather than pruning it. But the natural thing, putting the catalog replacement next to the module that depends on it, silently does nothing.

**A flat namespace has no owner.** The first publisher of a common name holds it permanently, nothing distinguishes a vendor's module from a third party's fork of it, and there is no path segment that tells tooling whether a given repository is a module, a catalog, or a schema. "Which of this module's dependencies are catalogs?" is asked constantly and currently answered by fetching and decoding each one.

**A pinned version does not name fixed bytes.** OCI registries treat tag immutability as opt-in configuration: ECR repositories are mutable by default, Harbor implements it as project-level rules. Package registries treat it as fundamental instead (Maven Central rejects redeployment of a release outright). CUE modules live in OCI registries, so OPM inherits the weaker default. If a tag can be overwritten under a consumer who has already pinned it, every downstream digest comparison silently checks against a moving target, and the mutable tag is a time-of-check-to-time-of-use vector in its own right.

## Concrete Example

Publishing `jellyfin` today:

```
$ cd modules && task publish
# 1. checksum modules/jellyfin/*.cue, excluding cue.mod/
# 2. differs from versions.yml → bump jellyfin: v2.0.1 → v2.0.2
# 3. cue mod publish v2.0.2
# 4. store the new checksum
```

Nothing in steps 1–4 opened `modules/jellyfin/module.cue` to see that it says `version: "2.0.0"`, and nothing wrote back to it. The artifact at `v2.0.2` claims to be `2.0.0`. Deploy it with the CLI and the `ModuleInstance` records `2.0.0`; hand it to the operator and the operator fetches `v2.0.0`, a different artifact, and reconciles it green forever.

Now suppose the author had been developing against a local catalog checkout:

```
modules/jellyfin/cue.mod/local-module.cue
    replaceWith: "opmodel.dev/catalogs/opm@v1": path: "../../catalog_opm/src"
```

`cue vet` passes, the module renders, everything looks right. `cue mod publish` strips the file. The published `v2.0.2` resolves against `opmodel.dev/catalogs/opm@v1.0.0-alpha.1` from the registry, different bytes from the ones that were validated, with no record anywhere that a substitution occurred.

## User Stories

- As an **application module author**, I want one command that publishes my module correctly, so that I do not have to know how a checksum in another repository decides my version. Today: publishing means understanding the checksum task, `versions.yml`, and `cue mod publish`, and the result is an artifact whose declared version is wrong.
- As a **catalog author**, I want to publish exactly the bytes I committed, so that what I tested is what my consumers evaluate. Today: publish copies my tree and injects a file into the copy, so the artifact has never existed on my disk.
- As a **platform team operator**, I want a pinned catalog version to name fixed bytes, so that a digest I recorded yesterday still means something today. Today: nothing prevents a tag from being overwritten, and nothing would tell me if it were.

## Why Existing Workarounds Fail

**A guard in the publish task is bypassable by construction.** `cue mod publish` exists, will keep working, and is what every artifact published to date used. A check that lives in a Taskfile protects only the people who run the Taskfile.

**A content checksum cannot decide a version.** It answers "did these bytes change", which is not the same question as "is this a patch, a minor, or a major". It also becomes self-referential the moment the version lives in the files being hashed: a pure version bump changes the checksum, so the detector starts reporting that the act of versioning is itself a change. Today's flow converges only because it stores the checksum *after* publishing; any flow that computes it before deciding the version oscillates.

**An external version file cannot make source and artifact agree**, because nothing in the flow writes back into the source the agreement is about. `versions.yml` is a third statement of the version, not a reconciliation of the other two.

**Documenting the local-override hazard does not remove it.** The divergence is invisible on both trees: the local one and the published one each `cue vet` clean. So there is no point at which a careful author would notice it unaided. Only the tool that performs the publish is positioned to see both sides.
