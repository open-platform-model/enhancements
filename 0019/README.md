# Enhancement 0019 — Kernel render path parity with pure CUE

The kernel does not hand a transformer what CUE would hand it. Before rendering, it converts each component into a "data" value using `cue.Final()`, and that call deletes every definition field. So `#component.#names`, the identity `core/SPEC.md` calls "the single source of truth for this component's identity", does not exist inside any `#transform`, along with `#resources`, `#traits` and `#instance`. A third declared input, `#moduleInstance`, is never filled at all. This enhancement makes plain CUE unification the reference semantics of the render path, and closes the gaps by removing kernel behaviour rather than by adding more of it.

See [`config.yaml`](config.yaml) for the metadata contract; it is the sole source of metadata, and no parallel metadata table lives in this README.

## Summary

A pure-CUE control settles what the target behaviour is. Unifying a real `#ModuleInstance`'s component into a real transformer's `#transform`, with the transformer arriving by import from a separate package, preserves **every** field and evaluates fully concrete: `#names.dns.fqdn` renders `web.prod.svc.cluster.local`, `#resources` renders its FQN list, `#moduleInstance.metadata.fqn` renders the instance identity, and `cue vet -c` exits 0. The kernel is the only thing that removes anything.

The premise that justified the removal is also falsified there. The behaviour dates to a March 2026 `cli` experiment whose design document records the reason as "`FillPath` on `#component` fails with schema constraints present". The component in the control carries those constraints (its `spec` is genuinely closed, verified by an unknown field being refused), and it renders anyway. `cue.Final()` was reached for to strip validators and `close()`; `omitDefinitions` is one of the four switches it flips, and dropping definitions was collateral rather than intent. Three later changes removed the conditions that motivated it, and none prompted a re-examination.

Measured on the kernel side: filling `#component` from the unstripped value leaves the full library suite green across 14 packages, including both closedness regression guards and the CUE canary pair; a transformer then renders `#component.#names.dns.fqdn`, which fails on the unmodified kernel. The ADR-003 output-local hidden field hazard does not reproduce, and defaulted disjunctions still resolve without `cue.Final()`.

The design's load-bearing artifact is not the fix but the **parity oracle**: a differential harness comparing the kernel's rendered value against pure-CUE unification of the same three inputs. It is what turns "stay compatible with CUE" from an intention into an invariant, and its first failure is the evidence for the whole entry.

One finding changes the authoring contract independently of any code. CUE resolves references **lexically**, so a transformer must re-declare a slot in its own `#transform` body to reference it. That is why shipped transformers write `#component: _` despite `core` already declaring it, and why `#moduleInstance` becomes author-visible only once someone tries to use it.

## Documents

The six split documents below are mandatory and always present.

1. [01-problem.md](01-problem.md): the render path forks one component into two values and hands the transformer the lossy branch; the premise that justified it does not hold in CUE
2. [02-design.md](02-design.md): parity as the contract, the differential oracle, the fills, and the fixture that has to move first
3. [03-decisions.md](03-decisions.md): decision log (D1 through D4) + Open Questions (OQ1 through OQ5)
4. [04-graduation.md](04-graduation.md): per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md): risks and mitigations, drawbacks, high-level alternatives
6. [06-operational.md](06-operational.md): operational concerns (PRR-lite), including the landing order

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue), which states the parity contract, the runtime's fill obligations per input and which field classes each must preserve, the execution unit, and the lexical-declaration obligation on transformer authors.

## Scope

### In scope

- Making pure-CUE unification the reference semantics of the render path, enforced by a differential parity harness in `library` rather than by review.
- Filling `#transform.#component` from the unstripped component value, so definition fields reach transformers.
- Filling `#transform.#moduleInstance`, the third input `core` declares and the kernel has never supplied.
- Removing `FinalizeValue` from the render path, and subsequently from the public kernel surface, with the `MIGRATIONS.md` entry that break requires.
- Repairing `TestFlow_WebApp_OnOpmPlatform`'s instance construction, which severs the reference wiring `#instance` and must land with the slice that exposes definitions rather than after it.
- Recording the lexical-declaration rule as an authoring obligation.

### Out of scope

- **The single-build render pipeline.** Raised by this work and deliberately unresolved: ADR-003 chose federation because a platform could hold several versions of one catalog major, and enhancement 0010 D14 subsequently deleted that capability. Whether the premise is stale is OQ1 through OQ3, and OQ3 is a genuine design fork rather than a verification task.
- **Matching.** How components pair with transformers is untouched.
- **Changing the execution unit.** One component per `#transform` evaluation is the original design intent and stays (D2).
- **Removing `#moduleInstance` from the schema.** It is intended surface; the fix is to fill it (D3).
- **The `catalog_opm` transformer sweep.** open-platform-model/catalog_opm#44 and open-platform-model/core#49 remain worth landing on their own merits, because the computed name genuinely does not match the rendered name. This entry removes the part of their justification that reads "no transformer can read `#names` anyway".
- **Improving the empty-disjunction error.** Filling all three inputs removes the most common way to reach it; the message itself stays as unhelpful as it is today.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `library/CONSTITUTION.md` | Kernel neutrality and small-batch principles governing every slice here |
| `library/adr/003-no-cross-build-fillpath-into-closed-values.md` | The no-cross-build-fill invariant, and the federation premise OQ1 re-examines |
| `library/docs/design/repro-purecue-definitions/` | The pure-CUE control this entry rests on |
| `library/docs/design/transformer-output-hidden-field-scope-bug.md` | The closedness corruption whose hazard shape was probed and did not reproduce |
| `library/docs/design/cue-closedness-regression-alpha2.md` | The unfixed upstream evaluator regression the canary pair pins |
| `library/opm/compile/execute.go` | `executePair`, the fill site |
| `library/opm/compile/finalize.go` | `FinalizeValue`, the strip |
| `library/opm/kernel/compile.go` | Where one components value forks into two |
| `library/opm/kernel/phases.go` | The public kernel wrapper over `FinalizeValue` |
| `library/opm/schema/paths.go` | Path constants; gains `ModuleInstance` |
| `library/opm/schema/context.go` | Go-side `#context` construction, deleted if OQ5 resolves toward projection |
| `library/opm/kernel/flow_integration_test.go` | The fixture whose instance construction severs `#instance` |
| `library/opm/materialize/composed_open_test.go` | Closed-platform corruption guard that must keep passing |
| `library/opm/internal/cueregression/closedness_test.go` | The CUE canary pair |
| `library/MIGRATIONS.md` | Records the `FinalizeValue` removal |
| `core/src/transformer.cue` | `#transform`'s three declared inputs and `#TransformerContext` |
| `core/src/component.cue` | `#names`, the projection the render path cannot currently read |
| `core/src/platform.cue` | `#registry`, whose one-subscription-per-path shape underlies OQ1 |
| `core/SPEC.md` | Co-update target if OQ5 resolves toward projection |
