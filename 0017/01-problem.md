# Problem Statement: Layered Defaults

## Current State

No authoring layer can hold a component-field default today. Four could plausibly do it; each fails differently:

1. **Trait/resource schemas** (`catalog_opm/src/traits/`) are workload-type-agnostic unions. `#UpdateStrategySchema.type` is `"RollingUpdate" | "Recreate" | "OnDelete"` with no `*`. That is correct: the right default (and the legal menu) depends on the target kind the trait cannot see.

2. **Blueprints** (`catalog_opm/src/blueprints/`) compose traits but neither narrow their menus to the target kind nor default them. Every composed trait's `spec` projection is a *required* field. Core's `#Component._allFields` (`core/src/component.cue:128-151`) embeds `trait.spec` into the component's closed `spec`, and core's `#Trait` gate (`spec!: (strings.ToCamel(name)): _`, `core/src/trait.cue:104`) forces the projected field regular even when a catalog authors it optional. Attaching a trait therefore forces its field *present*, and a defaultless schema makes the component permanently non-concrete.

3. **Module authors** default in `#config` (`replicas: int & >=1 | *1`). The kernel validates values against `#config` and fills the *unified* result (defaults unresolved) at the `values` path (`library/opm/kernel/validate.go` `runValidate` returns `schema.Unify(values)`; `library/opm/kernel/process.go:42` `FillPath`). `#ModuleInstance` then unifies `#config: values` (`core/src/module_instance.cue:79`), so a ⟨value, default⟩ pair travels into component fields.

4. **Transformers** (`catalog_opm/src/transformers/`) carry per-kind fallbacks keyed on field absence: `_restartPolicy: string | *"Always"` behind `if #component.spec.restartPolicy != _|_`, and the deliberate omit-`strategy:`-and-let-Kubernetes-default idiom. Because layer 2 makes every composed field present, these guards are dead code: the "author set it" branch is always taken.

The trait `optional: bool | *true` posture (enhancement 0010 D46) is honored by zero traits in practice: measured 2026-08-18 against `catalog_opm` v2.0.0-alpha.3, 11 of 20 v1beta1 traits force the author to set their field on every attachment (`updateStrategy`, `scaling`, `restartPolicy`, `expose`, `hostNetwork`, `hostPid`/`hostIpc`, `gracefulShutdown`, `resourceName`, `disruptionBudget`, `runtimeClass`, `workloadIdentity`); the other nine escape only because their schemas happen to be all-optional or self-defaulting.

## Gap / Pain

- **Fresh modules do not render.** The CLI's minimal template failed `opm inst build` out of the box (`unresolved disjunction "RollingUpdate" | "Recreate" | "OnDelete"`) until the template hardcoded a strategy. `cue vet` does not check concreteness, so nothing catches this before render.
- **The fleet carries boilerplate nobody chose.** All 7 v2 modules composing `#StatelessWorkload` restate `restartPolicy: "Always"` and `updateStrategy: {type: "RollingUpdate", rollingUpdate: {}}` verbatim (`modules/apprise/components.cue:128`, `modules/k8up/components.cue:195`, `modules/metallb/components.cue:144`, …): the Kubernetes defaults, extracted by the schema rather than decided by the author.
- **Layered defaults annihilate.** CUE's default model has one slot per field, and two differing defaults unify to bottom (spec rule U2; `research/cue/concepts/default-precedence.md`). A `#config` default flowing into a blueprint-defaulted field silently destroys both. There is no in-language precedence: "closest to the leaf wins" requires provenance the lattice deliberately erases.
- **Catalog accepts what Kubernetes rejects.** With no per-kind narrowing, a stateful module can declare `Recreate` and a stateless module `restartPolicy: "Never"`; both vet clean and fail at `kubectl apply` (catalog_opm issue 40).
- **Transformer fallbacks are unreachable**, so the one layer that knows the target kind cannot supply its defaults.

## Concrete Example

Fresh scaffold, zero edits:

```
$ opm module init --template minimal test && cd test && opm inst build .
ERRO render failed: 1 issue
unresolved disjunction "RollingUpdate" | "Recreate" | "OnDelete" (type string)
  values.#UpdateStrategySchema
    > update_strategy.cue:37:5
```

The chain: `#StatelessWorkload` embeds `tr.#UpdateStrategy` → core `_allFields` embeds the trait's required `spec: updateStrategy: #UpdateStrategySchema` → the field is present on the component with a defaultless disjunction → the kernel's instance gate (`spec.Validate(cue.Concrete(true))`, `library/opm/kernel/process.go:48`) fails before matching or transformation ever run. The deployment transformer's `_updateStrategy: *null | {...}` fallback (written precisely for the author-silent case) is unreachable: its guard tests presence, and presence is unconditional.

```
   trait spec (required field, defaultless)
        │  core _allFields embedding (faithfully carries "required")
        ▼
   component spec — present, never concrete
        ▼
   kernel Concrete(true) gate  ✗ dies here
        ▼
   matching → transformer fallback   (never reached)
```

## User Stories

- As an **application module author**, I want a fresh module from a workload blueprint to render with sensible defaults so that I only write the values I actually care about. Today: I must hand-set `updateStrategy`, `scaling`, and `restartPolicy` on every workload or the module does not build.
- As a **catalog author**, I want to state per-kind starting values and legal menus in the blueprint so that a stateless workload defaults to what a Deployment accepts. Today: any default I put in the trait schema is a global claim across all kinds, and the blueprint has no defaulting or narrowing convention at all.
- As a **kernel contributor**, I want a defined precedence between instance values, config defaults, blueprint defaults, and transformer fallbacks so that "who decides this value" has one answer. Today: precedence is inexpressible in CUE and undefined in OPM; colliding defaults annihilate silently.

## Why Existing Workarounds Fail

- **Hardcoding in templates/modules** (current state): restates Kubernetes defaults in every module; values nobody chose; does not scale past the fields the template author anticipated.
- **Defaulting the trait schema** (`type: *"RollingUpdate" | …`): fixes only defaultable fields, at the wrong layer. It is a global claim the trait is not entitled to make, since the menu and the default are kind-dependent. It also permanently spends the field's single default slot, so no downstream layer can ever default it differently.
- **Blueprint-side `?` demotion** (`spec: updateStrategy?: …`): measured no-op. Unification keeps the stronger marker; the trait's required projection wins over any optional marker added downstream, and core's trait gate forces it regular at the source.
- **`SetLayer` (upstream CUE per-file default priority)**: prototype-status internal API: one commit, no design doc, "may change at any time", and a documented soundness bug where a low layer combining constraint and default lets a high-layer default violate the constraint (`research/cue/concepts/default-precedence.md`).
