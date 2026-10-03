# Design: Kubernetes as a First-Class Library Tier

Trade-off reasoning lives in [`03-decisions.md`](03-decisions.md). This document describes the shape.

## Design Goals

**One shared Kubernetes tier**

- **One implementation of every Kubernetes decision OPM makes.** Whether a stale entry is deleted, whether a live object may be deleted, what order deletes happen in, what a stale set is: each has exactly one definition, in the library's Kubernetes tier, and every implementor executes it.
- **A new platform capability lands once.** Adding a safety check, a deletion policy, or an ownership rule is a library change that both the operator and the CLI inherit by upgrading. The current cost (two implementations in two repos plus a hand-maintained parity comment) is the thing being removed.
- **Deletion has one defined meaning.** Given an instance, its inventory, and its policy, what happens on delete is computed by the library and is identical across implementors, including the refusals and the reasons for them.
- **Divergence becomes a compile error, not a review comment.** A frontend that skips a guard should fail to build or fail a shared conformance test, not silently behave differently. This is what distinguishes this entry from 0006's OQ15/OQ16, which were the documented-convention approach and did not close.

**Library discipline**

- **The library stays deterministic and side-effect-free where it decides.** Planning what to do is pure and testable without a cluster; doing it is a separate, explicitly-invoked step.
- **The frontends keep what is genuinely theirs.** Credentials, impersonation, controller-runtime machinery, Flux, status conditions, events, output formatting, and command surface stay where they are.

## Non-Goals

**What stays where it is**

- **Merging the two frontends.** The operator stays a controller and the CLI stays one-shot. This entry moves decisions, not architectures.
- **Making the library a Kubernetes client library.** It does not grow kubeconfig handling, credential resolution, impersonation, informers, work queues, or a scheme registry.
- **Adopting Flux SSA into the library.** `fluxcd/pkg/ssa` is the operator's staged-apply engine and must not become a CLI dependency. See the apply/delete asymmetry below.
- **Owning the reconcile loop.** Watches, requeues, backoff, conditions, and events remain the operator's.
- **Changing the render half.** `Kernel.Render` is untouched; this is additive below the render line.

**Other entries' decisions**

- **Re-deciding what 0006 D31 actually decided.** D31's cross-actor safety analysis stands. This entry supersedes its *conclusion about where the code lives*, on facts that changed after it was made, not its data-flow tracing.
- **Second-guessing 0010's identity work.** FQNs, module paths, and the identity migration are 0010's. This entry consumes whatever identity 0010 lands.

## High-Level Approach

Today the kernel stops at `[]*kernel.Compiled` and everything Kubernetes-shaped happens above it, twice. The question this entry answers is **how far past that line the kernel goes**. It is useful to name the rungs, because the answer is not "all the way" and the reason is specific. The ladder predates 0012:D3, which places this code in the library's `opm/k8s` tier beside the kernel package; read "kernel" on the rungs as that tier.

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │ Rung 4   kernel owns the CR         types, status, conditions        │  <- 0008's territory
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 3   kernel STEPS               advances a plan one action per   │  <- behaviour actually
 │                                     call; the caller performs it     │     unified (ADR-008)
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 2   kernel DECIDES             stale set, prune plan, ownership │  <- what D31 deleted
 │                                     verdicts, deletion state machine │
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 1   kernel EMITS               Render -> K8s objects + entries  │  <- kills the pkg/core
 │                                                                      │     duplication
 ├─────────────────────────────────────────────────────────────────────┤
 │ Rung 0   today                      Render -> []*kernel.Compiled     │
 └─────────────────────────────────────────────────────────────────────┘
