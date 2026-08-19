# Experiment 02: platform-authority-mvs

Status: Concluded

## Hypothesis

In a single CUE build that contains both a consumer `#Module` and the platform, the platform decides which catalog build is executed, and a consumer module's own `cue.mod` pin cannot override it.

This is the executable form of the question raised against `02-design.md`'s single-build section: if the render step collapses into one build, does enhancement 0010 D14's property ("the platform file *is* the resolution") survive, or does dependency resolution hand a consumer module the power to choose which transformer bytes run? The second reading would be a privilege boundary on a multi-tenant `opm-operator`, not merely a versioning preference.

The experiment also carries the proposed platform shape, because the question is not answerable against today's shape: a platform that names a catalog by a `version` string never participates in dependency resolution at all.

## Setup

Three modules on disk, each with its own `cue.mod`, assembled into one build.

| Directory | Role | Notes |
| --- | --- | --- |
| `platform/` | the platform, under the **proposed** schema | pins `catalogs/opm@v2.0.0-alpha.3` in its own `cue.mod`; constant in every case |
| `consumer/` | a minimal real `#Module` | its catalog pin is the matrix variable |
| `render/` | the kernel-generated render module | main module of the build; its `cue.mod` is the second variable |

**The proposed schema** lives in `platform/schema.cue`, copied from `core/src/platform.cue` @ `v2.0.0-alpha.4` and modified at exactly one place:

```
core today                          this experiment
---------------------------------   ---------------------------------
#registry: [Path]: #Subscription    #registry: [Path]: #CatalogEntry
  enable:   bool | *true              enable:        bool | *true
  version!: #VersionType              #transformers: #TransformerMap
```

The `version!` scalar is gone rather than optional, and the catalog arrives by `import`. It is redefined locally rather than unified onto core's `#Platform` because core's `#Subscription` is closed around `enable` + `version!`, so the proposal is inexpressible as an extension of it. That is itself informative: this is a core schema change, not an authoring convention. `#composedTransformers` becomes a fold over enabled registry entries rather than a kernel-filled slot, which is `library/opm/materialize/index.go` written as four lines of CUE.

**The consumer** is deliberately minimal. The claim is about which version a build *resolves*, not about rendering, so the module carries the smallest component that still makes the catalog a genuine import: the `config` component copied verbatim from `library/testdata/modules/web_app/components.cue`.

**Two readout packages** inside the render module:

- `render/probe/` imports **only the platform**, which is what a real kernel-generated glue imports. It stays evaluable when the consumer fails to build under skew.
- `render/full/` also imports the consumer, so the same question can be asked of a build where the consumer participates directly, and so skew shows up as a build failure rather than a silently different answer.

**Three modes** for the render module, which is where the mechanism lives:

| Mode | `render/cue.mod/module.cue` | `cue.mod/local-module.cue` |
| --- | --- | --- |
| `pinned` | lists `catalogs/opm@v2` at the platform's version | replaces the two local modules only |
| `unpinned` | does **not** list `catalogs/opm@v2` | replaces the two local modules only |
| `replaced` | lists it, as `pinned` | additionally directory-replaces `catalogs/opm@v2` onto the platform's extracted build |

**Deviation from the copy-never-reference rule, stated deliberately**, on the same grounds experiment 01 recorded: `opmodel.dev/core@v2.0.0-alpha.4` and `opmodel.dev/catalogs/opm@v2.0.0-alpha.{2,3,4}` are resolved from the registry rather than vendored. They are exact published versions, so they are immutable and cannot drift, and an experiment about *dependency resolution* cannot vendor away the dependency graph it exists to measure.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
./run.sh
```

Pinned to `cue v0.17.1`. `replaceWith` requires language version `v0.17.0` or later.

`run.sh` assembles every case in a scratch copy under `_out/` and mutates nothing in this directory. Per-case trees and full-build errors are left under `_out/` for inspection.

## Outcome

**Hypothesis held, but conditionally, and the condition is the finding.**

```
platform module pins catalogs/opm@2.0.0-alpha.3 in every case

CONSUMER-PIN       MODE       RESOLVED         AUTHORITY  CONSUMER-SEES    FULL-VET  TRANSFORMER-BYTES
2.0.0-alpha.3      pinned     2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.3      unpinned   2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.3      replaced   2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.4      pinned     2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.4      unpinned   2.0.0-alpha.4    no         2.0.0-alpha.4    ok        deployment-transformer@2.0.0-alpha.4
2.0.0-alpha.4      replaced   2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.2      pinned     2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.2      unpinned   2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
2.0.0-alpha.2      replaced   2.0.0-alpha.3    YES        2.0.0-alpha.3    ok        deployment-transformer@2.0.0-alpha.3
```

`TRANSFORMER-BYTES` is the load-bearing column. A `#ComponentTransformer`'s FQN carries the SemVer of the catalog build it shipped in (`#ImplFQNType`, `core/src/types.cue`), so it names which bytes would execute without trusting any metadata field.

