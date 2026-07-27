# Enhancement 0012 — Kubernetes as a First-Class Kernel Platform

The OPM kernel renders and then stops. Everything that turns a rendered resource into cluster state — inventory, stale-set computation, prune safety, ownership guards, deletion — is written twice, once in `opm-operator` and once in `cli`, and the two copies have already diverged in ways that decide whether a resource is deleted. This enhancement makes Kubernetes the kernel's platform rather than one it abstracts over, and moves those decisions into `library/opm/` so that every implementor executes one definition of them.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

Today `Kernel.Compile` returns `[]*core.Compiled` and the frontends take it from there. Below that line, `cli/pkg/resourceorder/weights.go` and its operator twin are byte-identical, `pkg/core/{labels,resource,convert}.go` differ by three comment lines, and the render-digest function exists twice with a comment instructing future maintainers to keep the copies in sync by hand. Where the copies make *decisions* rather than copy fields, they have drifted: the CLI deletes `CustomResourceDefinition`s and the operator refuses to; the operator checks live ownership before deleting and the CLI does not; the CLI refuses to apply over a foreign object and the operator does not. Neither actor holds both guards — **each independently grew exactly the half the other lacks**.

This entry establishes that the Kubernetes runtime surface belongs in the kernel (**D1**) and that the kernel is written for Kubernetes without a portability abstraction maintained on its behalf (**D2**). It then asks how far past the render line the kernel goes: deciding what to do, or also doing it. The proposed boundary is asymmetric and lands exactly on this entry's scope — **share every decision; share execution only where execution carries no framework opinion.** Deletion qualifies. Apply does not, because the operator's apply is Flux SSA and the CLI must never inherit it.

On the deletion half specifically, enhancement 0010's **OQ10** is corrected: the claim that `ModuleInstance` has no finalizer is false — `opmodel.dev/cleanup` is registered at `opm-operator/internal/reconcile/moduleinstance.go:38` and drives a fully-tested cleanup path. The claim that nothing stamps `ownerReferences` is true. What OQ10 missed is that `spec.prune` defaults to false, so the finalizer's *default* behaviour is to orphan; that a CLI-owned instance carries no hold at all, so `kubectl delete` destroys the only inventory record and orphans every workload; and that an `ownerReference` garbage-collects regardless of `controller` or `blockOwnerDeletion`, which makes OQ10's additive-references candidate a silent contradiction of `prune: false` rather than a fast path over it.

This entry also re-opens a settled decision. Enhancement 0006 **D13.1** decided this shared logic "homes in `library` … required for correctness, not just tidiness"; it shipped as slice A3 and **D31** deleted it on 2026-07-01. D31's cross-actor safety analysis stands and is not disputed. Two of the three facts supporting its conclusion have since changed — the `go.mod` edge it declined to pay for was added 19 days later by 0006's own C2 slice, and its "third representation" objection applied to a runtime-neutral type that D2 removes. Its deferred **OQ15** and **OQ16** are absorbed here.

## Documents

1. [01-problem.md](01-problem.md) — One kernel, two Kubernetes runtimes: verified duplication, measured divergence, and the deletion gaps OQ10 did not identify
2. [02-design.md](02-design.md) — A Kubernetes tier in the kernel; share every decision, share execution only where it carries no framework opinion
3. [03-decisions.md](03-decisions.md) — Append-only decision log + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE definitions live in [`schemas/target.cue`](schemas/target.cue) — the ownership vocabulary, inventory wire shape, deletion policy, plan verdicts, ownerRef eligibility predicate, and the conformance property. It compiles, so a wrong shape is a build failure rather than a documentation bug.

## Scope

### In scope

- **The deletion protocol as kernel contract**: the hold (`opmodel.dev/cleanup`), the ordered deletion plan with typed skip reasons, and the verdict that decides when the hold may be released. Every branch the operator's `handleDeletion` takes today becomes a kernel case; the operator keeps the patch and the impersonation setup.
- **`ownerReferences`** — whether OPM stamps them at all, resolved against the `spec.prune` contradiction and the cluster-scope limitation rather than either alone. The eligibility predicate is specified either way.
- **The ownership guards, both directions**: the delete-time `managed-by` + instance-UUID check the CLI lacks, and the apply-time foreign/terminating refusal the operator lacks (0006 OQ16).
- **The duplicated Kubernetes surface**: label vocabulary, terminal object type, resource-order weights, inventory entry construction, stale-set computation, and the three digests — one definition each, in the kernel, with both frontends' copies deleted rather than aliased.
- **The stale-set base relation** — one comparator across implementors (0006 OQ15).
- **The kernel's dependency and constitutional bounds**: `k8s.io/apimachinery` enters `library`; `client-go`, `controller-runtime`, and Flux do not. `library/CONSTITUTION.md` Principle III's package list and Principle IV's runtime-concerns clause are amended, with an ADR recording the bound.
- **A conformance property** asserting an implementor cannot execute a delete the plan marked `skip` — the mechanism that makes this different from 0006's documented conventions.

### Out of scope

