# Design — Kubernetes as a First-Class Kernel Platform

Trade-off reasoning lives in [`03-decisions.md`](03-decisions.md). This document describes the shape.

## Design Goals

- **One implementation of every Kubernetes decision OPM makes.** Whether a stale entry is deleted, whether a live object may be deleted, what order deletes happen in, what a stale set is — each has exactly one definition, in the kernel, and every implementor executes it.
- **A new platform capability lands once.** Adding a safety check, a deletion policy, or an ownership rule is a kernel change that both the operator and the CLI inherit by upgrading. The current cost — two implementations in two repos plus a hand-maintained parity comment — is the thing being removed.
- **Deletion has one defined meaning.** Given an instance, its inventory, and its policy, what happens on delete is computed by the kernel and is identical across implementors, including the refusals and the reasons for them.
- **Divergence becomes a compile error, not a review comment.** A frontend that skips a guard should fail to build or fail a shared conformance test, not silently behave differently. This is what distinguishes this entry from 0006's OQ15/OQ16, which were the documented-convention approach and did not close.
- **The kernel stays deterministic and side-effect-free where it decides.** Planning what to do is pure and testable without a cluster; doing it is a separate, explicitly-invoked step.
- **The frontends keep what is genuinely theirs.** Credentials, impersonation, controller-runtime machinery, Flux, status conditions, events, output formatting, and command surface stay where they are.

## Non-Goals

- **Merging the two frontends.** The operator stays a controller and the CLI stays one-shot. This entry moves decisions, not architectures.
- **Making the library a Kubernetes client library.** It does not grow kubeconfig handling, credential resolution, impersonation, informers, work queues, or a scheme registry.
- **Adopting Flux SSA into the kernel.** `fluxcd/pkg/ssa` is the operator's staged-apply engine and must not become a CLI dependency. See the apply/delete asymmetry below.
- **Owning the reconcile loop.** Watches, requeues, backoff, conditions, and events remain the operator's.
- **Changing the render half.** `opm/compile/` is untouched; this is additive below the render line.
- **Re-deciding what 0006 D31 actually decided.** D31's cross-actor safety analysis stands. This entry supersedes its *conclusion about where the code lives*, on facts that changed after it was made — not its data-flow tracing.
- **Second-guessing 0010's identity work.** FQNs, module paths, and the identity migration are 0010's. This entry consumes whatever identity 0010 lands.

## High-Level Approach

Today the kernel stops at `[]*core.Compiled` and everything Kubernetes-shaped happens above it, twice. The question this entry answers is **how far past that line the kernel goes**. It is useful to name the rungs, because the answer is not "all the way" and the reason is specific.

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Rung 4   kernel owns the CR         types, status, conditions        │  ← 0008's territory
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 3   kernel ACTS                executes a plan against a        │  ← behaviour actually
 │                                     caller-supplied object client    │     unified
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 2   kernel DECIDES             stale set, prune plan, ownership │  ← what D31 deleted
 │                                     verdicts, deletion state machine │
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 1   kernel EMITS               Compile → K8s objects + entries  │  ← kills the pkg/core
 │                                                                      │     duplication
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 0   today                      Compile → []*core.Compiled       │
 └─────────────────────────────────────────────────────────────────────┘
```

**Rung 2 alone is what 0006 already reverted.** A package of pure helpers that nothing forces a frontend to call is precisely what D31 called "actively misleading… that nothing actually imports". The design goal "divergence becomes a compile error" is not met at Rung 2: a frontend can import the plan and then not follow it, which is exactly how the CLI came to lack a CRD exclusion the operator has.

**Rung 3 is where behaviour is actually unified** — but it cannot be applied uniformly, because apply and delete are not symmetric:

```
   DELETE                                    APPLY
   ──────                                    ─────
   order → get → guard → delete              operator: fluxcd/pkg/ssa
                                                       (staged, readiness waits,
   No framework opinion.                                CRD/Namespace first)
   Expressible over apimachinery
   plus a two-method interface.              cli:      its own SSA engine

   ✅ kernel owns the execution              A framework opinion, and a heavy
                                             dependency the CLI must never inherit.

                                             ❌ kernel owns the verdict only
