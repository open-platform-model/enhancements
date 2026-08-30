# Problem Statement: Kubernetes as a First-Class Kernel Platform

Every fact in this document was verified against the working tree on 2026-07-27. File paths and line numbers refer to that state.

## Current State

The kernel renders. It stops there.

`(*kernel.Kernel).Compile` returns a `*kernel.CompileResult` carrying `[]*core.Compiled`, a CUE value plus instance/component/transformer provenance (`library/opm/core/compiled.go`). That is the last thing both frontends share. Everything that turns those values into cluster state is written twice:

```
                    library/opm/kernel.Compile
                              │
                       []*core.Compiled
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     cli/pkg/core.Resource          opm-operator/pkg/core.Resource
     cli/pkg/inventory              opm-operator/internal/inventory
     cli/internal/inventory         opm-operator/internal/apply
     cli/internal/kubernetes        opm-operator/internal/reconcile
              │                               │
              └───────────────┬───────────────┘
                              ▼
                          the cluster
```

`library/opm/core/resource.go` states the reason for the stop explicitly: `Resource` and `Identity` are a platform-neutral contract, and the doc comment enumerates the platforms the abstraction exists to serve: "Kubernetes, docker-compose, Nomad, Terraform, Crossplane". The library's `go.mod` carries no `k8s.io/*` dependency of any kind.

Below that line, the two frontends have independently grown a full Kubernetes runtime each.

**Byte-identical duplication.**

- `cli/pkg/resourceorder/weights.go` and `opm-operator/pkg/resourceorder/weights.go` do not differ by a single character.
- `cli/pkg/core/labels.go` and `opm-operator/pkg/core/labels.go` differ only in three comment lines; `cli/pkg/core/resource.go` and its operator twin differ in one.
- `cli/pkg/core/convert.go` and `opm-operator/pkg/core/convert.go` are identical.
- The render-digest function exists as `opm-operator/internal/status.RenderDigest` and as `cli/internal/inventory.ComputeRenderDigest`, and the CLI copy carries this comment:

> "using EXACTLY the operator's algorithm and serialization … Byte-for-byte parity with the operator's digest is the D7.4 handoff verification contract (enhancement 0006 D9/D30); do not change one side without the other."

A hand-maintained parity contract between two repos, written into a code comment, is the load-bearing mechanism today.

**Divergence where the copies decide things.** The duplication is not uniform. Where the two implementations make decisions rather than copy fields, they have already drifted:

| Decision | `cli` | `opm-operator` |
| --- | --- | --- |
| stale-set base relation | `IdentityEqual`, component-aware (`pkg/inventory/entry.go:52`), then rescued by a separate `ApplyComponentRenameSafetyCheck` post-filter (`internal/inventory/stale.go:24`) | `K8sIdentityEqual`, component-blind (`internal/inventory/stale.go`), no post-filter needed |
| never delete `Namespace` | yes (`internal/inventory/stale.go:119`) | yes (`internal/apply/prune.go:136`) |
| never delete `CustomResourceDefinition` | **no** | yes (`internal/apply/prune.go:136`) |
| delete-time ownership guard (`managed-by` + instance-UUID match against live state) | **none**: `PruneStaleResources` deletes straight from the inventory (`internal/inventory/stale.go:102`) | yes (`internal/apply/prune.go:99-114`) |
| apply-time collision guard (refuse foreign or terminating object) | yes: `PreApplyExistenceCheck` (`internal/inventory/stale.go:58`) | **none** |
| delete ordering | reverse resource-order weight | unordered |
| delete propagation | foreground | background (client default) |

Two of those rows are the same finding stated twice, and it is the one worth pausing on:

```
                    apply-time guard        delete-time guard
   cli                     ✅                      ❌
   opm-operator            ❌                      ✅
```

Neither actor has both. Each independently grew exactly the half the other lacks. That is not a coincidence to be fixed with a convention. It is the arithmetic of writing the same component twice.

**Deletion, specifically.** Enhancement 0010's OQ10 raised deletion semantics and recorded two claims. One is correct and one is not, and the correction matters because it relocates the problem:

- **"`ModuleInstance` has no finalizer."** *False.* `FinalizerName = "opmodel.dev/cleanup"` is defined at `opm-operator/internal/reconcile/moduleinstance.go:38`, registered at `:97`, and drives `handleDeletion` at `:590`, which prunes the recorded inventory under impersonation, stalls on `Forbidden`, stalls on a missing ServiceAccount with a force-orphan annotation as the escape hatch, and removes the finalizer only after the prune succeeds. `internal/reconcile/deletion_test.go` covers it across roughly 570 lines. `ModuleInstance` and `ModulePackage` register the *same* constant.
- **"`opm-operator` sets no `ownerReferences` on applied resources."** *True.* Zero occurrences of `SetControllerReference`, `SetOwnerReference`, or `OwnerReferences` anywhere in the repository outside generated and vendored trees.

