# Problem Statement — OPM Module Publishing Workflow

This document answers the question: "Why does this enhancement need to exist?" Lead with observable facts. Reference existing code paths and definitions so readers can verify the claims. Do not propose solutions here — that belongs in `02-design.md`.

## Current State

An OPM module ends up carrying three independently-authored names:

- **OPM metadata identity** — `metadata.modulePath` + `metadata.name` + `metadata.version`, set inside the module body and typed by `core`'s `#Module` (`#ModulePathType`, `#NameType`, `#VersionType`). `metadata.name` is kebab-case (RFC 1123 DNS label).
- **CUE registry module path** — the `module:` line in the module's `cue.mod/module.cue` (e.g. `module: "opmodel.dev/modules/metallb@v0"`). This is the only address CUE uses to fetch or import the module.
- **CUE package name** — the `package` clause in the module's `.cue` files. CUE resolves an import to the package whose name matches the last path segment, unless qualified as `import alias "path:pkgName"`.

Nothing in the schema or tooling binds these three together. A module author writes `metadata.name` in the body and, separately, picks a registry path and package name in `cue.mod` and the `package` clauses.

A module is acquired at runtime by an explicit registry reference: `Kernel.LoadModuleFromRegistry(modPath, version)` (`library/opm/helper/loader/registry`). The resulting `*module.Module` (`library/opm/module/module.go`) keeps only the decoded `metadata` and the built `cue.Value` — it does **not** retain the `modPath@version` the caller fetched it by.

## Gap / Pain

Because the registry path is author-chosen and not retained on the loaded module, **code holding a `*module.Module` cannot reconstruct the reference needed to import that module again.** The single-build render path (`library`'s `simplify-render-single-build`) builds a release by synthesizing a CUE package that does `import "<module path>"` and `#module: <import>`. To write that import it must know the module's registry path — and the only fact it has is `metadata`, from which the path is not derivable.

Attempting to derive the path as `metadata.modulePath + "/" + metadata.name` fails for real modules: the path leaf is sometimes the kebab name, sometimes a snake-cased name, and the package name is independently sometimes a third spelling. There is no deterministic rule, so the render path either resolves the wrong address (`module not found`) or cannot be made correct for a whole class of modules.

This blocks the convergence the render change exists to deliver (one construction mechanism for both the synthesized-CR path and the authored-`release.cue` path), and more broadly there is no enforced, machine-checkable relationship between a module's identity and where it lives — so the ecosystem cannot rely on "given a module's metadata, here is how to import it."

## Concrete Example

Three modules in the workspace, each with a different relationship between the three names:

| Module | `metadata.name` | `metadata.modulePath` | `cue.mod` registry path | `package` | `modulePath/name` matches path? |
| --- | --- | --- | --- | --- | --- |
| metallb | `metallb` | `opmodel.dev/modules` | `opmodel.dev/modules/metallb@v0` | `metallb` | yes |
| zot | `zot-registry-ttl` | `opmodel.dev/modules` | `opmodel.dev/modules/zot_registry_ttl@v0` | `zot_registry_ttl` | **no** (hyphen vs underscore) |
| web-app | `web-app` | `opmodel.dev/library/testdata/modules` | `…/modules/web-app@v1` | `web_app` | yes for path, **no** for package |

Deriving the import as `metadata.modulePath/metadata.name@vMAJOR(version)`:

- metallb → `opmodel.dev/modules/metallb@v0` ✅ resolves.
- zot → `opmodel.dev/modules/zot-registry-ttl@v0` ❌ — the real artifact is at `…/zot_registry_ttl@v0`. `module not found`.
- web-app → `…/web-app@v0` (path leaf is right) but the package is `web_app`, so a bare import that assumes the leaf is the package name needs an explicit `:web_app` qualifier.

So neither "use `name`" nor "use a single fixed transform" reconstructs every module's address, and the package-name spelling is a third independent variable.

## User Stories

- As an **application module author**, I want a single rule for what registry path and package name my module must use given its `metadata.name`, so that publishing is mechanical and consumers can find my module. Today: the path and package are free-form, so I can publish a module that no tooling can import by metadata.
- As a **kernel contributor** (library), I want to turn a loaded `*module.Module` into the exact registry reference it was published under, so that the render path can import it in a single build. Today: the reference is discarded at load and not derivable from metadata, so the import is unreconstructable.
- As a **platform team operator**, I want `opm publish` to reject a module whose registry coordinates don't match its identity, so that a malformed module never reaches the registry. Today: nothing checks the relationship, so drift ships silently and only surfaces as a render-time `field not allowed` / `module not found` much later.

## Why Existing Workarounds Fail

The render path's only metadata-based workaround — guessing the path from `modulePath` + `name` (optionally snake-casing it) — is provably wrong for some real modules (zot needs the snake form, web-app needs the hyphen form) and cannot be made right by any single transform, because the registry path lives in `cue.mod/module.cue`, a file the schema and metadata cannot see or constrain. Threading the reference manually through every `synth.Release` caller pushes a correctness burden onto callers and still leaves third-party modules unconstrained. The durable fix is a *convention* on what the registry coordinates must be — derivable from metadata and enforced where modules are published — rather than a guess applied where they are consumed.
