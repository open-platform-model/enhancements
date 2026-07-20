# Problem Statement — OPM Module Publishing Workflow

This document answers the question: "Why does this enhancement need to exist?" Lead with observable facts. Reference existing code paths and definitions so readers can verify the claims. Do not propose solutions here — that belongs in `02-design.md`.

## Current State

An OPM module ends up carrying four independently-authored coordinates:

- **OPM metadata identity** — `metadata.modulePath` + `metadata.name` + `metadata.version`, set inside the module body and typed by `core`'s `#Module` (`#ModulePathType`, `#NameType`, `#VersionType`). `metadata.name` is kebab-case (RFC 1123 DNS label).
- **CUE registry module path** — the `module:` line in the module's `cue.mod/module.cue` (e.g. `module: "opmodel.dev/modules/metallb@v0"`). This is the only address CUE uses to fetch or import the module.
- **CUE package name** — the `package` clause in the module's `.cue` files. CUE resolves an import to the package whose name matches the last path segment, unless qualified as `import alias "path:pkgName"`.
- **The artifact's release tag** — the version the module is actually published under. There is no `opm module publish`; publishing today is raw `cue mod publish <version>`, and in the `modules` repo the tag comes from a *separate file*: `modules/Taskfile.yml` reads `version=$(yq ".$module.version" "$VERSION_FILE")` from `versions.yml`, then runs `cue mod publish "$new_version"`.

Nothing in the schema or tooling binds these four together. A module author writes `metadata.name` and `metadata.version` in the body and, separately, picks a registry path and package name in `cue.mod` and the `package` clauses, while the release tag is decided by yet another mechanism.

A module is acquired at runtime by an explicit registry reference: `Kernel.LoadModuleFromRegistry(modPath, version)` (`library/opm/helper/loader/registry`). The resulting `*module.Module` (`library/opm/module/module.go`) keeps only the decoded `metadata` and the built `cue.Value` — it does **not** retain the `modPath@version` the caller fetched it by.

## Gap / Pain

