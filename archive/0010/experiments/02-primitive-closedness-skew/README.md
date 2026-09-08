# 02-primitive-closedness-skew — Module and Catalog Identity

Status: Concluded

> **Ran before the model it tests was recorded.** It measured MAJOR-keyed
> primitive FQNs with an additive-only promise while that design was still under
> discussion; the outcome then became evidence for **D24, D26 and D27**, which
> reversed D13's keying half. Read those decisions for what the design concluded;
> this file is what was measured.

## Hypothesis

Under MAJOR-keyed primitive FQNs, a component and a transformer built from
different builds of one primitive meet at one key, and `Match`'s always-unify
rung (`library/opm/compile/match.go:243-278`) is what decides whether they are
compatible. The claim under test: **CUE's closedness makes a component field the
provider's build never declared a hard failure**, so a provider lagging behind
the contract fails loudly exactly when the module uses something the provider
cannot honour — and passes when it does not.

If that holds, "transformers build independently of primitives" is safe. If it
does not, an additive-only promise buys a match that renders while silently
dropping fields, which for a backup contract is the worst available outcome.

## Setup

Two module roots, `mod/` and `prov/`, declaring the **same** module path
(`test.example/skew@v0`) over different filesystem trees — the modelling choice
`0001/experiments/11-cross-catalog-import` established, so every package file is
byte-identical across the two and only the build each side *imports* differs.
`prov/` is a verbatim `cp -r` of `mod/`. The component is loaded from `mod/`,
the transformer from `prov/`, by two separate `load.Instances` calls sharing one
`*cue.Context` — the shape `compile` (module's own build) and `materialize`
(`pull.go:23`, per-catalog build, shared `octx`) actually have.

**Copied, never referenced** (2026-07-29), into `mod/schema/schema.cue`:
`#NameType`, `#VersionType`, `#KebabToPascal` from `core/src/types.cue`;
`#Resource` / `#ResourceMap` from `core/src/resource.cue` — including
`spec!: (strings.ToCamel(metadata.#definitionName)): _` verbatim, since the
dynamic field label and the `_` leaf are among the things that could decide the
answer; `#Component` from `core/src/component.cue` and `#ComponentTransformer`
from `core/src/transformer.cue`, both trimmed to the fields `Match` reads.
`main.go`'s `unifyIntersection` is copied from `match.go:243-278` with the
plan-recording replaced by a returned slice.

**Two deliberate deviations from shipped `core`**, both under test: `#FQNType`
is MAJOR-keyed (`path/name@v1`) rather than SemVer-keyed, and a primitive
carries `apiVersion` (contract major, keys the FQN) alongside `catalogVersion`
(the build it shipped in) where shipped `core` has one `version` doing both.
Under the shipped scheme the two sides of every case below carry *different*
keys and never meet in the matcher, so there is nothing to measure.

Four builds of one `backup@v1` contract, plus two of a pattern-constraint
variant (`spec: backupSet: [k=string]: #BackupSetSchema`, the shape
`catalog_opm/src/resources/configmap.cue:23` uses):

| build | change | promise |
| --- | --- | --- |
| `catalog_v1_0` | baseline | — |
| `catalog_v1_1` | adds `retention?` | kept (additive) |
| `catalog_v1_2_narrowed` | narrows `schedule: string` → `"daily" \| "weekly"` | **broken** (removes options) |
| `catalog_v1_3_default` | flips `mode`'s default `retain` → `delete` | adds nothing, removes nothing |
| `catalog_v1_0p` / `catalog_v1_1p` | same additive change inside a pattern constraint | kept |

Each case is measured under three unification **scopes**: the whole primitive
value (what `match.go` does today), `spec` only, and the whole value with
conflicts under `metadata` discarded.

## Run

```bash
bash run.sh          # fixtures + the FQN/provenance shape + the harness
# or just the harness:
go run .
```

## Outcome

Observed 2026-07-29, cue v0.17.1, Go 1.26.2. **7 of 7 cases behave as predicted
under the third scope.** The first two scopes are characterised rather than
predicted, and the gap between them is the finding.

### 1. The hypothesis holds — but only when the closed definition is in the unification

| # | skew | whole value | spec only | whole, metadata ignored |
| - | --- | --- | --- | --- |
| 1 | provider on 1.0.0, module on 1.1.0 **uses** `retention` | FAILS `spec.backup.retention: field not allowed` | **PASSES** | FAILS `field not allowed` |
| 2 | same skew, module does not use it | FAILS on `metadata.catalogVersion` | PASSES | PASSES |
| 3 | provider ahead (1.1.0 vs 1.0.0) | FAILS on `metadata.catalogVersion` | PASSES | PASSES |
| 4 | same build (control) | PASSES | PASSES | PASSES |
| 5 | provider's build broke the promise by narrowing | FAILS on `spec.backup.schedule` | FAILS | FAILS, naming both arms |
| 6 | default drift | FAILS on `metadata.catalogVersion` | PASSES | PASSES |
| 7 | case 1 in the pattern-constraint shape | FAILS `field not allowed` | FAILS | FAILS |

Case 1 versus case 7 is the load-bearing row. Both are the same skew and the
same authored change; they differ only in how the catalog wrote the spec body.
Under **spec-only** unification, case 1 passes and case 7 fails — because
closedness is inherited from the enclosing definition, and `spec.backup` is an
inline struct literal that carries none of its own, while `#BackupSetSchema` is
a named definition that does. **Where the unification is cut decides whether
closedness is enforced, and cutting at `spec` makes enforcement depend on a
catalog author's formatting choice.** `catalog_opm` ships both styles today.

### 2. Provenance in the unified value defeats MAJOR keys outright

Unmeasured before this run and fatal to the naive form of the model: with
`catalogVersion` as a field of the primitive's `metadata`, **every** build skew
fails, whether or not the contract surfaces are compatible (cases 2, 3, 6). The
conflict is `metadata.catalogVersion: conflicting values "1.1.0" and "1.0.0"` —
the two sides state which build they came from, those disagree, and `match.go`
unifies the whole value. MAJOR-keyed FQNs exist so two builds can meet at one
key; the provenance field prevents them from ever meeting.

So `metadata.catalogVersion` cannot be both an ordinary field of the primitive
and provenance the matcher reads across a skew, unless the comparison excludes
it. The third scope measures the smallest fix — keep the whole (closed) value
in the unification, discard conflicts under `metadata` — and it produces the
full predicted matrix: skew is invisible when the contract surfaces agree, and
a real incompatibility still fails, still naming the field.

### 3. Default drift is not silent, but it fails late and in the wrong place

Case 6's probe: after unification `spec.backup.mode` is `"retain" | "delete"`
and **not concrete**. Neither build's default survives, so the value does not
silently pick a side — it ceases to have one. The match passes; the render then
fails on an incomplete value, far from the catalog release that caused it, with
a message naming a field rather than a build. That confirms "an existing field's
default is immutable within a major" is a real rule and not a tidiness one, and
that `Validate(cue.Concrete(false))` at match time cannot be what enforces it.

### What this settles, and what it does not

Settled: an additive-only promise inside a MAJOR is *enforceable at match time*,
in both directions, provided (a) the closed definition stays in the unification
and (b) provenance is excluded from it. A provider lagging the contract is a
loud failure naming the field, exactly when the module uses what the provider
lacks. `library` already has the mechanism; what changes is the comparison's
scope.

Not settled, and out of this experiment's frame: whether `Subsume` can enforce
the promise at publish (the write-side half); whether excluding `metadata`
should be an error-path filter or a structural split of provenance out of the
unified value; and the entire question of a *provider that matches and then
ignores* a field it does declare, which no unification can detect.

### Where this landed

- **D24** (contract keys) — the model this experiment tests, adopted. Case 1 versus case 7 is cited there for why the comparison's scope matters.
- **D26** (provenance excluded before unification) — finding 2 is the whole basis of that decision, and finding 1's spec-only asymmetry is why the exclusion is on the operands rather than on the errors. The mechanism it leaves open is OQ12.
- **D27** (additive-only inside an API version) — the case matrix is that decision's evidence, and finding 3 is why the immutable-defaults rider is part of the rule rather than a note on it.
- **0011 D9** (publish-side compatibility gate) — finding 3 is why the gate is not redundant with the match rung. The four builds here are the fixtures a `Subsume`-based gate must classify correctly, which is the measurement that decision defers to.

**Hypothesis held**, with one condition the hypothesis did not anticipate: closedness enforces the additive promise at match time only when the closed definition and the provenance are separated first. Both halves of that are now recorded as decisions.
