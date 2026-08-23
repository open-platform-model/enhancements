# 02-catalog-version-authoring-alternatives — OPM Module Publishing Workflow

Status: Concluded

Pins: OQ13 (where does a catalog's version come from under D4) — evaluates the candidate authoring methods head to head

## Hypothesis

Exactly one way of declaring a catalog's version in source satisfies all three properties OPM needs: (a) the committed tree is vettable without ceremony, (b) no placeholder version can ever ship, and (c) a version/tag disagreement is expressible as a schema-level failure rather than a convention. Six candidate declarations are compared; the strict-committed form (variant B) is predicted to be the only one that satisfies all three.

Six sub-claims, one per variant:

1. **a1_core_inert_default.** `version!: #VersionType | *"0.0.0-dev"` copied verbatim from `core/src/catalog.cue:63`, with nothing else supplying a version → the documented default applies and the tree vets clean.
2. **a2_identity_supplied_dev.** Production shape — the real default lives on the non-required `identity.Version` → vets clean, ships `0.0.0-dev` FQNs.
3. **b_strict_committed.** `version!` with no default + a concrete committed version → vets clean, ships real FQNs, no sentinel possible.
4. **c_strict_missing.** Strict schema, author forgot to set a version → fails, loudly and specifically.
5. **d_version_absent.** No `version` field in the schema at all (the "publisher injects everything" option) → the derived `fqn` cannot be constructed.
6. **e_default_with_cue_guard.** Sentinel default plus a schema-level `!="0.0.0-dev"` guard → asks whether 0001's proposed "CI guard" can be moved into the schema and made unbypassable.

## Setup

Self-contained; nothing outside this directory is read or modified.

`./schema/common.cue` — `#NameType`, `#ModulePathType`, `#VersionType`, `#FQNType` copied 2026-07-25 from `core/src/types.cue`; `#CatalogFQNType` and the `#ComponentTransformer` / `#PrimitiveMetadata` shapes copied from `core/src/catalog.cue`. Skill rule: copy, never reference.

`#Catalog` is deliberately **not** in the shared package. Its `metadata.version` declaration is this experiment's independent variable, so each variant defines its own copy of `#Catalog` differing only in that line (and, where relevant, in what the stand-in identity block supplies). Everything the variants do not vary is shared.

Each variant is a sibling package exposing a `shipped` struct carrying the catalog FQN, the resolved catalog version, and (where constructible) the transformer FQN — so the observable outcome is a value, not a log line.

`./cue.mod/module.cue` — `module: "enhancements.opmodel.dev/0003/experiments/02-catalog-version-authoring-alternatives@v0"`, language `v0.17.0`.

## Run

```bash
for v in a1_core_inert_default a2_identity_supplied_dev b_strict_committed \
         c_strict_missing d_version_absent e_default_with_cue_guard; do
  echo "== $v"
  cue vet    ./$v/...            ; echo "  vet    exit=$?"
  cue vet -c ./$v/...            ; echo "  vet -c exit=$?"
  cue export ./$v/... -e shipped --out yaml
done
```

## Outcome

Observed 2026-07-25 with cue v0.17.1.

| Variant | `cue vet` | `cue vet -c` | What ships | Verdict |
| --- | --- | --- | --- | --- |
| `a1_core_inert_default` | **1** | **1** | nothing — cannot evaluate | default is inert |
| `a2_identity_supplied_dev` | 0 | 0 | `example.com/cat/transformers/foo@0.0.0-dev` | sentinel ships |
| `b_strict_committed` | 0 | 0 | `example.com/cat/transformers/foo@1.0.0-alpha.2` | **satisfies all three** |
| `c_strict_missing` | **1** | **1** | nothing — cannot evaluate | fails loudly, as wanted |
| `d_version_absent` | **1** | **1** | nothing — cannot evaluate | structurally dead |
| `e_default_with_cue_guard` | **1** | **1** | nothing — guard fires in dev | guard cannot live in schema |

**Hypothesis held.** Variant B is the only declaration satisfying all three properties. Four findings, three of them not anticipated:

**1. `core`'s documented catalog default does not exist (a1).** `core/src/catalog.cue:63` declares `version!: #VersionType | *"0.0.0-dev"` and `core/SPEC.md:576` describes it as a source-tree default: *"`metadata.version` defaults to `0.0.0-dev` in a source tree so `cue vet` is cheap during development."* It does not. A required field's disjunction default never applies — the requirement wins. Isolated minimal probe:

```cue
#Required: {v!: string | *"dev"}
required: #Required & {}   // → v: field is required but not present
#Optional: {v: string | *"dev"}
optional: #Optional & {}   // → v: dev
```

The dev-time ergonomics attributed to this line actually come from `identity.Version`, which is a **plain** field and whose default therefore does apply. `core/src/catalog.cue:63` and the SPEC paragraph describing it are both misleading about the mechanism, independent of whichever alternative wins.

**2. Removing the default costs nothing at vet time (b vs a2).** Both vet clean under plain `cue vet` and `cue vet -c`. 0001 D8's stated benefit — "dev-time `cue vet` works zero-friction" — is not a differentiator between the two, because the friction it avoids is one committed line, not a failing command. What B buys is that `0.0.0-dev` is not a representable state.

**3. Strict-and-forgotten fails precisely (c).** `cue vet` exits 1 with *"some instances are incomplete"*; `cue vet -c` names the field: `catalog.metadata.version: field is required but not present`, plus the downstream `invalid interpolation: required field missing: version` on the FQN. The failure is immediate, at the right field, before anything is published — which is the whole cost of removing the default.

**4. A schema-level publish guard is not expressible (e).** The guard does not reject the sentinel — it *deletes the default*, leaving `shipped.guard: incomplete value !="0.0.0-dev" & =~"^\\d+\\.\\d+\\.\\d+…"`. Unifying `!="0.0.0-dev"` against `#VersionType | *"0.0.0-dev"` eliminates the default branch and leaves an open constraint, so the value goes from concrete to incomplete. CUE has no notion of "publish time" to condition on, so the guard fires during development too, and it fires with a confusing incompleteness error rather than "you forgot to stamp." **Enhancement 0001's proposed mitigation ("a CI guard that rejects publishes of `0.0.0-dev` tags") must therefore live in a publish task — outside the schema, and bypassable by `cue mod publish`.** That is precisely the class of enforcement 0003 D6 rejects as giving consumers nothing to rely on.

**5. Version-free source is structurally dead (d).** Omitting the field entirely fails at reference resolution — `#Catalog.metadata.fqn: reference "version" not found` — because the derived identity interpolates it. This is the catalog-side confirmation of the same conclusion 0003 reached for `#Module`: an identity computed inside CUE cannot be built from a value the file does not carry.