Because the registry path is author-chosen and not retained on the loaded module, **code holding a `*module.Module` cannot reconstruct the reference needed to import that module again.** The single-build render path (`library`'s `simplify-render-single-build`) builds a release by synthesizing a CUE package that does `import "<module path>"` and `#module: <import>`. To write that import it must know the module's registry path — and the only fact it has is `metadata`, from which the path is not derivable.

Attempting to derive the path as `metadata.modulePath + "/" + metadata.name` fails for real modules: the path leaf is sometimes the kebab name, sometimes a snake-cased name, and the package name is independently sometimes a third spelling. There is no deterministic rule, so the render path either resolves the wrong address (`module not found`) or cannot be made correct for a whole class of modules.

This blocks the convergence the render change exists to deliver (one construction mechanism for both the synthesized-CR path and the authored-`instance.cue` path), and more broadly there is no enforced, machine-checkable relationship between a module's identity and where it lives — so the ecosystem cannot rely on "given a module's metadata, here is how to import it."

### The same gap in the version dimension

`metadata.version` has the identical problem and a worse failure mode, because it fails silently.

Nothing checks that the version declared inside a module equals the version of the artifact carrying it. Publish a module as `v0.2.0` without bumping `metadata.version` from `0.1.3` and the artifact at tag `v0.2.0` internally claims to be `0.1.3`. Every consumer that trusts the metadata is then wrong about what it is holding.

That matters because `metadata.version` is load-bearing in three separate places:

1. **Identity.** `fqn` → `module.uuid` (`SHA1(OPMNamespace, fqn)`) → `instance.uuid` → the `module-instance.opmodel.dev/uuid` label stamped on **every rendered resource**, which the operator's prune guard and the CLI's inventory both match on.
2. **The deployment record.** The CLI derives `ModuleInstance.spec.module.version` from it — the reference the *operator* later resolves from the registry.
3. **The synthesized import.** `library/opm/helper/synth/render.go:62` builds the instance package's import from `major(in.Module.Metadata.Version)`, so a stale version can select the wrong major line entirely.

The resulting failure is silent rather than loud: the CLI deploys the artifact it fetched (`v0.2.0`) but records `spec.module.version: v0.1.3`. After a handoff the operator reconciles `v0.1.3` — a *different artifact* — from then on, with `Ready: True` and every gate green. The cluster is pinned to an older module than the one the operator's own user deployed, and nothing reports it.

### Evidence: a derivable rule is not the same as an enforced one

This enhancement's own `schemas/target.cue` has always specified `depVersion: "v" + version` — the correct v-prefixed form for a CUE registry reference. The implementation that shipped in enhancement 0006's C1 slice (`cli/pkg/module/module.go` `CanonicalModuleRef`) returned `metadata.version` **verbatim**, without the prefix.

CUE rejects a bare `0.1.3` as a malformed module version, and the operator passes `spec.module.version` straight to the registry loader with no normalization of its own. So *every* `ModuleInstance` the CLI had ever written was unresolvable by the operator — the shared-record premise of enhancement 0006 did not actually hold. It went unnoticed because the CLI never reads that field back, the operator was only ever tested against hand-written YAML fixtures (where a human naturally types `v0.1.2`), and the unit test asserted the bare form as expected, actively defending the defect. It surfaced only when `opm instance handoff` became the first operation that had to re-read and resolve what the CLI itself had written (fixed 2026-07-20).

The lesson is the premise of this enhancement: a mapping that is merely *derivable by convention* drifts from its implementations. It has to be stated once and checked where it is produced **and** where it is consumed.

## Concrete Example

Three modules in the workspace, each with a different relationship between the three names:

| Module | `metadata.name` | `metadata.modulePath` | `cue.mod` registry path | `package` | `metadata.version` vs published tag | `modulePath/name` matches path? |
| --- | --- | --- | --- | --- | --- | --- |
| metallb | `metallb` | `opmodel.dev/modules` | `opmodel.dev/modules/metallb@v0` | `metallb` | unchecked | yes |
| zot | `zot-registry-ttl` | `opmodel.dev/modules` | `opmodel.dev/modules/zot_registry_ttl@v0` | `zot_registry_ttl` | unchecked | **no** (hyphen vs underscore) |
| web-app | `web-app` | `opmodel.dev/library/testdata/modules` | `…/modules/web-app@v1` | `web_app` | **`0.1.0` under an `@v1` path** | yes for path, **no** for package |

The `web-app` row shows both failure modes in one module: its package name disagrees with its path leaf, *and* its declared `0.1.0` is inconsistent with the `@v1` major line it is published under. Enhancement 0006's C2 slice later confirmed the practical consequence — `library/testdata/modules/web_app` "violates the nameSnakeCase path convention (kebab leaf) and cannot synthesize."

The `metadata.version` column reads "unchecked" rather than "yes" deliberately: nothing verifies it, so its correctness today is a property of author diligence, not of the system.

Deriving the import as `metadata.modulePath/metadata.name@vMAJOR(version)`:

- metallb → `opmodel.dev/modules/metallb@v0` ✅ resolves.
- zot → `opmodel.dev/modules/zot-registry-ttl@v0` ❌ — the real artifact is at `…/zot_registry_ttl@v0`. `module not found`.
- web-app → `…/web-app@v0` (path leaf is right) but the package is `web_app`, so a bare import that assumes the leaf is the package name needs an explicit `:web_app` qualifier.

So neither "use `name`" nor "use a single fixed transform" reconstructs every module's address, and the package-name spelling is a third independent variable.

## User Stories

- As an **application module author**, I want a single rule for what registry path and package name my module must use given its `metadata.name`, so that publishing is mechanical and consumers can find my module. Today: the path and package are free-form, so I can publish a module that no tooling can import by metadata.
- As a **kernel contributor** (library), I want to turn a loaded `*module.Module` into the exact registry reference it was published under, so that the render path can import it in a single build. Today: the reference is discarded at load and not derivable from metadata, so the import is unreconstructable.
- As a **platform team operator**, I want `opm publish` to reject a module whose registry coordinates don't match its identity, so that a malformed module never reaches the registry. Today: nothing checks the relationship, so drift ships silently and only surfaces as a render-time `field not allowed` / `module not found` much later.
- As a **cluster operator handing a release to the operator**, I want to trust that `metadata.version` names the artifact I am actually running, so that ownership transfer does not silently re-pin my cluster to a different module version. Today: nothing binds the two, and a stale stamp survives every existing gate.
- As a **consumer of a third-party module** published without OPM tooling, I want a legible error at fetch time when its metadata disagrees with its coordinates, rather than a wrong-but-plausible render. Today: the disagreement is invisible until something much further downstream misbehaves.

## Why Existing Workarounds Fail

The render path's only metadata-based workaround — guessing the path from `modulePath` + `name` (optionally snake-casing it) — is provably wrong for some real modules (zot needs the snake form, web-app needs the hyphen form) and cannot be made right by any single transform, because the registry path lives in `cue.mod/module.cue`, a file the schema and metadata cannot see or constrain. Threading the reference manually through every `synth.Instance` caller pushes a correctness burden onto callers and still leaves third-party modules unconstrained. The durable fix is a *convention* on what the registry coordinates must be — derivable from metadata and enforced where modules are published — rather than a guess applied where they are consumed.