So the mechanism OQ10 asked for mostly exists, on one side. What does not exist is any reason to believe the other side behaves the same, and two narrower holes that the finalizer's presence conceals.

## Gap / Pain

**1. A new platform capability costs two implementations, and lands as one.**

This is the generative problem; the rest are symptoms. There is no place to put a Kubernetes behaviour such that both implementors get it. Enhancement 0006 recorded exactly this outcome twice and deferred both:

- **OQ15** (stale-set comparator divergence): classified "product-consistency, not safety", left open at graduation.
- **OQ16** (operator's missing apply-time collision guard): classified "a real, presently-shipping exposure", left open at graduation.

Both were recorded on 2026-07-01 during D31's investigation, were still open when 0006 graduated on 2026-07-20, and are still unimplemented in either repo on 2026-07-27. Neither was implemented because implementing either means writing a component that already exists, a second time, in a second repo. A documented convention was the alternative on offer, and OQ16 *is* that documented convention.

**2. The CLI deletes CustomResourceDefinitions.**

`PruneStaleResources` excludes only `Namespace`. A stale inventory entry naming a CRD (a component removed from a module that shipped one) is deleted, and with it every custom resource of that type in the cluster. The operator refuses the same delete at `internal/apply/prune.go:136`. This is not a consistency wrinkle; it is unbounded collateral damage available through one of the two supported tools.

**3. The CLI prunes without checking what it is deleting.**

The operator's `Prune` GETs each object and skips it when `app.kubernetes.io/managed-by` is not an OPM value, or when the live `module-instance.opmodel.dev/uuid` disagrees with the owner. The CLI has no equivalent at delete time. A resource that OPM once managed and something else has since adopted is deleted by the CLI and preserved by the operator.

**4. Deleting a CLI-owned instance orphans everything, silently.**

`handleCLIOwned` (`internal/reconcile/moduleinstance.go:519`) is hands-off by design: no render, no apply, no prune, and (deliberately) no finalizer, so the operator never prunes resources the CLI owns. The consequence is stated in its own comment: for a deleting instance it "returns immediately: no finalizer was ever added, so there is nothing to clean up or unblock."

A `kubectl delete moduleinstance` against a CLI-owned instance therefore removes the CR, which is the only record of what that instance deployed, and leaves every workload running with no inventory to find it by. Nothing warns. `opm instance delete` handles this correctly; the API server does not.

**5. `spec.prune` defaults to false, so the finalizer's default behaviour is to orphan.**

`ModuleInstanceSpec.Prune` has no CRD default. `handleDeletion` reads it at `internal/reconcile/moduleinstance.go:600`: if prune is false, the finalizer is removed and every resource stays running. The finalizer exists and, by default, does nothing. This is a deliberate policy (the CLI prints a warning explaining it), but it means the *outcome* OQ10 described ("deleting a ModuleInstance leaves every deployed resource running") is real on the default path, for a reason OQ10 did not identify.

**6. `ownerReferences` cannot be added as an additive fast path without breaking (5).**

OQ10's candidate (b) proposed ownerReferences for the same-namespace namespaced subset, as a fast path layered over the inventory. OQ10's stated obstacle is real: modules render cluster-scoped objects (`catalog_opm/src/resources/crd.cue:56` types `scope!: "Namespaced" | "Cluster"`, `role.cue:47` covers ClusterRole, `catalog_kubernetes` ships a namespace transformer), and a namespaced owner cannot legally own them.

But there is a sharper obstacle it does not mention. Kubernetes garbage-collects a dependent when every object in its `ownerReferences` is gone. `controller: false` changes which owner is authoritative for adoption; `blockOwnerDeletion: false` changes foreground ordering. Neither makes a reference non-collecting. There is no read-only ownerReference. The discovery and grouping job it might otherwise do is already done by labels.

So an ownerReference on a namespaced resource deletes that resource when the `ModuleInstance` is deleted, **regardless of `spec.prune`**. Against a default of `prune: false`, whose contract is "your workloads survive", that is a silent contradiction affecting exactly the namespaced subset. Making ownerReferences conditional on `prune: true` removes the contradiction and also removes the point: the finalizer already prunes when prune is true.

## Concrete Example

A platform team runs `postgres` in namespace `prod`. The module ships a `Deployment`, a `Service`, a `PersistentVolumeClaim`, and (because it registers a custom backup type) a `CustomResourceDefinition`.

The module author removes the backup feature and republishes. The CRD is no longer rendered, so it becomes a stale inventory entry.

**Under the operator:** `pruneStaleResources` calls `apply.Prune`, which hits `isSafeToDelete` and refuses. The CRD stays. A warning is logged and counted in `PruneResult.Skipped`. Every `Backup` custom resource in the cluster survives.

**Under the CLI:** `PruneStaleResources` checks the entry against one exclusion, `Kind == "Namespace"`, which does not match. It issues a foreground delete against the CRD. Kubernetes cascades: every `Backup` object in every namespace, belonging to every team, is deleted with it.

Same module, same upgrade, same stale entry. One tool logs a skip; the other takes out a cluster-wide resource type. Nothing in the module, the platform, or the CR expresses which behaviour the user gets: only which binary they happened to run.

Now the same instance, deleted. If it is operator-owned and nobody set `spec.prune`, the finalizer runs, finds prune disabled, removes itself, and all four resources keep running. If it is CLI-owned and someone runs `kubectl delete moduleinstance postgres -n prod` instead of `opm instance delete`, the CR is removed with no finalizer to stop it, and the four resources keep running with the only record of their existence deleted.

## User Stories

- As a **platform team operator**, I want deleting an instance to have one defined meaning, so that I can predict what survives. Today: the outcome depends on which of two tools I use, on a `spec.prune` field with no default and no prompt, and on whether I deleted the CR or asked the CLI to.
- As a **kernel contributor**, I want to add a Kubernetes behaviour once and have every implementor get it, so that a safety check is not a per-frontend project. Today: `library/opm/` may not contain Kubernetes code, so the work is two PRs in two repos with a hand-maintained parity comment between them, which is why 0006's OQ15 and OQ16 are still open.
- As an **application module author**, I want removing a component from my module to be safe, so that an upgrade cannot destroy state I never owned. Today: removing a component that shipped a CRD is safe under the operator and cluster-destroying under the CLI.

## Why Existing Workarounds Fail

**The shared package was tried, and reverted.** Enhancement 0006 D13.1 decided the shared logic "homes in `library` … consumed by both the CLI and the operator", calling it "required for correctness, not just tidiness". It shipped as slice A3 (`library/opm/inventory` existed) and D31 deleted it on 2026-07-01.

D31's reasoning is narrowly correct and remains so. It asked whether shared code is *required for cross-actor handoff safety*, traced the data flow, and found that only the `InventoryEntry` wire shape crosses the boundary unmediated (anchored by the CRD's OpenAPI schema rather than by a Go package) while the handoff instant is independently gated by D7.4's render-digest check. Nothing in this entry disputes that.

