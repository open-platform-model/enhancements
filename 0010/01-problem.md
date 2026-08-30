# Problem Statement: Module and Catalog Identity

## Current State

An OPM artifact states its identity in more places than one, and nothing binds them together.

A **module** declares three metadata fields (`core/src/module.cue:12-22`):

- `metadata.modulePath`: a bare prefix, e.g. `opmodel.dev/modules`
- `metadata.name`: kebab-case, e.g. `jellyfin`
- `metadata.version`: a hand-typed SemVer, e.g. `2.0.0`

Separately, the module's CUE module path lives in `cue.mod/module.cue` (`opmodel.dev/modules/jellyfin@v2`), its CUE package name is whatever the `package` clause says, and the tag the artifact is actually published under is chosen by whatever drives the publish. Four independent statements of one identity.

Those metadata fields are not decorative. `core/src/module.cue:23-26` computes:

```
fqn:  "\(modulePath)/\(name):\(version)"
uuid: SHA1(OPMNamespace, fqn)
```

and `uuid` feeds `instance.uuid`, which is stamped as `module-instance.opmodel.dev/uuid` on every rendered resource. The declared version is therefore part of the identity of every object OPM applies to a cluster.

A **catalog** works differently. `#Catalog.metadata` is `modulePath` + `version` with no `name` (`core/src/catalog.cue:60-64`), and its identity is supplied by a sibling `identity/` subpackage that resources, traits, and transformers import to compute their own FQNs (`catalog_opm/src/resources/configmap.cue:4`). The committed tree resolves `identity.Version` to a `0.0.0-dev` sentinel; `task publish VERSION=vX.Y.Z` copies `src/` to a transient build directory, writes an `identity/version_override.cue` pinning the real value, and publishes the copy.

Every primitive interpolates that version into its own FQN (`core/src/resource.cue:18` is `fqn: "\(modulePath)/\(name)@\(version)"`), and `#Catalog`'s pattern constraint (`core/src/catalog.cue:70-76`) stamps the catalog's version onto every transformer it ships.

Primitive FQNs are the matcher's key space: `library/opm/compile/execute.go` looks a component's demanded FQN up in the platform's composed transformer map, and a miss is `no matching transformer`.

## Gap / Pain

**A declared version drifts from the artifact carrying it, and the drift is the normal output of the flow.** Artifacts pulled from the workspace registry and read byte-for-byte (2026-07-25) show `jellyfin` `v2.0.1` and `v2.0.2` both carrying `metadata.version: "2.0.0"`, and `seerr` `v1.0.2` carrying `1.0.0`. Only the `.0` of each minor line is honest.

The mechanism is `modules/Taskfile.yml`'s `publish:smart`: it checksums each module's `.cue` files, bumps a version in a separate `versions.yml` on any difference, publishes at the bumped tag, and never reads or writes `metadata.version`. The declared version is structurally frozen at whatever was last hand-typed while the tag advances with every content change.

The consequence is silent rather than loud. All three `jellyfin` artifacts compute one `fqn` and therefore one `module.uuid`, so instances of `v2.0.2` are identity-indistinguishable from instances of `v2.0.0`. A CLI deployment of `v2.0.2` writes `spec.module.version: 2.0.0` into the `ModuleInstance`, and after a handoff the operator resolves that coordinate to a real, older, cleanly-reconciling artifact, indefinitely, with `Ready=True` and every gate green.

**Fixing that drift would activate a worse failure.** Because `fqn` interpolates `version`, a version that genuinely moves changes `module.uuid` → `instance.uuid` → the owner label on every rendered resource. `opm-operator/internal/reconcile/moduleinstance.go:308` repopulates `Status.InstanceUUID` from each new render, and `internal/apply/prune.go:107` **skips** any delete whose live label disagrees with that owner UUID. So a module whose version moved on upgrade would silently orphan everything the new version removed. The drift has been masking this the entire time: the declared version never moved, so the UUID never moved.

**A platform supplies one catalog build, so a module built against any other one misses.** A module built against `catalog@1.0.0-alpha.2` demands `…/resources/config-maps@1.0.0-alpha.2`; a platform whose subscription resolved `1.1.0` supplies only `…/resources/config-maps@1.1.0`. No key matches. The symptom is `no matching transformer`, which names neither the catalog nor the version at fault. This has already been observed in the workspace (opm-operator e2e, fixtures at `@v1-alpha` against a platform range at `@v0`).

The observable failure is not in dispute; where it comes from is, and the two candidate causes lead to opposite designs. It is **not** that the version sits in the key. `library` already pulls *every* survivor of a subscription filter (`materialize/filter.go:43-100`) and indexes each as its own build, and `materialize/index.go:57-64` records the resulting invariant: distinct versions produce distinct FQNs, so two builds of one catalog never collide. A platform whose subscription covers both builds therefore supplies both key spaces, and both modules match.

