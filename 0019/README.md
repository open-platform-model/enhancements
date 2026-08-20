# Enhancement 0019 — Kernel render path parity with pure CUE

The kernel does not hand a transformer what CUE would hand it. Before rendering, it converts each component into a "data" value using `cue.Final()`, and that call deletes every definition field. So `#component.#names`, the identity `core/SPEC.md` calls "the single source of truth for this component's identity", does not exist inside any `#transform`, along with `#resources`, `#traits` and `#instance`. A third declared input, `#moduleInstance`, is never filled at all. This enhancement makes plain CUE unification the reference semantics of the render path and closes the gaps by removing kernel behaviour rather than by adding more of it — first from the render path as it stands, and then by removing the multi-build architecture that made the removal reachable in the first place.

See [`config.yaml`](config.yaml) for the metadata contract; it is the sole source of metadata, and no parallel metadata table lives in this README.

## Summary

**Parity is the contract; the single build is what makes it structural.** The entry is one arc executed in two phases, and its design doc states the relationship in one line: two changes that turn out to be the same change.

A pure-CUE control settles what the target behaviour is. Unifying a real `#ModuleInstance`'s component into a real transformer's `#transform`, with the transformer arriving by import from a separate package, preserves **every** field and evaluates fully concrete: `#names.dns.fqdn` renders `web.prod.svc.cluster.local`, `#resources` renders its FQN list, `#moduleInstance.metadata.fqn` renders the instance identity, and `cue vet -c` exits 0. The kernel is the only thing that removes anything. The premise that justified the removal is falsified there too: the behaviour dates to a March 2026 `cli` experiment whose stated reason ("`FillPath` on `#component` fails with schema constraints present") does not reproduce — the control's component carries genuine closedness and renders anyway. `cue.Final()` was reached for to strip validators and `close()`; dropping definitions was collateral.

**Phase A** makes the current path honest: fill `#transform.#component` from the unstripped value, fill `#transform.#moduleInstance` for the first time, remove `FinalizeValue` from the render path and then from the public surface, and repair the flow fixture whose instance construction severs `#instance`. It is library-local, evidence-complete, and lands first — no Phase A slice depends on anything in Phase B.

**Phase B** removes the reason the strip was reachable: the render step becomes **one CUE build per render** (D9). The kernel stages the instance and the platform into a generated render module and evaluates it once; nothing crosses a build boundary, so nothing needs stripping, and parity stops being a property the kernel maintains and becomes one it cannot violate. That collapse carries the platform reshape it requires — a registry entry imports its catalog and embeds the transformer map, replacing the `version!` scalar (D5); the operator generates the platform package the CR describes (D6); module-versus-platform version skew becomes a kernel-detected, caller-configured signal (D7); ADR-002's shared-materialized-platform model is superseded by shares-nothing renders (D8); and matching moves into the build with its verdicts as data (D10).

The design's load-bearing artifact across both phases is the **parity oracle**: a differential harness comparing the kernel's rendered value against pure-CUE unification of the same three inputs. It lands before any fix, its first failure is the evidence for the whole entry, it proves each Phase B slice produces what the old path produced, and it survives as the tripwire against a future Go-side transformation of a component value.

The collapse is not only a correctness argument; the architecture it replaces is also the measured-expensive one. Eight concluded experiments put numbers on it: the shared-platform model races under concurrent render (2321 detector reports, unfixed by pre-evaluation) and retains 348 MB per render by construction; a shares-nothing single build is cheaper per component at every size, crosses over at roughly a dozen components, parallelises at ~4x on eight cores independent of module size, and beats today's path serialised as its races require by 2.5x to 5.5x at every size — while retaining 117 KB per render. The honest asterisk rides along: sequentially, small modules pay a fixed ~85 ms catalog term, making a two-component render 1.7x-2.1x slower in isolation.

One finding changes the authoring contract independently of any code. CUE resolves references **lexically**, so a transformer must re-declare a slot in its own `#transform` body to reference it. That is why shipped transformers write `#component: _` despite `core` already declaring it, and why `#moduleInstance` becomes author-visible only once someone tries to use it.