- **A kernel apply engine.** The operator keeps `fluxcd/pkg/ssa` and its staged apply; the CLI keeps its own. The kernel supplies apply *verdicts* only. A kernel apply executor should be refused if proposed during implementation.
- **The reconcile loop.** Watches, requeues, backoff, status conditions, events, and metrics stay in `opm-operator`. Command surface, output formatting, and exit codes stay in `cli`.
- **Credentials.** Kubeconfig resolution, rest.Config construction, and ServiceAccount impersonation are the frontends'.
- **The render half.** `opm/compile/` is untouched; this is additive below the render line.
- **The CRD Go types.** Whether `library` becomes their home is entangled with enhancement 0008 and is an open question here, not a deliverable.
- **Identity.** FQNs, module paths, `instanceUUID` derivation, and the identity migration belong to [0010](../0010/). This entry consumes whatever identity 0010 lands and compares label values without parsing them.
- **The execution half of the kernel** — `#Op` / `#Action` / `#Lifecycle` / `#Workflow` and `opm/flow/` belong to [0009](../0009/). The two entries overlap on the planner-plus-execution-seam convention, tracked as an open question rather than absorbed.
- **Re-deciding 0006 D31's data-flow analysis.** Only its placement conclusion is superseded.

## Deviations from Design

None at this stage. This entry is `draft`; deviations are recorded here when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary governing this multi-repo enhancement |
| `library/CONSTITUTION.md` | Principles I, III, IV — the neutrality clauses this entry amends |
| `library/CLAUDE.md` | Kernel-neutrality working rules; the helper-vs-kernel tier boundary the new packages sit across |
| `library/opm/core/resource.go` | The platform-neutral `Resource` / `Identity` contract naming compose, Nomad, Terraform, Crossplane — deleted or retained per OQ3 |
| `library/opm/core/compiled.go` | `Compiled`, the kernel's current terminal output |
| `library/opm/kernel/compile.go`, `library/opm/kernel/results.go` | `CompileResult` — where the Kubernetes-shaped output surfaces |
| `library/go.mod` | Gains `k8s.io/apimachinery`; the MVS floor this sets for every embedder |
| `library/MIGRATIONS.md` | Required entry per breaking change under the repo's `migration-guard` contract |
| `opm-operator/internal/reconcile/moduleinstance.go` | `FinalizerName` (`:38`), registration (`:97`), `handleCLIOwned` (`:519`), `handleDeletion` (`:590`), the `spec.prune` branch (`:600`) |
| `opm-operator/internal/apply/prune.go` | The delete-time ownership guard (`:99-114`) and safety exclusions (`:136`) the CLI lacks |
| `opm-operator/internal/apply/apply.go` | Flux SSA staged apply — kept, and the reason apply execution stays out of the kernel |
| `opm-operator/internal/inventory/` | Entry construction, both identity relations, stale set, digest — deleted in favour of the kernel |
| `opm-operator/pkg/core/`, `opm-operator/pkg/resourceorder/` | The operator half of the byte-identical duplication |
| `opm-operator/internal/render/module.go` | `buildInventoryEntries` — becomes a kernel call |
| `opm-operator/api/v1alpha1/moduleinstance_types.go` | `ModuleInstanceSpec.Prune` (no default — OQ5), `Owner`, `Status.Inventory`, `Status.InstanceUUID` |
| `cli/internal/inventory/stale.go` | `PreApplyExistenceCheck` (`:58`), `PruneStaleResources` (`:102`) and its Namespace-only exclusion (`:119`) |
| `cli/internal/inventory/digest.go` | `ComputeRenderDigest` and the hand-maintained parity comment this entry deletes |
| `cli/pkg/inventory/entry.go` | `ComputeStaleSet` over the component-aware relation (`:52`) — the OQ7 divergence |
| `cli/pkg/core/`, `cli/pkg/resourceorder/` | The CLI half of the byte-identical duplication |
| `cli/internal/kubernetes/delete.go` | The instance-delete walk that becomes a kernel plan |
| `cli/internal/cmd/instance/delete.go` | Ownership branch and the `spec.prune` warning surface |
| `cli/go.mod`, `opm-operator/go.mod` | Both pin `library v1.0.0-alpha.8` — the edge whose absence D31 priced |
| `core/src/transformer.cue` | `#TransformerContext` — where labels are composed and `#runtimeName` is filled (OQ11) |
| `core/src/module_instance.cue` | The deterministic instance UUID the ownership guard compares |
| `catalog_opm/src/resources/crd.cue`, `role.cue` | Cluster-scoped renderables that make a namespaced owner ineligible |
| `enhancements/0006/03-decisions.md` | D13, D31, OQ15, OQ16 — the decision this entry supersedes and the questions it absorbs |
| `enhancements/0010/03-decisions.md` | OQ10 — the question that surfaced this entry, corrected in `01-problem.md` |
| `enhancements/0008/` | CRD types from CUE — entangled via OQ9 |
| `enhancements/0009/` | The kernel's execution half — entangled via OQ10 (planner + execution seam) |
