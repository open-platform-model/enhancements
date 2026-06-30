# Enhancement 0008 — CUE-Native CRD Schemas as Single Source of Truth

See [`config.yaml`](config.yaml) for metadata. This README is the index of the six split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

OPM defines its Kubernetes custom resources twice. The canonical domain schema lives in `core/` as pure CUE (`#ModuleInstance`, `#Platform`, `#Subscription`, …); the operator's API types live independently in `opm-operator/api/v1alpha1/*_types.go` as hand-authored Go structs from which controller-gen generates the CRD YAML and deepcopy. The two are kept in sync by hand, and the CLI now consumes those same Go types — so drift between the CUE contract and the Go/CRD shape is a cross-repo correctness hazard, not a cosmetic one.

This enhancement makes the **CUE schema in `core/` the single source of truth** for the CRD-shaped types, and generates the downstream artefacts from it: the Kubernetes CRD YAML (via CUE's `encoding/openapi` structural-schema encoder), and the Go API types the operator and CLI compile against. The pieces CUE provably cannot own — `runtime.Object`/deepcopy boilerplate and CEL `x-kubernetes-validations` — are handled honestly: deepcopy stays controller-gen's job over the generated Go, and CEL rules are carried as CUE-expressed verbatim strings injected at assembly time. The non-schema CRD facets (scope, subresources, printer columns, short names) become **CUE data** alongside the schema, and a single Go assembler — consuming the *published* `opmodel.dev/core` module, never reaching into core's build — emits both outputs.

The design is grounded in a dated, primary-source research dossier ([`research/findings.md`](research/findings.md)); the verified state of the CUE v0.17 toolchain drives every decision, including the ones that say "don't try to derive this from CUE."

## Documents

1. [01-problem.md](01-problem.md) — Why defining the CRD types twice (canonical CUE in `core/` vs hand-authored Go in `opm-operator/`) is a live drift hazard now that the CLI also depends on the Go types
2. [02-design.md](02-design.md) — CUE owns schema + validation + CRD-metadata-as-data; a Go assembler over published `core` emits CRD YAML and Go types; controller-gen retained only for deepcopy; CEL passed through verbatim
3. [03-decisions.md](03-decisions.md) — Append-only decision log (D1–D8) and Open Questions
4. [04-graduation.md](04-graduation.md) — draft → accepted, accepted → implemented gates
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, and the Go-source-of-truth / CRD-pivot alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination

Pure-CUE schema definitions live under [`schemas/`](schemas/) as compilable files. External evidence lives under [`research/`](research/).

## Scope

### In scope

- A CUE-native way to declare a Kubernetes CRD in `core/`: a `#CRD` construct bundling group/kind/names/scope, per-version served/storage flags, the OpenAPIv3-compatible spec/status schema (which `core` already mandates), subresources, printer columns, short names, and verbatim CEL rules. Sketched end-to-end in [`schemas/target.cue`](schemas/target.cue).
- Re-expressing the three existing CRDs — `ModuleInstance` (namespaced), `ModulePackage` (namespaced), `Platform` (cluster singleton) — as `#CRD` instances in `core/`, reusing the existing domain definitions for the schema bodies.
- A generation pipeline that consumes the **published** `opmodel.dev/core` module and emits (a) the CRD YAML in `opm-operator/config/crd/bases/` and (b) the Go API types in `opm-operator/api/v1alpha1/`.
- Retaining controller-gen for `runtime.Object`/deepcopy generation over the generated Go structs; the generated structs carry the `+kubebuilder:object:root=true` marker so this keeps working unchanged.
- Carrying CEL `x-kubernetes-validations` (today: the Platform `metadata.name == 'cluster'` singleton rule) as CUE-expressed verbatim strings injected into the assembled CRD.
- A drift gate: CI fails if regenerating from `core` produces a diff against the committed CRD YAML / Go types.

### Out of scope

- **Translating CEL to/from CUE.** CEL rules are opaque strings carried through; the research shows bidirectional CEL↔CUE is unbounded work (`research/findings.md` §4). New validation logic that *could* be CEL stays authored as CEL.
- **Replacing controller-gen wholesale.** deepcopy stays controller-gen's job; this enhancement does not write a deepcopy generator.
- **Generating controllers, RBAC, or webhook wiring from CUE.** Only the CRD types (schema + metadata) and their Go shapes are in scope. RBAC/printer-column markers that live on controllers, and the reconcilers themselves, stay hand-authored.
- **The `v1alpha1 → v1beta1` API version bump or conversion webhooks.** This enhancement changes how the *current* version's types are authored, not the versioning story.
- **Schema redesign.** The field shapes are preserved; this is an authoring/generation change, not a schema change. Any field-level change rides a separate enhancement.
- **Adopting CUE as source of truth for non-CRD Go types** (inventory entries, internal structs). Only the API/CRD types.

## Relationship to 0006

[0006](../0006/) made the operator's `ModuleInstance` CR types a shared contract that the CLI imports directly (D13: CLI imports `library`; the operator owns the CRD types). That sharing is exactly what raises the stakes here: a single hand-maintained Go definition is now a multi-consumer contract, and its drift from the canonical `core/` CUE is felt in two repos at once. 0008 does not change 0006's runtime contract or handoff design — it changes where the `ModuleInstance`/`Platform` *type definitions* originate (CUE in `core/`, generated into Go) so the contract 0006 relies on cannot silently diverge from `core`.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + the area vocabulary the `area` / `affects` fields validate against. |
| `core/CLAUDE.md`, `core/CONSTITUTION.md`, `core/SPEC.md` | Core repo principles; the pure-CUE rule and the SPEC.md co-update gate the `core/` slice must honour (load `core-schema-edit` before editing `core/*.cue`). |
| `core/src/module_instance.cue`, `core/src/platform.cue` | The canonical `#ModuleInstance` / `#Platform` / `#Subscription` definitions the `#CRD` instances reuse for their schema bodies. |
| `core/src/resource.cue`, `core/src/trait.cue`, `core/src/module.cue` | The existing "spec MUST be OpenAPIv3-compatible" constraint this design depends on for clean structural-schema emission. |
| `opm-operator/CLAUDE.md`, `opm-operator/CONSTITUTION.md` | Operator repo principles governing the generator + API-type slice. |
| `opm-operator/api/v1alpha1/moduleinstance_types.go`, `modulepackage_types.go`, `platform_types.go`, `common_types.go` | The hand-authored Go types this enhancement replaces with generated output. |
| `opm-operator/api/v1alpha1/zz_generated.deepcopy.go` | controller-gen deepcopy output; stays controller-gen's, now run over generated structs. |
| `opm-operator/config/crd/bases/*.yaml` | The CRD YAML this enhancement generates from `core` instead of from Go markers. |
| `opm-operator/.tasks/dev.yaml` (`controller-gen … crd` / `object` targets), `Taskfile.yml` | The generation targets the new pipeline slots into. |
| `cli/` (imports the operator API types per 0006) | Downstream consumer of the generated Go types; must build unchanged against them. |
| `enhancements/0006/` | The CR-sharing design that makes this drift cross-repo; relationship described above. |
| `research/findings.md` | Dated, primary-source research dossier behind every decision (verified CUE v0.17 toolchain capabilities and gaps). |

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.
