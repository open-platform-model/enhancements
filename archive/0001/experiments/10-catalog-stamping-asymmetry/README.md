# 10-catalog-stamping-asymmetry — #Platform Redesign Umbrella

Status: Concluded

Pins: D19 (`#Catalog.#transformers` schema-enforced stamping), D21 (deliberate asymmetry — no equivalent for `#Resource` / `#Trait` / `#Blueprint`)

## Hypothesis

`#Catalog.#transformers`'s pattern constraint catches every form of transformer-subpath / version drift at `cue vet` time (caught loudly with named diverging fields and file:line citations). Resources, traits, and blueprints — which do **not** carry an equivalent pattern constraint — accept the same drift silently and ship the wrong `metadata.modulePath` without any safeguard.

Seven sub-claims:

1. **transformer_ok_omitted.** Transformer that omits `metadata.modulePath` entirely → pattern stamps it; vet clean; exported value shows canonical subpath + version.
2. **transformer_ok_canonical.** Transformer that writes the canonical `<id.ModulePath>/transformers` subpath + canonical version literally → unifies with the pattern's stamped values; vet clean.
3. **transformer_typo_subpath.** Transformer that writes `<id.ModulePath>/trasnformers` (typo) → unification conflict; vet FAILS with "conflicting values" + file:line citations.
4. **transformer_wrong_version.** Transformer that writes `version: "9.9.9"` against `id.Version: "0.0.0-dev"` → unification conflict; vet FAILS.
5. **resource_typo_subpath.** Resource that writes `<id.ModulePath>/resorces/workload` (typo) → no pattern constraint catches it; vet SUCCEEDS; the wrong subpath ships in the exported metadata.
6. **trait_typo_subpath.** Trait that writes `<id.ModulePath>/trais/scaling` (typo) → same residual surface; vet SUCCEEDS.
7. **blueprint_typo_subpath.** Blueprint that writes `<id.ModulePath>/blueprnts/web-app` (typo) → same residual surface; vet SUCCEEDS.

## Setup

`./schema/common.cue` — `#PrimitiveMetadata` + `#Resource` + `#Trait` + `#Blueprint` + `#ComponentTransformer` + `#Catalog` (with the `_md: metadata` mirror and `#transformers` pattern constraint) + `#FQNType` / `#NameType` / `#ModulePathType` / `#VersionType` slice copied from `enhancements/0001/schemas/target.cue` (skill rule: copy, never reference).

`./identity/identity.cue` — synthetic identity package (`package identity`; exports `ModulePath: "example.com/cat"` and `Version: "0.0.0-dev"`). Mirrors the production sibling-identity-subpackage layout from D19.

Seven sibling packages, each one variant of the matrix:

| Package | Primitive | What the author writes | Expected vet outcome |
| --- | --- | --- | --- |
| `transformer_ok_omitted/` | Transformer | (no modulePath; pattern stamps) | clean |
| `transformer_ok_canonical/` | Transformer | canonical subpath + version | clean |
| `transformer_typo_subpath/` | Transformer | `/trasnformers` typo | FAILS (conflicting values) |
| `transformer_wrong_version/` | Transformer | `version: "9.9.9"` | FAILS (conflicting values) |
| `resource_typo_subpath/` | Resource | `/resorces/workload` typo | SUCCEEDS (drift ships) |
| `trait_typo_subpath/` | Trait | `/trais/scaling` typo | SUCCEEDS (drift ships) |
| `blueprint_typo_subpath/` | Blueprint | `/blueprnts/web-app` typo | SUCCEEDS (drift ships) |

Each catalog/primitive instance pins itself to `id.ModulePath` + `id.Version` from the synthetic identity package, mirroring the production sourcing pattern.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry@v0"`.

## Run

```bash
# OK cases — vet clean, stamped value correct.
cue vet ./transformer_ok_omitted/...
cue vet ./transformer_ok_canonical/...
cue export ./transformer_ok_omitted/... --out yaml | \
  grep -q "modulePath: example.com/cat/transformers"

# Drift caught — vet fails with conflicting values.
cue vet ./transformer_typo_subpath/...  2>&1 | grep -q "conflicting values"
cue vet ./transformer_wrong_version/... 2>&1 | grep -q "conflicting values"

# Residual surface — vet succeeds despite typo; drift ships.
cue vet ./resource_typo_subpath/...
cue vet ./trait_typo_subpath/...
cue vet ./blueprint_typo_subpath/...
cue export ./resource_typo_subpath/... --out yaml | \
  grep -q "modulePath: example.com/cat/resorces/workload"   # typo shipped
```

## Outcome

Observed on 2026-05-25 with cue v0.16.x:

| Package | vet exit | Notes |
| --- | --- | --- |
| `transformer_ok_omitted/` | 0 | Stamped: `modulePath: example.com/cat/transformers`, `version: 0.0.0-dev`, `fqn: example.com/cat/transformers/foo@0.0.0-dev` |
| `transformer_ok_canonical/` | 0 | Author's canonical literals unify with pattern's stamped values |
| `transformer_typo_subpath/` | 1 | `conflicting values "example.com/cat/transformers" and "example.com/cat/trasnformers"` with file:line citations into both the schema and the offending catalog file |
| `transformer_wrong_version/` | 1 | `conflicting values "0.0.0-dev" and "9.9.9"` |
| `resource_typo_subpath/` | 0 | Exported `shipped.modulePath: "example.com/cat/resorces/workload"` — typo ships |
| `trait_typo_subpath/` | 0 | Exported `shipped.modulePath: "example.com/cat/trais/scaling"` — typo ships |
| `blueprint_typo_subpath/` | 0 | Exported `shipped.modulePath: "example.com/cat/blueprnts/web-app"` — typo ships |

**Hypothesis held.** D19's `#Catalog.#transformers` schema-enforced stamping catches every form of transformer drift at `cue vet` time with named diverging fields and file:line citations — the structural guarantee promised by D19 is empirically real and immediately diagnosable. D19 + D21's deliberate asymmetry — no equivalent schema enforcement on resources, traits, blueprints — is also empirically real: typos in their `metadata.modulePath` subpath ship without any vet-time signal, exactly as the design acknowledges.

**Implications for D19 + D21 + future work:**

1. The transformer side of D19 is structurally sound: a typo / wrong-version in transformer `metadata` cannot ship from a correctly-written catalog package (the pattern catches it).
2. The resource / trait / blueprint side carries a real residual surface: an author typo in `metadata.modulePath` subpath ships silently. Mitigations available (none in 0001's scope):
   - Publish-task lint that greps every primitive's `metadata.modulePath` for canonical-subpath conformance against a per-catalog convention.
   - Extending `#Catalog` with `#resources` / `#traits` / `#blueprints` sibling maps (deferred additive extension per D19; would lift the asymmetry).
   - Concrete-catalog CI fixture that asserts on the exported `metadata.modulePath` of every primitive.
3. The asymmetry is principled (transformers are the kernel-consumed shape; the others are author-imported via standard CUE imports). Acceptable for this enhancement; flagged in 02-design.md §2 + 05-risks.md.

D19 + D21 Source lines gain experiment citation.