What actually fails is the **default**: an unfiltered subscription resolves `highestStable(published)` (`filter.go:43-47`) and materializes exactly one build, and against today's prerelease-only catalogs the obvious range (`>=1.0.0 <2.0.0`) selects none at all, because Masterminds constraints exclude prereleases unless the constraint carries one. This is a subscription-selection defect wearing a keying defect's symptoms. So the fix is to widen what a subscription materializes rather than to narrow what a key carries.

**Local and published evaluation of the same catalog are guaranteed to disagree.** Measured 2026-07-25 against a live registry: a catalog published through the stamping flow resolves to `…/transformers/foo@0.0.0-dev` from a local checkout and `…/transformers/foo@1.0.0` from the registry. Both trees `cue vet` clean, so only a cross-tree comparison surfaces the divergence. `cue.mod/local-module.cue`'s `replaceWith` onto a catalog checkout is a sanctioned development workflow, so the divergence is reachable in ordinary use, not just in theory. A catalog with a committed concrete version yields byte-identical FQNs from both.

**The registry address is not recoverable from a loaded artifact.** `metadata.modulePath` is a prefix and the path leaf is a snake-cased projection of `name`, neither of which is bound to the `module:` line in `cue.mod`. In practice they diverge: a module named `zot-registry-ttl` is published at `…/zot_registry_ttl`; `web-app` is published at `…/web-app@v1` with package `web_app` while declaring version `0.1.0`. Code holding a `*module.Module` cannot reconstruct the reference needed to import it.

**One documented mechanism does not exist.** `core/src/catalog.cue:63` declares `version!: #VersionType | *"0.0.0-dev"` and `core/SPEC.md:576` describes the default as a source-tree convenience. Measured: a required field's disjunction default never applies. The requirement wins. The dev-time behaviour attributed to that line actually comes from `identity.Version`, a plain field whose default does apply. The schema line and the SPEC paragraph describe a mechanism that is not in effect.

## Concrete Example

`modules/jellyfin` today, read from four files:

```
modules/jellyfin/module.cue
    metadata: modulePath: "opmodel.dev/modules"     # prefix only
    metadata: name:       "jellyfin"
    metadata: version:    "2.0.0"                   # hand-typed, last touched at 2.0.0

modules/jellyfin/cue.mod/module.cue
    module: "opmodel.dev/modules/jellyfin@v2"       # the real address
    deps:   "opmodel.dev/catalogs/opm@v1": v: "v1.0.0-alpha.1"

modules/versions.yml
    jellyfin: version: v2.1.0                       # a third answer

registry (highest tag actually published)
    v2.0.2                                          # a fourth
```

The artifact at `v2.0.2` computes `fqn: "opmodel.dev/modules/jellyfin:2.0.0"`, so it is UUID-identical to the artifact at `v2.0.0`. Deploy it with the CLI and the `ModuleInstance` records `2.0.0`. Hand it to the operator and the operator fetches `v2.0.0`, a different artifact, reconciling green forever.

Meanwhile the module's components demand `opmodel.dev/catalogs/opm/resources/config-maps@1.0.0-alpha.1`, because that is the catalog its `cue.mod` pinned. Point it at a platform whose subscription resolved `v1.0.0-alpha.2` and every one of those keys misses.

## User Stories

- As an **application module author**, I want the version I ship to be the version consumers get, so that a bug report names an artifact I can find. Today: the version in my source is whatever I last typed, the tag is chosen by a checksum in another repo, and the two have not agreed since the `.0` release.
- As a **platform team operator**, I want to upgrade a catalog by a minor version without breaking the modules installed on my platform, so that catalog releases are routine. Today my subscription materializes one build. The moment I take a newer one, every module built against the old one fails with `no matching transformer`, and I must rebuild the whole fleet in lockstep. I also want the reverse guarantee, which nothing offers today: that publishing a catalog build does not change what an already-installed module renders.
- As a **catalog author**, I want my local checkout to evaluate the way the published artifact will, so that what I test is what I ship. Today: my committed tree resolves every FQN against a `0.0.0-dev` sentinel that only publish replaces, and both trees vet clean, so nothing tells me they differ.

## Why Existing Workarounds Fail

**An external version registry cannot make source and artifact agree.** `modules/versions.yml` holds the version the publish flow uses, but nothing in that flow writes back into the source the invariant is about. It is a third statement of the version, not a reconciliation of the first two. And it is currently wrong on its own terms: it claims `v2.1.0`/`v1.2.0` against highest published tags of `v2.0.2`/`v1.0.2`.

**A CUE-expressed guard against the placeholder cannot be written.** Measured: a `!= "0.0.0-dev"` constraint does not reject the sentinel: it eliminates the default branch and leaves the value *incomplete*, so it fires during ordinary development and reports an incompleteness error rather than a missing stamp. CUE has no publish-time to condition on.

**A guard in the publish task is bypassable.** `cue mod publish` exists, keeps working, and is what every artifact published to date used. Any check that lives only in a task or a CI job gives a *consumer* nothing to rely on.

**Rebuilding every module on every catalog release is the current answer to catalog skew, and it does not scale past one publisher.** It requires the whole fleet to be rebuilt and republished in lockstep with a catalog patch release, and it is unavailable to anyone consuming a catalog they do not own.