## Documents

The six split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md): the render path forks one component into two values and hands the transformer the lossy branch; the premise that justified it does not hold in CUE; and the multi-build architecture that made it reachable is also the one that races, retains, and serialises
2. [02-design.md](02-design.md): parity as the contract, the differential oracle, the fills, the single-build render step and the platform shape that makes it resolvable, what matching costs (measured), and the fixture that has to move first
3. [03-decisions.md](03-decisions.md): decision log (D1 through D10) + Open Questions (OQ1 through OQ14)
4. [04-graduation.md](04-graduation.md): per-status gates (draft → accepted → implemented), phased
5. [05-risks.md](05-risks.md): risks and mitigations, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md): operational concerns (PRR-lite), including the two-phase landing order and the interim operator stopgap

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue), which states the parity contract, the runtime's fill obligations per input and which field classes each must preserve, the execution unit, the lexical-declaration obligation on transformer authors, and the D5 registry-entry shape.

Cross-repo sequencing lives in [`plan.yaml`](plan.yaml) (rendered as [PLAN.md](PLAN.md)): Phase A slices carry no dependency on Phase B, which is the structural guarantee that the ready half is never hostage to the unready half.

## Scope

### In scope

**Phase A — parity on the current path:**

- Making pure-CUE unification the reference semantics of the render path, enforced by a differential parity harness in `library` rather than by review.
- Filling `#transform.#component` from the unstripped component value, so definition fields reach transformers.
- Filling `#transform.#moduleInstance`, the third input `core` declares and the kernel has never supplied.
- Removing `FinalizeValue` from the render path, and subsequently from the public kernel surface, with the `MIGRATIONS.md` entry that break requires.
- Repairing `TestFlow_WebApp_OnOpmPlatform`'s instance construction, which severs the reference wiring `#instance` and must land with the slice that exposes definitions rather than after it.
- Recording the lexical-declaration rule as an authoring obligation.
- The read-only names contract (D15): transformers read `#component.#names.resourceName` and its DNS variants, and never derive a name of their own — generation stays upstream on `#Component`. The `catalogs/opm` sweep that rewrites every hand-rolled name formula to read `#names` lands as the `catalog-names-readonly` slice, gated on the `#component` fill that makes `#names` readable.
- The instance-qualified `resourceName` default (D16): `metadata.resourceName` defaults to `<instance>-<component>` (validated against `#NameType`) instead of the bare component name, fixing the cross-instance collision the bare default admits; a `core` slice gated on the sweep, breaking by intent for rendered fleets.
- The `env`-ordering migration note (OQ14): removing the strip changes list ordering for modules that assemble environments conditionally, so the note attaches to Phase A's landing, not to the collapse.

**Phase B — the single-build collapse:**

- The render step as one CUE build per render (D9): the kernel-generated render module, its `cue.mod` as the resolution, directory replacements for the unpublished inputs, and the OQ6 invariant on what that file owes.
- `#Platform.#registry` entries carrying the catalog by import (`{enable, #transformers}`), with the `version!` scalar removed (D5), and `#composedTransformers` becoming derived.
- The operator generating the platform package its CR describes (D6).
- Kernel-detected, caller-configured module-versus-platform skew (D7).
- Superseding ADR-002 with shares-nothing renders and the `cue.Context` lifetime rule (D8), including removal of `opm-operator`'s single held platform slot.
- Matching moving into the render build with verdicts as data, per experiment 05's measured glue shape (D10); the D30 provenance carve-out is deleted rather than ported.
- `opm/materialize` shrinking to the point of deletion, replaced by the platform's own imports.

### Out of scope

