# 11-cross-catalog-import — #Platform Redesign Umbrella

Status: Concluded

Pins: D16 (cross-catalog primitive references as a supported pattern)

## Hypothesis

A transformer in catalog A referencing a resource owned by catalog B via standard CUE import:

1. **Both catalogs present** (`both_subscribed/` scenario) → resolves cleanly; catalog A's `requiredResources` map contains catalog B's resource value keyed by its concrete FQN.
2. **Catalog B physically absent** (`b_missing/` scenario) → fails at CUE evaluation with `cannot find package "..."` / `cannot find module providing package ...` error. The error names the offending import line (`foo_transformer.cue:12:2`) and the file that triggered the resolution (`catalog.cue:9:2`). This is exactly the failure mode the kernel can wrap as a `MaterializeError` at materialize time per D16 + 06-operational.md.

D16 stated cross-catalog references are a supported pattern without giving empirical backing — this experiment fills the gap.

## Setup

**Two parallel `cue.mod/` setups** (the modelling choice locked at planning time): one root carries both catalog A and catalog B; the second root carries only catalog A. Each root has its own `cue.mod/module.cue` declaring the same module identifier `test.example/cross-catalog@v0` — same module name, different filesystem trees, so the import path inside catalog A is byte-identical across both scenarios but resolves to different filesystems.

```
11-cross-catalog-import/
  both_subscribed/
    cue.mod/module.cue          test.example/cross-catalog@v0
    schema/common.cue            #Catalog + #Resource + #ComponentTransformer + ...
    catalog_a/
      identity/identity.cue      ModulePath: "test.example/a", Version: "1.0.0"
      transformers/foo_transformer.cue   imports catalog_b/resources
      catalog.cue                 c.#Catalog + #transformers entry
    catalog_b/
      identity/identity.cue      ModulePath: "test.example/b", Version: "1.0.0"
      resources/bar.cue           #BarResource
      catalog.cue                 c.#Catalog (no transformers)
  b_missing/
    cue.mod/module.cue          test.example/cross-catalog@v0   (same module name)
    schema/common.cue            (byte-identical copy)
    catalog_a/                   (byte-identical to both_subscribed/catalog_a/)
    (no catalog_b/ here)
```

Catalog A's `transformers/foo_transformer.cue`:

```cue
import (
    s "test.example/cross-catalog/schema"
    b "test.example/cross-catalog/catalog_b/resources"
)

#FooTransformer: s.#ComponentTransformer & {
    metadata: { name: "foo", description: "..." }
    requiredResources: {
        (b.#BarResource.metadata.fqn): b.#BarResource
    }
}
```

The transformer is a `#FooTransformer` definition (closed) with `metadata.modulePath` + `metadata.version` deliberately omitted — the parent `#Catalog.#transformers` pattern constraint stamps them when the transformer is placed inside catalog A's manifest. This mirrors the production pattern from D19.

**Honest gap acknowledgement.** This experiment uses *physical absence of catalog_b* to simulate "catalog_b not subscribed" — at the kernel level, the `MaterializeError` would surface when the kernel inspects the subscription set and discovers catalog_b is missing or its filter excludes the SemVer the transformer references. Pure CUE cannot express the platform-side subscription set without the kernel's Materialize step. The CUE-level failure (`cannot find package`) is the same error the kernel would wrap, so the experiment validates the error-routing claim from D16 + 06-operational.md without claiming to validate the full kernel materialize path.

## Run

```bash
# both_subscribed scenario: cross-catalog import resolves; transformer's
# requiredResources contains catalog_b's BarResource keyed by FQN.
( cd both_subscribed && cue vet ./catalog_a/... ./catalog_b/... )
( cd both_subscribed && cue vet -c ./catalog_a/... ./catalog_b/... )
( cd both_subscribed && cue eval ./catalog_a/... --all | \
    grep -q 'test.example/b/resources/bar@1.0.0' )

# b_missing scenario: catalog_b physically absent → CUE evaluation fails
# with "cannot find package" — the failure shape kernel wraps as MaterializeError.
( cd b_missing && cue vet ./catalog_a/... 2>&1 | grep -q 'cannot find package' )
```

## Outcome

Observed on 2026-05-25 with cue v0.16.x:

- **both_subscribed.** `cue vet` clean (plain and `-c`). `cue eval ./catalog_a/... --all` shows the transformer's `requiredResources` populated with catalog_b's resource value: `"test.example/b/resources/bar@1.0.0": { kind: Resource, metadata: { name: bar, modulePath: test.example/b/resources, version: 1.0.0, fqn: test.example/b/resources/bar@1.0.0 }, spec: { bar: 0 } }`. The cross-catalog reference materialized concretely; catalog A's manifest carries catalog B's resource keyed by B's FQN.
- **b_missing.** `cue vet ./catalog_a/...` → exit 1. Errors:
  - `test.example/cross-catalog/catalog_a@v0.test.example/cross-catalog/catalog_a/transformers: import failed: import failed: cannot find package "test.example/cross-catalog/catalog_b/resources": cannot find module providing package test.example/cross-catalog/catalog_b/resources`
  - File:line citations point at `catalog.cue:9:2` (where the catalog imports the transformers subpackage) and `transformers/foo_transformer.cue:12:2` (the offending `import b "..."` line).

**Hypothesis held.** D16's "cross-catalog primitive references are a supported pattern" claim has empirical backing. The both-subscribed case resolves cleanly through standard CUE imports — no special kernel handling, no `#CatalogDependencies` manifest, no `CrossCatalogMismatch` diagnostic. The missing-catalog failure mode produces a CUE error with file:line citations that the kernel can wrap as `MaterializeError` (per 06-operational.md's diagnostic-routing claim) at materialize time, when the subscription set is consulted and the unreferenced catalog is discovered.

**Implications for D16 + 06-operational.md:**

1. The "supported pattern" claim works mechanically as designed at the CUE-evaluation level.
2. The MaterializeError routing claim is structurally sound — the underlying CUE error names the offending file/line, so the kernel has enough context to attribute the failure to catalog A's import statement and the absent catalog B by package path.
3. The author-time-vs-platform-time pin drift risk (already in 05-risks.md) remains: the CUE import in catalog A pins one SemVer; the platform's subscription range may exclude it; the failure is well-diagnosed at materialize time, but the *author* and the *operator* are the two separate parties who need to coordinate. The experiment confirms diagnostic quality but not the broader coordination question.

D16 Source line gains experiment citation.