### Minimum Version Selection does not run at load time

The premise the question was built on is wrong, and the correction is the experiment's main result. CUE resolves an import by first consulting the **main module's own dependency list**, and only falls back to the full module graph, where maximum-version selection applies, for paths the main module does not list:

```go
// cuelang.org/go@v0.17.1 internal/mod/modpkgload/import.go:93-98
// Note: mg is nil the first time around the loop.
if mg == nil {
    v, ok = pkgs.requirements.RootSelected(prefixPath)
} else {
    v, ok = mg.Selected(prefixPath), true
}
```

`RootSelected` returns `maxRootVersion[mpath]`, the main module's declared version. MVS is what `cue mod tidy` computes when it *writes* a dependency list; it is not re-derived when a build reads one. So a committed `cue.mod` is a resolution, not a floor.

The consequence for this design is direct: **the kernel-generated render module's `cue.mod` is authoritative**, and a consumer module's pin is inert for every path that file lists. Row 4 is the proof, and it is the case the question was actually about: the consumer demands `alpha.4`, the render module lists `alpha.3`, and `alpha.3` is what executes.

### The failure mode is omission, not override

Authority is lost in exactly one cell of the matrix: `unpinned` + a consumer pinning **higher**. Drop the catalog from the render module's roots and the graph answers instead, maximum-version selection applies across every requirement, and the consumer's `alpha.4` becomes the transformer bytes the platform executes. A consumer pinning *lower* is harmless, because the maximum is still the platform's.

This matters because omission is the natural default. A real render glue imports the instance and the platform; it has no reason to import the catalog, so nothing forces the catalog onto the main module's dependency list. Authority is therefore something the kernel must **write down deliberately**, not something it inherits.

A second, subtler form of the same trap: a **default major version** is honoured only for a path that is a root dependency. The catalog imports `cue.dev/x/k8s.io/...` with no major suffix and declares the default in its own `cue.mod`, which is consulted only while the catalog is itself a root. Dropping the catalog from the roots broke that import until the render module listed `cue.dev/x/k8s.io@v0` itself. The generated render module therefore needs the complete tidied dependency set, not just the OPM paths.

### Directory replacement works, and is not needed for authority

`replaced` behaves identically to `pinned` in every row. The mechanism is real (`cue/load/config.go:581-620` installs a replacing registry from `cue.mod/local-module.cue`, and `modpkgload/replace.go:88-97` serves a directory replacement without consulting a registry at all, whatever version was selected), and `replaceWith` is refused in published modules by `mod/modfile/schema.cue`'s `#Strict`, which makes it structurally a build-local, kernel-owned override.

But its role is narrower than expected. It is what brings **unpublished local modules** (the synthesized instance, the generated platform) into a build. It is not what confers platform authority, because listing the path already does that.

### Skew is silent

In every `pinned` row the consumer is evaluated against a catalog its own `cue.mod` does not name, and `cue vet -c ./full` exits 0 with no diagnostic. Row 4 downgrades a consumer that demanded `alpha.4` to `alpha.3` and says nothing. CUE will not report this; if OPM wants a "the module was authored against a build this platform does not run" diagnostic, the kernel has to compute it, which is the `_versionsAgree` check experiment 01 sketched, promoted from illustration to load-bearing.

### Three mechanical findings worth carrying

1. **`cue.mod/local-module.cue` is the complete main-module dependency view, not a patch.** `cue/load/config.go:581` makes it take precedence over `module.cue`'s deps wholesale, so hand-writing only the replaced entries silently drops every other dependency and the build fails with confusing "cannot find package" errors. Generate it with `cue mod edit --replace`, which writes the full set.
2. **`v: null` does not work in `v0.17.1`**, despite `mod/modfile/schema.cue` documenting it for a replace-only entry: both `cue mod edit` and the loader fail with `cannot decode into modFile struct: cannot use value null (type null) as string`. A placeholder version is required, and it is inert because a directory replacement never consults a registry.
3. **A dependency listed but not imported still participates in graph expansion.** Before the local modules were replaced in, an unimported `consumer@v0.0.1` entry failed the build with `cannot expand module graph: module not found`. The kernel cannot make a module's requirements inert by declining to import it; it makes them inert by listing the path itself.