- **Matching semantics.** How components pair with transformers is untouched in both phases — experiment 05's gate for D10 is that the moved matcher reproduces the kernel's exact pair set. Where matching *executes* changes; what it *decides* does not.
- **Changing the execution unit.** One component per `#transform` evaluation is the original design intent and stays (D2).
- **Removing `#moduleInstance` from the schema.** It is intended surface; the fix is to fill it (D3).
- **Per-transformer selection in the platform file.** D5 embeds a catalog's transformer map whole; choosing among transformers belongs to enhancement 0015 (provider classes, `TransformerRegistration`), as do the runtime-registration questions this entry defers there (OQ9, OQ10).
- **Publishing platforms to a registry.** Disallowed (D6, revised 2026-08-20) — the generated `#Platform` package is build-local by construction, and the reserved namespace stays reserved-unpublished; OQ11 is resolved by that revision.
- **The core-side name workaround.** open-platform-model/core#49's approach — copying the computed name into a regular field — is made unnecessary rather than implemented: the transformer sweep it motivated is now in scope (D15, `catalog-names-readonly`), reading the projection instead of duplicating it.
- **Improving the empty-disjunction error.** Filling all three inputs removes the most common way to reach it; the message itself stays as unhelpful as it is today.
- **A publish-side gate forbidding unstated trait posture.** Experiment 05 measured that an unstated `optional` posture refuses as a build error rather than as a diagnostics row; making it data would need publish-side enforcement of 0010 D46's authoring rule, which belongs to the publish-gate family (0011), not here.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `library/CONSTITUTION.md` | Kernel neutrality and small-batch principles governing every slice here |
| `library/adr/002-concurrent-render-shared-materialized-platform.md` | Superseded by D8; gains the superseded-by header in a Phase B slice |
| `library/adr/003-no-cross-build-fillpath-into-closed-values.md` | The no-cross-build-fill invariant, and the federation premise D9 retires |
| `library/docs/design/repro-purecue-definitions/` | The pure-CUE control this entry rests on |
| `library/docs/design/transformer-output-hidden-field-scope-bug.md` | The closedness corruption whose hazard shape was probed and did not reproduce |
| `library/docs/design/cue-closedness-regression-alpha2.md` | The unfixed upstream evaluator regression the canary pair pins |
| `library/opm/compile/execute.go` | `executePair`, the Phase A fill site |
| `library/opm/compile/finalize.go` | `FinalizeValue`, the strip — removed in Phase A |
| `library/opm/compile/match.go` | The Go matcher D10 moves into the build; its D30 carve-out is deleted with federation |
| `library/opm/kernel/compile.go` | Where one components value forks into two |
| `library/opm/kernel/phases.go` | The public kernel wrapper over `FinalizeValue` |
| `library/opm/materialize/index.go` | `indexCatalogs`; shrinks or goes under D5 |
| `library/opm/schema/paths.go` | Path constants; gains `ModuleInstance` |
| `library/opm/schema/context.go` | Go-side `#context` construction, deleted if OQ5 resolves toward projection |
| `library/opm/kernel/flow_integration_test.go` | The fixture whose instance construction severs `#instance` |
| `library/opm/materialize/composed_open_test.go` | Closed-platform corruption guard that must keep passing |
| `library/opm/internal/cueregression/closedness_test.go` | The CUE canary pair |
| `library/MIGRATIONS.md` | Records the `FinalizeValue` removal and the OQ14 ordering note |
| `core/src/platform.cue` | `#registry`; reshaped by D5 with a `SPEC.md` co-update under the `core-schema-edit` protocol |
| `core/src/transformer.cue` | `#transform`'s three declared inputs and `#TransformerContext` |
| `core/src/component.cue` | `#names`, the projection the render path cannot currently read |
| `catalog_opm/src/` | The 35 transformers whose hand-rolled name formulas the `catalog-names-readonly` slice rewrites to read `#component.#names` (D15) |
| `core/SPEC.md` | Normative co-update for D5, and for OQ5 if it resolves toward projection |
| `opm-operator/api/v1alpha1/platform_types.go` | The CR that keeps naming a catalog coordinate while the operator generates the package (D6) |
| `opm-operator/internal/platform/store.go` | The single held slot that loses its reason to exist under D8 |
| `cli/` | Render command configuration — D7's policy surface |
| `enhancements/0015/` | Provider classes and `TransformerRegistration`; OQ9/OQ10 defer there, and its integration surface re-baselines when this entry reaches `accepted` |
| `enhancements/0011/` | The publish-gate family; candidate home for the unstated-posture gate experiment 05 surfaced |