```

So the proposed boundary is: **share every decision; share execution only where execution carries no framework opinion.** Deletion qualifies. Apply does not — the kernel computes apply verdicts (including the collision guard the operator lacks) and each frontend applies with its own engine.

That boundary is not a compromise around this entry's scope; it lands exactly on it. Deletion, ownership, and the finalizer protocol — OQ10's subject — are the part of the pipeline with no framework opinion, and therefore the part the kernel can own outright.

### What "first-class Kubernetes platform" means concretely

The kernel gains a Kubernetes tier that is not an adapter bolted onto a neutral core, but the platform the kernel is written for. Three consequences follow, and each is a real decision rather than a detail:

1. **The kernel's terminal output becomes a Kubernetes object,** not a CUE value an adapter wraps. `cli/pkg/core` and `opm-operator/pkg/core` are deleted rather than aliased.
2. **`k8s.io/apimachinery` enters the library's dependency set,** and — by MVS, exactly as the CUE SDK already does — becomes a floor for every embedder. Nothing heavier: no `client-go`, no `controller-runtime`, no Flux. Whether the neutral `core.Resource`/`Identity` contract is deleted or retained-and-implemented is OQ3; the dependency arrives either way.
3. **The library's constitution needs amending, narrowly.** Principle I (kernel neutrality) is about *runtime* neutrality — no globals, no `os.Exit`, no hidden env, I/O at the edges with caller-supplied config — and a Kubernetes tier does not violate any of it; the registry loader already performs OCI network I/O under exactly those terms. What does need changing is Principle III's package list, Principle IV's "`opm/` packages MUST NOT import command, controller, or runtime-specific concerns", and the platform-neutrality promise in `opm/core/resource.go`'s doc comment. That is an ADR in `library/` plus a `CONSTITUTION.md` edit, not a rewrite.

### The deletion protocol

Deletion becomes a kernel-owned state machine over inputs the kernel already understands, producing a plan the caller executes and a verdict the caller obeys:

```
   inputs                          kernel                        caller
   ──────                          ──────                        ──────
   inventory entries
   instance identity (UUID)   ┌──────────────────┐
   deletion policy            │  DeletionPlan()  │──▶ ordered []PlannedAction
   live object state          │                  │      each: Delete | Skip(reason)
                              └──────────────────┘
                                       │
                                       ▼                        executes via
                              ┌──────────────────┐              ObjectClient,
                              │ MayReleaseHold() │──▶ verdict   or lets the kernel
                              └──────────────────┘              executor walk it
                                Release | Hold(reason)
