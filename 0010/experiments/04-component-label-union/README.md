# 04-component-label-union — Module and Catalog Identity

Status: Concluded

## Hypothesis

OQ16 asks whether a primitive's **component fragment** is covered by D27's additive-only promise. This experiment tests the answer that dissolves the question rather than answering it: that the matching label can be **moved off the fragment onto the primitive**, so the fragment reverts to a pure wrapper and the label falls under D27 automatically.

That much held. *How* the label then reaches the component changed during the run, and the experiment is written to show both routes, because the discarded one is what makes the surviving one legible:

- **Design A — union `metadata.labels`.** The route `core/SPEC.md` already describes normatively at `:216`, `:222` and `:658`: *"`metadata.labels` … unify from every attached primitive. Conflicts MUST fail at unification."* Tested in five variants.
- **Design B — a dedicated matching field.** `metadata.labels` is left alone and never unified; matching moves to its own field which is unified wholesale. Proposed after A's variants exposed that every one of them needed a filter.

## Setup

Everything is copied in shape, nothing imported. No registry, no network, no dependency on `core/` or the catalogs.

`prim/prim.cue` carries minimal stand-ins for the catalog primitives. Specs are reduced to a single field because only the label surface matters; the **label values are verbatim** from `catalog_opm/src` as of 2026-08-01, which is what the experiment turns on:

| stand-in | source | labels |
| --- | --- | --- |
| `#ContainerRequired` / `#ContainerOpen` | `resources/container.cue:21` | `resource…/category: "workload"` + `core…/workload-type` as an open disjunction |
| `#Volumes` | `resources/volume.cue:19` | `resource…/category: "storage"` |
| `#ConfigMaps` | `resources/configmap.cue` | `resource…/category: "config"` |
| `#Expose` | `traits/expose.cue` | `trait…/category: "network"` |
| `#SecurityContext` | `traits/security_context.cue` | `trait…/category: "security"` |
| `#StatefulBlueprint` | `blueprints/workload/stateful_workload.cue:44` | `core…/workload-type: "stateful"` |

Three deliberate departures from the real catalog:

- `#ContainerRequired` keeps the real `!` marker (`"core.opmodel.dev/workload-type"!: "stateless" | …` — the module author must pick); `#ContainerOpen` drops it. The `!` is a dimension of the experiment, not an accident.
- `#StatefulBlueprint` carries an extra label, `opm.opmodel.dev/tier: "data"`, which no real primitive carries. It stands in for the future state where the matching vocabulary has moved out of `core` into a catalog; whether this key survives is what separates the design-A filters from each other.
- The `*Match` stand-ins (design B) split the same primitives across two fields — `metadata.labels` for categorisation, `matchLabels` for matching.

`v_*/` packages, each defining its own `#Component` and composing the same component — mirroring `modules/jellyfin/components.cue:22` (stateful blueprint + container + volumes + configmaps + expose + security context):

| package | design | union style | container |
| --- | --- | --- | --- |
| `v_full` | A | every primitive label, unfiltered — SPEC.md as written | open |
| `v_prefix` | A | keys under `core.opmodel.dev/` only | open |
| `v_denylist` | A | every key except a named categorisation set | open |
| `v_denylist_req` | A | as `v_denylist` | **required** |
| `v_index_req` | A | one key, indexed not iterated | **required** |
| `v_matchfield` | B | `matchLabels` unified wholesale, no filter | **required** |
| `v_matchfield_conflict` | B | as above, two blueprints disagreeing | **required** |
| `v_render` | B | folding `matchLabels` into rendered output behind an opt-in flag | — |

`v_render` mirrors `core/src/transformer.cue:147-157` as of 2026-08-01, including its `transformer.opmodel.dev/` exclusion, so the shape under test is the real one.

## Run

```bash
./run.sh
```

## Outcome

```
A. Unioning metadata.labels
  v_full                FAIL  resource.opmodel.dev/category: 5 errors in empty disjunction
  v_prefix              ok    workload-type=stateful
  v_denylist            ok    workload-type=stateful  opm.opmodel.dev/tier=data
  v_denylist_req        FAIL  missing required field in for comprehension
  v_index_req           ok    workload-type=stateful

B. A dedicated matching field
  v_matchfield          ok    opm…/workload-type=stateful  opm…/tier=data
  v_matchfield (bare)   FAIL  field is required but not present
  v_matchfield_conflict FAIL  conflicting values "daemon" and "stateful"

C. Folding matchLabels into rendered output
  outDefault            ok    matching labels absent
  outOff                ok    identical to default
  outOn                 ok    both matching labels appended
```

