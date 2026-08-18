# Problem Statement — Documentation Architecture

OPM has no usable public documentation, and the reason is not that nobody wrote any. Documentation exists, in volume. It describes a version of OPM that has not existed since April.

## Current State

The public site (`opmodel.dev`) carries five pages. Three are section stubs, two were written on 2026-08-18 as a slice of enhancement 0010 (the catalog contract and the registry namespaces). The generated reference sections it advertises are empty: `task generate:cli` fails on a clean tree, and the site's disabled-theme condition currently renders no section to HTML at all.

The largest body of prose lives in `opm/docs`. Every file there was last touched 2026-04-21 and describes the deprecated v0 catalog line. It contains 121 references to `#ModuleRelease`, an artifact renamed by enhancement 0002. Every import path it teaches (`opmodel.dev/core/v1alpha1/module@v1`, `opmodel.dev/opm/v1alpha1/resources/workload@v1`) resolves to the frozen v0 catalog. Its `cli.md` documents an `opm release` command group that was removed with no alias. Its `operator.md` describes a `BundleRelease` type that does not exist. The `specs/` and `benchmarks/` trees its own `CONSTITUTION.md` and `CLAUDE.md` point at were deleted in January.

Meanwhile the material that *is* current sits in places a reader would never look. `cli/README.md` and `cli/QUICKSTART.md` are the best user-facing prose in the workspace and are the de-facto getting-started. `core/SPEC.md` carries roughly 700 lines of Rationale that explain, with dates and measurements, why the model is shaped as it is. Seventeen catalog transformers embed compile-verified worked examples. None of it is reachable from a documentation site.

## Gap / Pain

Four gaps, in descending order of how badly they hurt a newcomer.

**No conceptual documentation exists at all.** OPM asks a reader to hold four artifact types, four primitive kinds, two key namespaces, a contract-level ladder and a matching model before they can write anything that renders. A reference-only site leaves every reader reverse-engineering the model from field tables. The `core` survey identified seventeen concepts subtle enough that a reader gets them actively wrong without prose, led by the four version-shaped axes (module major, release SemVer, contract `apiVersion`, and core's own major), `fqn == modulePath` for artifacts but something entirely different on a primitive, and `matchLabels` versus `metadata.labels`.

**Documentation coverage is inverted against usage.** Measured in `catalog_opm`: blueprints, which are the first thing a module author picks and without which a component cannot render, have doc comments on 0 of 5 members. Abstraction resources have 1 of 11. Traits have 6 of 27. The raw `k8s-*` family, which no first-party module imports and which CI forbids the abstraction family from depending on, has 27 of 27. The generated `src/INDEX.md` faithfully reproduces this: its Description column is empty for exactly the members a reader needs, while 375 of roughly 460 rows are vendored Kubernetes types nobody should browse.

**Nothing tells a reader what stops them.** OPM enforces its rules across four distinct layers: CUE unification, the kernel at render, the publish gates, and pure convention. The gaps between those layers are where users get hurt, and no document distinguishes them. `SPEC.md` scatters the information through Rationale prose and is currently wrong in both directions: §6's layering rules are stated as MUSTs that nothing checks, while SPEC.md:31 still describes the publish gates as "shipped surface with no enforcement behind them", which stopped being true when the CLI's catalog-gates slice merged.

**Shipped hazards are undocumented.** `spec.prune` defaults to false, so the finalizer's default behaviour is to orphan every workload. A CLI-owned instance carries no hold at all, so `kubectl delete` on the CR destroys the only inventory record and orphans everything it tracked. This is current, shipped behaviour. It appears in no document a user would find.

## Concrete Example

A developer wants to package an application. They find `opm/docs/getting-started.md`, which is the only document with that name in the workspace.

It tells them to build the CLI from source (there are release binaries), then run `opm module init hello`. The command rejects the argument: since enhancement 0010, `init` takes a full module path, `opm mod init example.com/modules/my_app@v0`. They work that out. The scaffolded module now imports `opmodel.dev/core@v2`, but every example in the document they are following imports `opmodel.dev/core/v1alpha1/module@v1`, so nothing they copy compiles.

They persevere and write a component. It fails to render. The error names an FQN and says no transformer requires it. Nothing tells them the difference between "no transformer on this platform implements that contract" and "no matched transformer consumes this trait", which are different problems with different fixes. Nothing tells them that a bare container cannot render because `matchLabels` carries a required key that only a blueprint answers.

They give up on the guide and read the catalog. `src/INDEX.md` lists five blueprints with an empty description column for all five.

## User Stories

- As a **module author**, I want to know which blueprint to start from and which traits I may attach to it, so that my first component renders instead of failing on an unanswered matching key.
- As a **module author** whose render just failed, I want to map the error I got to the thing I did wrong, without reading kernel source.
- As a **platform engineer**, I want to know what happens to running workloads when I delete an instance, before I delete one.
- As a **platform engineer**, I want to know which catalog builds my platform can subscribe to and what a subscription commits me to.
- As a **catalog author**, I want to know what the publish gates will hold my catalog to, and which of my obligations are checked versus conventional.
- As someone **evaluating OPM**, I want to know what it does not do, so that I do not discover the absence of lifecycle hooks three weeks in.
- As an **embedder**, I want a kernel walkthrough that includes every mandatory step, so that following it produces working code.

## Why Existing Workarounds Fail

**Updating `opm/docs` in place fails** because the vocabulary drift is total rather than partial. The rename of Release to Instance, the replacement of Provider by Platform plus catalog subscriptions, the move from `v1alpha1` paths to `core@v2`, and the identity reshape each invalidate every example independently. What survives is the argument structure of three or four documents, not their content.

**Generating everything from source fails today** because generation faithfully reproduces the inverted coverage described above. A generated reference built from current doc comments produces empty pages for blueprints and most traits, which is worse than no page: it looks authoritative and says nothing.

**Publishing `SPEC.md` fails** because its audience is explicitly contributors evolving the schema, and it says so at line 7. Its Rationale sections, which carry the explanation a user needs, are dense with enhancement decision numbers, experiment paths and cross-repo file references that a public reader cannot resolve. It also documents unshipped state as first-class content, which is correct for its audience and misleading for anyone reading a MUST as a description of what the toolchain does.

**Pointing readers at `cli/README.md` fails** as a general answer because it is scoped to the CLI. It happens to carry the only written account of owner semantics and the handoff gates, which is itself a symptom: load-bearing cross-cutting behaviour documented in one tool's README because there was nowhere else to put it.