```

**Rung 2 alone is what 0006 already reverted.** A package of pure helpers that nothing forces a frontend to call is precisely what D31 called "actively misleading… that nothing actually imports". The design goal "divergence becomes a compile error" is not met at Rung 2: a frontend can import the plan and then not follow it, which is exactly how the CLI came to lack a CRD exclusion the operator has.

**Rung 3 is where behaviour is actually unified, and library ADR-008 fixes its shape.** An earlier draft of this entry put a plan-walking loop in the kernel, executing against a caller-supplied object client. ADR-008 rules that out for the whole library. Rule 1 says the kernel plans and the caller runs, and that the library ships no loop that drives a plan to completion. Rule 3 says the kernel names an action and never performs one. An in-place amendment citing library ADR-011 limits its allowance for opt-in executor backends under `opm/helper/` to executor backends that perform no planned action against a cluster, so no code in the library performs a planned action against a cluster (0012:D3). That amends 0009:D4: 0009's wasm, HTTP, `cue.eval` and local container hosts may stay there, and its k8s get/apply Ops and Job-rendering container variant are performed by the frontend (0012:OQ10). What the library supplies instead is a transition. The caller asks for the next action, performs it, and hands back the result; the state is a serialisable value the caller owns, so a controller can carry it across reconciles and a one-shot frontend can hold it in memory.

That shape is the first half of 0012:OQ1's answer; 0012:D4 gives the second, the apply/delete asymmetry below. A frontend cannot decline to follow the decisions, because calling the transition is the only way to make progress, and it inherits no framework opinion, because it performs every action itself.

Apply and delete remain asymmetric in how much of the sequence the library owns (0012:D4):

```
   DELETE                                    APPLY
   ------                                    -----
   order -> get -> guard -> delete           operator: fluxcd/pkg/ssa
                                                       (staged, readiness waits,
   No framework opinion.                                CRD/Namespace first)
   The tier owns the whole
   sequence and names each action;           cli:      its own SSA engine
   the caller performs it.
                                             A framework opinion, and a heavy
                                             dependency the CLI must never inherit.

                                             The tier owns the per-object
                                             verdict and order; engine stays.
```

So the boundary, fixed by 0012:D4, is: **share every decision; share the sequence only where it carries no framework opinion; never share the doing.** Deletion qualifies for the sequence. Apply does not. The library computes apply verdicts (including the collision guard the operator lacks) and the apply order, and each frontend applies with its own engine.

That boundary is not a compromise around this entry's scope; it lands exactly on it. Deletion, ownership, and the finalizer protocol (0010:OQ10, corrected in `01-problem.md`) are the part of the pipeline with no framework opinion, and therefore the part the library can own outright.

### What "first-class Kubernetes platform" means concretely

The library gains a Kubernetes tier. Kubernetes is the platform the library is written for (0012:D2), so the tier is no adapter over a neutral core. It sits beside the kernel package, outside both the kernel and the opt-in helper tier (0012:D3). Four consequences follow, and each is a real decision rather than a detail:

1. **The library's terminal output for Kubernetes is a Kubernetes object.** The tier converts the kernel's compiled output into objects, and `cli/pkg/core` and `opm-operator/pkg/core` are deleted rather than aliased. The kernel's own output stays what it is, so the kernel stays "CUE in, verdicts out".
2. **`k8s.io/apimachinery` enters the library's Go module, for the tier only.** The tier ships in the same module as the kernel, so the two share one version line and the dependency is a floor for every embedder by MVS, exactly as the CUE SDK already is. The kernel imports none of it. Nothing heavier enters at all: no `client-go`, no `controller-runtime`, no Flux. The neutral `core.Resource`/`Identity` contract is already deleted (0012:OQ3).
3. **The tier is fenced from day one.** Nothing else in the library imports it. Beyond the standard library and the CUE SDK that the kernel's output types carry, it imports only the kernel's exported packages and `apimachinery`. It never imports `client-go`, `controller-runtime`, Flux, a cluster client, `opm/internal` or `opm/helper`. The library's lint refuses, from day one, any other `k8s.io` module and any `sigs.k8s.io` module in the tier, Flux, `opm/internal` and `opm/helper` in the tier, any Kubernetes module in the kernel or the helper tier, and `client-go`, `controller-runtime` and Flux anywhere in the library. Any other third-party import into the tier is held by review until the first tier package decides whether a strict allow list pays. The fence is in place before the first tier package exists, the same way the helper tier is fenced today.
4. **The library's constitution needs amending, narrowly.** Principle I (kernel neutrality) is about *runtime* neutrality: no globals, no `os.Exit`, no hidden env, I/O at the edges with caller-supplied config. A Kubernetes tier does not violate any of it, and it performs no I/O at all. What does need changing is Principle III's package list and Principle IV's "`opm/` packages MUST NOT import command, controller, or runtime-specific concerns". Library ADR-011 records the tier and its bound.

**The tier is not optional for a Kubernetes frontend.** A frontend that adopts a tier package deletes its own copy in the same release, with no alias, and its own checks refuse a copy being reintroduced. That is what separates the tier from the opt-in helper tier, and from the package 0006:D31 reverted because nothing forced its use.

### The deletion protocol

Deletion becomes a state machine owned by the Kubernetes tier, over inputs the library already understands, producing a plan the caller executes and a verdict the caller obeys:

```
   inputs                          opm/k8s                       caller
   ──────                          ───────                       ──────
   inventory entries
   instance identity (UUID)   ┌──────────────────┐
   deletion policy            │  deletion plan   │──▶ ordered []PlannedAction
   live object state          │                  │      each: Delete | Skip(reason)
                              └──────────────────┘
                                       │
                                       ▼                        performs each
                              ┌──────────────────┐              action itself,
                              │   hold verdict   │──▶ verdict   asking the tier
                              └──────────────────┘              for the next one
                                Release | Hold(reason)
