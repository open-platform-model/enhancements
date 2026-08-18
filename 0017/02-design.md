# Design — Layered Defaults

This document answers the question: "What is the proposed solution and how does it work?"

## Design Goals

- A fresh module composed from a workload blueprint renders with zero hand-set trait fields.
- Every authoring layer has exactly one defaulting role, and the composed precedence is deterministic: **instance values > `#config` defaults > blueprint defaults > transformer fallbacks**.
- A module author's explicit value always wins; a module author's `#config` default always beats a blueprint default; a field nobody speaks for falls through to the transformer (or to the platform runtime, by omission).
- Blueprints constrain composed fields to what the target kind's API accepts, so kind-invalid values fail at vet time, not at `kubectl apply`.
- `#Trait.optional` (0010 D46) becomes load-bearing: an optional trait's field is genuinely absent until someone sets it; a module demanding a trait (`optional: false`) makes its field required.
- The rules that CUE cannot enforce are written as specification with citable identifiers, enforceable by CLI gates.

## Non-Goals

- **No in-language precedence.** No use of CUE's `SetLayer`/layer machinery (prototype, internal, unsound — D4 alternatives). If upstream ships it properly it can slot underneath this design without changing observable behavior.
- **No trait-level defaults.** Primitives stay bounds-only; this enhancement does not add a defaulting mechanism to traits or resources.
- **No v1-line changes.** The v1 catalogs and module fleet keep their current (boilerplate-carrying, working) shape.
- **The K8s-fidelity narrowing sweep itself** (every blueprint field audited against its kind's API) is scoped to catalog_opm issue 40; this entry establishes the mechanism and the contract, the issue tracks the exhaustive audit.
- **CLI gate implementation** is a consumer of this design (rules L1–L6); gate engineering details land in a cli-side slice, not here.

## High-Level Approach

Four mechanisms, one per layer, each individually measured (cue v0.17.1, 2026-08-18). None is a precedence feature; the chain emerges from two lattice facts — concrete data eliminates a marked disjunct, and absence falls through.

```
instance values ─── beats ──► #config defaults ─── beat ──► blueprint defaults ─── beat ──► transformer fallbacks
   (unification at              (kernel finalizes               (presence beats                 (absence-keyed,
    validate time)               config to DATA                  absence-guard)                  per target kind)
                                 before composition)
```

1. **Primitives publish bounds** (unchanged, now codified): trait/resource schemas are defaultless unions of what any kind accepts.
2. **Blueprints narrow and default**: each blueprint conjoins the submenu its target kind honors and MAY mark at most one field-level default per field — the single `*` on the catalog side. An author's concrete value eliminates the marked arm and wins.
3. **The kernel finalizes `#config` to data**: after validating instance values against `#config`, and before `FillPath`, the kernel resolves every default to its concrete value. What enters the composition is plain data — so an author's `#config` default beats a blueprint default by mechanism 2's own rule, and the two-`*` annihilation case becomes unrepresentable.
4. **Core honors trait optionality**: `#Component._allFields` projects an `optional: true` trait's spec through an optionalizing comprehension (`for k, v in trait.spec {(k)?: v}`) — the field exists as a constraint but is absent until set — and embeds an `optional: false` trait's spec as-is (required). Absence is what arms the transformers' existing per-kind fallbacks.

## Schema / API Surface

Headline shapes — full surface in [`schemas/target.cue`](schemas/target.cue).

- **`core` `#Component._allFields`** — the trait branch becomes optionality-aware (mechanism 4). A trait that never states a posture fails loudly at every consumer instead of being silently required. A companion single-regular-field guarantee on trait specs keeps the comprehension total (a top-level `req!` sibling would abort iteration; core's existing trait gate plus closedness already prevents it — the target schema pins it).
- **`catalog_opm` blueprints** — per-kind narrowing conjunctions plus field-level defaults on composed fields (mechanism 2); the whole-struct default form is forbidden (an author override of one field silently discards the marked arm's other defaults).
- **`library` kernel** — a finalize step between `ValidateConfig` and `FillPath` (mechanism 3). No schema change; a behavior change with one observable consequence (Before/After below).
- **`core` SPEC.md §6** — the layer contract, rules L1–L6 (landed 2026-08-18, core 504e927, ahead of this entry; L5 is rewritten by this design from an author obligation into a kernel guarantee).

## Integration Points

- **core** (`opmodel.dev/core@v2`, `feat!`, advances the alpha line)
  - `src/component.cue` — `_allFields` trait branch: optionality-aware projection.
  - `src/trait.cue` — no shape change; `#TraitOptionalGate` rationale gains the posture-required consequence (unstated posture now fails at consumers, not only at publish).
  - `SPEC.md` — §3.1/§2.2 constraint updates; §6 L5 reword (kernel guarantee).
- **library** (kernel)
  - `opm/kernel/process.go` — finalize validated config before `FillPath(schema.Values, …)`.
  - `opm/kernel/validate.go` — finalize helper; ambiguous-default errors surface at the config boundary with config-shaped messages.
  - Same treatment on the `ValidateConfigDetailed` layered-sources path (finalize after the last source merges) and the synth/debugValues path (`opm/kernel/synth.go` — frontends layer debugValues as values; same fill point).
- **catalog** (`catalog_opm`, v2 line)
  - `src/blueprints/v1beta1/*.cue` — narrowing + defaults per workload kind (issue 40 carries the exhaustive audit).
  - `src/traits/v1beta1/update_strategy.cue` — `rollingUpdate` substruct loosens to the union once blueprints carry per-kind param truth.
  - `src/transformers/*.cue` — unchanged; their absence-keyed fallbacks become reachable. Regression fixtures gain blueprint-path components (today's fixtures attach traits directly and never see the forced-presence path).
- **cli**
  - `templates/*/module.cue` — drop hand-set strategy/restartPolicy once blueprint defaults land.
  - Template smoke test: `opm inst build` against each generated template in CI (`cue vet` structurally cannot catch concreteness failures).
  - Later slice: L1–L6 vet/publish gates.
- **modules** (`main`, v2 staging)
  - Delete extracted boilerplate from the 7 stateless-workload modules; render diff must be empty (the defaults reproduce it).

## Before / After

**Before** — fresh minimal template:

```
opm inst build .   →  ERRO unresolved disjunction "RollingUpdate" | "Recreate" | "OnDelete"
```

Module authors compensate (modules/apprise, k8up, metallb, …):

```cue
restartPolicy: "Always"
updateStrategy: {type: "RollingUpdate", rollingUpdate: {}}   // K8s defaults, restated by hand
```

**After** — same template, no trait fields set: renders a Deployment with the blueprint's `strategy: RollingUpdate`; author writes `updateStrategy: type: "Recreate"` → wins; author writes `type: "OnDelete"` → vet-time conflict naming the blueprint line (measured against the patched blueprint, 2026-08-18).

**The kernel's one observable change** (mechanism 3): a `#config` default that violates a downstream constraint stops being silently substituted and starts erroring. Today `#config: port: *80 | 8080` meeting a downstream `port: >1000` silently ships 8080 — a value the author never chose, selected by disjunct elimination. After finalization the default is data (`80`) and the collision is a loud conflict. A default becomes a commitment: it ships, or it errors.