**Finding 1 — the union SPEC.md describes cannot be built.** `v_full` fails on `resource.opmodel.dev/category`, which takes `workload` on Container, `storage` on Volumes and `config` on ConfigMaps. This is not a latent risk: it is what the spec's own sentence promises will happen (*"conflicts MUST fail at unification"*), and the catalog's labelling scheme guarantees it on the first real component. Confirmed against the real tree before the fixtures were written — real `catalog_opm` fails at `#StatefulWorkload` (Container + Volumes) without reaching a module at all, and real `modules/jellyfin` additionally collides on `trait.opmodel.dev/category` across `workload`/`network`/`security`.

**Finding 2 — under design A a filter is a precondition, not a refinement**, and the filter choice decides whether the vocabulary can leave `core`. `v_prefix` and `v_denylist` differ on the same catalog: the prefix filter silently drops `opm.opmodel.dev/tier`, the denylist carries it. A prefix filter moves ownership from the key to the namespace but keeps it in `core`.

**Finding 3 — under design A, iteration and the `!` marker are mutually exclusive.** `v_denylist_req` fails with `missing required field in for comprehension`: CUE will not iterate a struct holding an unset required field. Every *filtered* union must iterate, so every one of them forces dropping `!` from `#ContainerResource`, degrading "the author must pick a workload type" from a required field to an incomplete value. Only the unfiltered indexing variant preserves it, at the cost of naming each participating key in `core` — which is what finding 2 rules out.

**Finding 4 — design B removes the filter rather than choosing one, and the three costs above go with it.** Every design-A problem traces to one cause: `metadata.labels` conflates categorisation with matching. Given matching its own field there is nothing to filter, and three properties follow:

- No filter means no `for k, v` comprehension — the structs unify wholesale, so the **`!` marker survives**. `v_matchfield` with a bare container fails `field is required but not present`, exactly as the catalog behaves today.
- The categorisation labels never meet, **structurally** rather than by a filter agreeing not to look at them.
- A conflict becomes **meaningful**: `v_matchfield_conflict` fails `conflicting values "daemon" and "stateful"`, a real modelling error rather than an artifact of unrelated labels sharing a namespace.

Design B is also symmetric with what already exists. `#ComponentTransformer` declares its matching *demand* in a dedicated field (`requiredLabels`, `core/src/transformer.cue:46`) separate from its own `metadata.labels`; only the component side declared matching *supply* in `metadata.labels`. B makes the two sides agree.

**Finding 5 — matching labels *can* be folded into rendered output behind an opt-in flag, and D36 deliberately does not.** `core/src/transformer.cue:147-157` folds `#componentMetadata.labels` into `componentLabels`, so matching labels reach every rendered object today. Under B they would stop unless folded deliberately. `v_render` shows the fold working with `#renderMatchLabels: bool | *false` — absent and explicitly-false render identically, true appends both keys. The guard sits at struct level, which is the shape `catalog_opm`'s documented closedness workaround requires anyway, so it carries no regression risk.

D36 ships without it. This variant is retained as evidence that adding the fold later costs four lines and disturbs nothing else — the reason to defer is that shipping it now would require deciding where the flag lives, and a runtime-only flag is ruled out by the byte-identical-render gate. The consequence of not folding is worth stating plainly: rendered objects carry `core.opmodel.dev/workload-type` today and will stop.

**Hypothesis held; the mechanism changed.** The label moves off the fragment onto the primitive, the fragment becomes a pure wrapper, and the label falls under D27 and the matcher's unify rung without extending either. It arrives via a dedicated `matchLabels` field rather than a filtered union of `metadata.labels` — which additionally means `core` never names the key, so the vocabulary is catalog-owned by construction rather than by a filter's cooperation.

Evidence for **D36**, which resolves **OQ16**. `SPEC.md` `:216`/`:222`/`:658` are restated rather than deleted: the upward union is real, and describes `matchLabels` rather than `metadata.labels`. D36 takes design B, does not render `matchLabels`, deletes `#LabelWorkloadType` from `core`, and renames the key `opm.opmodel.dev/workload-type` under `catalog_opm` ownership.