```

Everything the operator's `handleDeletion` branches on today becomes a case in the tier's hold verdict: prune disabled, empty inventory, partial failure, the force-orphan annotation. The operator keeps the finalizer patch (a `client.Patch`, which needs its client) and keeps the impersonation setup (credentials). It stops owning the decision of *when* the hold may be released.

The CLI runs the same protocol for its own delete, and the question of whether CLI-owned CRs should carry a hold at all becomes answerable separately (as OQ6), because "what would clean up" now has one definition rather than being an operator-private code path.

### `ownerReferences`

The analysis in [`01-problem.md`](01-problem.md) §6 points at one conclusion, recorded as 0012:OQ4 rather than as a decision because it is this entry's to make rather than one already made: **ownerReferences are the wrong mechanism for OPM's output**. The decisive reason is not the cluster-scope limitation 0010:OQ10 leads with, but the contradiction with `spec.prune`. A reference that garbage-collects regardless of policy cannot be an additive fast path under a policy whose default is "do not collect". The candidate this design carries forward is 0010:OQ10 candidate (a): inventory, labels, and a hold. Making the mechanism library-owned means "OPM cleans up its own resources" is one implementation rather than one-and-a-half.

## Schema / API Surface

The full target shape lives in [`contracts/contracts.cue`](contracts/contracts.cue) and compiles. It is CUE rather than Go because the surface that matters here is the *contract* both Go implementations must satisfy: the inventory wire shape, the label vocabulary, the deletion policy, the verdict enums, the ownerRef eligibility predicate. That contract is already anchored in CUE and the CRD schema rather than in either frontend's structs.

The Go package layout it implies is indicative; 0012:D3 fixes the tier and its fence, and the implementing changes settle the split:

| Package | Owns | Depends on |
| --- | --- | --- |
| `opm/k8s/labels` | the label and annotation vocabulary, `IsOPMManagedBy`, runtime-name values; reads labels, never stamps them (0012:D6) | none |
| `opm/k8s/object` | compiled-output-to-object conversion; replaces both `pkg/core` copies; the one kind-class order table (0012:D5); Kubernetes apply identity, moved from the helper tier | kernel output types, `apimachinery` |
| `opm/k8s/inventory` | `Entry`, one `ComputeStaleSet`, one `ComputeDigest`, one `RenderDigest` that excludes the managed-by value (0012:D6) | `apimachinery` |
| `opm/k8s/ownership` | `SafetyExcluded`, `CanDelete`, `CanApply`, `EligibleForOwnerRef` | `apimachinery` |
| `opm/k8s/lifecycle` | hold name, `DeletionPlan`, `MayReleaseHold`, the plan transition and its serialisable state | `apimachinery` |
| `opm/k8s/health` | readiness evaluation | `apimachinery` |

Beyond the standard library and the CUE SDK, every package in the table imports only the kernel's exported packages and `apimachinery`, and nothing outside `opm/k8s` imports any of them (0012:D3).

There is no executor package. No loop that drives a plan to completion ships anywhere in the library, and no code that performs a planned action against a cluster ships in any tier (0012:D3, library ADR-008 rules 1 to 3), so nothing here touches a cluster: `opm/k8s/lifecycle` names the next action and the frontend performs it with the client it already holds. The loop that remains in each frontend is a few lines and contains no decision; if a decision ever appears in one, the boundary is drawn wrong.

## Integration Points

### library

- `opm/core/resource.go`: the neutral `Resource`/`Identity` contract, already deleted (0012:OQ3).
- `opm/kernel`: unchanged in its imports. It names no Kubernetes type; the tier reads its public output types.
- `opm/k8s/**`: new tier beside the kernel, per the table above, fenced from the rest of the library (0012:D3).
- `opm/helper/`: nothing new. This entry adds no plan-walking helper and no executor backend. ADR-008 allows no loop there, and as amended allows only executor backends that perform no planned action against a cluster, such as 0009's wasm, HTTP, `cue.eval` and local container hosts. Kubernetes apply identity (`objectset`) moves out into the tier with the first tier package.
- `go.mod`: `k8s.io/apimachinery` added to the same module, imported by the tier only.
- `CONSTITUTION.md` + `adr/`: Principle III/IV amendment and ADR-011 recording the tier, its fence and its bound.
- `MIGRATIONS.md`: records the `apimachinery` floor the tier adds, next to the CUE floor.

### opm-operator

- `pkg/core/{labels,resource,convert,compiled_adapter}.go`: deleted; tier types used directly. The operator's `pkg/resourceorder/` is already gone (deleted 2026-09-13).
- `internal/inventory/**`: deleted; tier inventory used directly.
- `internal/apply/prune.go`: collapses into the tier plan plus a local loop that performs the actions it names.
- `internal/apply/apply.go`: keeps Flux SSA; gains the tier's apply verdicts and order (this is 0006:OQ16's fix). The verdict is consulted on every apply, with the adopt annotation as the only override (0012:D8).
- `api/v1alpha1/modulepackage_types.go`: the ModulePackage status gains the instance identity, as an additive field (0012:D8).
- `internal/reconcile/modulepackage.go`: fills the ModulePackage instance identity on reconcile and applies through the same verdict as a ModuleInstance (0012:D8).
- `internal/reconcile/moduleinstance.go`: `handleDeletion` keeps the patches and impersonation, delegates the branching to `MayReleaseHold`.
- `internal/render/module.go`: `buildInventoryEntries` becomes a tier call.

### cli

- `pkg/core/**`, `pkg/inventory/**`, `pkg/resourceorder/**`: deleted; tier types used directly.
- `internal/inventory/{digest,stale}.go`: `ComputeRenderDigest` and the parity comment deleted; `PruneStaleResources` collapses into the tier plan plus a local loop that performs the actions it names, gaining the CRD exclusion and the delete-time ownership guard.
- `internal/inventory/stale.go`: `PreApplyExistenceCheck`, the first-apply refusal, becomes the tier's apply verdict, consulted on every apply with the adopt annotation as the only override (0012:D8).
- `internal/inventory/stale.go`: `ApplyComponentRenameSafetyCheck` deleted, because 0012:D7 standardises on the component-blind comparator, which makes the post-filter unnecessary by construction.
- `internal/kubernetes/delete.go`: the instance-delete walk becomes the tier plan.
- `internal/cmd/instance/delete.go`: unchanged in shape; the outcomes it reports become tier-computed.

## Before / After

The `postgres` CRD-removal scenario from [`01-problem.md`](01-problem.md):

**Before**

```
stale entry: CustomResourceDefinition/backups.example.com

  operator ──▶ safety exclusion check  ──▶ skip, log, PruneResult.Skipped++
  cli      ──▶ Kind == "Namespace"?    ──▶ no ──▶ DELETE
                                                  └─▶ every Backup CR, cluster-wide
```

**After**

```
stale entry: CustomResourceDefinition/backups.example.com

  operator ─┐
            ├──▶ opm/k8s deletion plan     ──▶  Skip{reason: SafetyExcluded}
  cli      ─┘                                    (one implementation, one reason string,
                                                  one test asserting it)
```

And the deletion-policy branch:

**Before**: the operator's `handleDeletion` decides; the CLI has no equivalent concept; a CLI-owned CR has no hold at all, so `kubectl delete` bypasses both.

**After**: `MayReleaseHold` decides, from the policy and the plan's outcome, for whichever implementor is asking. Whether a CLI-owned CR carries a hold becomes a policy input rather than a property of which code path happened to run (OQ6).