```

Everything the operator's `handleDeletion` branches on today — prune disabled, empty inventory, partial failure, the force-orphan annotation — becomes a case in `MayReleaseHold`. The operator keeps the finalizer patch (a `client.Patch`, which needs its client) and keeps the impersonation setup (credentials). It stops owning the decision of *when* the hold may be released.

The CLI runs the same protocol for its own delete, and — separately, as OQ6 — the question of whether CLI-owned CRs should carry a hold at all becomes answerable, because "what would clean up" now has one definition rather than being an operator-private code path.

### `ownerReferences`

The analysis in [`01-problem.md`](01-problem.md) §6 points at one conclusion, recorded as OQ4 rather than as a decision because it is this entry's to make rather than one already made: **ownerReferences are the wrong mechanism for OPM's output**, and the decisive reason is not the cluster-scope limitation OQ10 leads with but the contradiction with `spec.prune`. A reference that garbage-collects regardless of policy cannot be an additive fast path under a policy whose default is "do not collect". The candidate this design carries forward is OQ10's (a) — inventory plus labels plus a hold — with the mechanism made kernel-owned so that "OPM cleans up its own resources" is one implementation rather than one-and-a-half.

## Schema / API Surface

The full target shape lives in [`schemas/target.cue`](schemas/target.cue) and compiles. It is CUE rather than Go because the surface that matters here is the *contract* both Go implementations must satisfy — the inventory wire shape, the label vocabulary, the deletion policy, the verdict enums, the ownerRef eligibility predicate — and that contract is already anchored in CUE and the CRD schema rather than in either frontend's structs.

The Go package layout it implies, subject to OQ1 and OQ2:

| Package | Owns | Depends on |
| --- | --- | --- |
| `opm/k8s/labels` | the label and annotation vocabulary, `IsOPMManagedBy`, runtime-name values | — |
| `opm/k8s/object` | the terminal Kubernetes object; replaces both `pkg/core` copies; resource-order weights | `apimachinery` |
| `opm/k8s/inventory` | `Entry`, one `ComputeStaleSet`, one `ComputeDigest`, one `RenderDigest` | `apimachinery` |
| `opm/k8s/ownership` | `SafetyExcluded`, `CanDelete`, `CanApply`, `EligibleForOwnerRef` | `apimachinery` |
| `opm/k8s/lifecycle` | hold name, `DeletionPlan`, `MayReleaseHold` | `apimachinery` |
| `opm/helper/k8s/executor` | walks a plan against a caller-supplied `ObjectClient` (opt-in, helper tier) | `apimachinery` |

`opm/helper/` is the established opt-in tier — a frontend may skip it and call the kernel directly — which is the right home for the one piece that touches a cluster.

## Integration Points

### library

- `opm/core/resource.go`, `opm/core/compiled.go` — the neutral `Resource`/`Identity` contract; deleted or retained-and-implemented per OQ3.
- `opm/kernel/compile.go`, `opm/kernel/results.go` — `CompileResult` gains the Kubernetes-shaped output.
- `opm/k8s/**` — new tier, per the table above.
- `opm/helper/k8s/executor` — new, opt-in.
- `go.mod` — `k8s.io/apimachinery` added.
- `CONSTITUTION.md` + `adr/` — Principle III/IV amendment and the ADR recording it.
- `MIGRATIONS.md` — required if OQ3 lands as a deletion.

### opm-operator

- `pkg/core/{labels,resource,convert,compiled_adapter}.go`, `pkg/resourceorder/` — deleted; kernel types used directly.
- `internal/inventory/**` — deleted; kernel inventory used directly.
- `internal/apply/prune.go` — collapses into the kernel plan plus the helper executor.
- `internal/apply/apply.go` — keeps Flux SSA; gains the kernel's apply verdicts (this is 0006 OQ16's fix).
- `internal/reconcile/moduleinstance.go` — `handleDeletion` keeps the patches and impersonation, delegates the branching to `MayReleaseHold`.
- `internal/render/module.go` — `buildInventoryEntries` becomes a kernel call.

### cli

- `pkg/core/**`, `pkg/inventory/**`, `pkg/resourceorder/**` — deleted; kernel types used directly.
- `internal/inventory/{digest,stale}.go` — `ComputeRenderDigest` and the parity comment deleted; `PruneStaleResources` collapses into the kernel plan plus the helper executor, gaining the CRD exclusion and the delete-time ownership guard.
- `internal/inventory/stale.go` — `ApplyComponentRenameSafetyCheck` deleted if OQ7 standardises on the component-blind comparator, which makes the post-filter unnecessary by construction.
- `internal/kubernetes/delete.go` — the instance-delete walk becomes the kernel plan.
- `internal/cmd/instance/delete.go` — unchanged in shape; the outcomes it reports become kernel-computed.

## Before / After

The `postgres` CRD-removal scenario from [`01-problem.md`](01-problem.md):

**Before**

```
stale entry: CustomResourceDefinition/backups.example.com

  operator ──▶ isSafeToDelete()        ──▶ skip, log, PruneResult.Skipped++
  cli      ──▶ Kind == "Namespace"?    ──▶ no ──▶ DELETE
                                                  └─▶ every Backup CR, cluster-wide
```

**After**

```
stale entry: CustomResourceDefinition/backups.example.com

  operator ─┐
            ├──▶ lifecycle.DeletionPlan()  ──▶  Skip{reason: SafetyExcluded}
  cli      ─┘                                    (one implementation, one reason string,
                                                  one test asserting it)
```

And the deletion-policy branch:

**Before** — the operator's `handleDeletion` decides; the CLI has no equivalent concept; a CLI-owned CR has no hold at all, so `kubectl delete` bypasses both.

**After** — `MayReleaseHold` decides, from the policy and the plan's outcome, for whichever implementor is asking. Whether a CLI-owned CR carries a hold becomes a policy input rather than a property of which code path happened to run (OQ6).