What D31 did not ask is whether two implementations of one kernel should *behave* the same. Its own investigation surfaced the answer and filed it as OQ15 and OQ16 rather than resolving it, and it did not trace the CRD-exclusion or delete-time-guard rows at all.

**Two of D31's three supporting facts have since changed:**

1. **Its cost argument has expired.** D31 rejected the shared package partly on "a `go.mod` edge, alpha-tag version pinning, a release cycle blocking downstream slices, exactly the friction already observed blocking B1 on `library v1.0.0-alpha.4`." That edge was added 19 days later: 0006's C2/D9 slice landed on 2026-07-20, and today `cli/go.mod:11` and `opm-operator/go.mod:15` both require `github.com/open-platform-model/library v1.0.0-alpha.8`, the same version. The coordination cost D31 priced is already paid, and it bought the harder half.

2. **Its "third representation" objection was aimed at a neutral type.** D31 rejected even a minimal shared package because "a shared library type adds a third representation everything maps through rather than collapsing the two that actually matter." That is true of the *runtime-neutral* entry type D13.1 specified. It is not true of a Kubernetes-native one, which is the same representation the CRD already anchors and the shape enhancement 0008 intends to generate.

3. **What has not changed** is that `ComputeStaleSet`, `ComputeDigest`, and the guards are computed by one actor at a time for its own action. D31 is right that this makes them safe from *cross-actor* drift. It does not make them safe: rows 2, 3, and 4 of the divergence table are single-actor defects, invisible to any cross-actor argument.

**Documentation does not close it.** OQ15 and OQ16 are the documented-convention approach in its strongest available form: written down on 2026-07-01, reviewed, and carried through a graduation gate on 2026-07-20 that explicitly acknowledged them as unresolved. Twenty-six days after they were recorded, neither has been implemented in either repo. In the same period, two further divergences went unnoticed until this entry's investigation: the CLI's missing CRD exclusion and its missing delete-time ownership guard, neither documented by any convention.
