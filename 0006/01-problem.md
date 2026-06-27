# Problem Statement — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Current State

The OPM CLI and the OPM operator are two independent actors that deploy the same kind of release to the same kind of cluster, but they share neither a state store nor a render pipeline.

**Inventory.** The CLI records what it has applied in a Kubernetes Secret named `opm.<releaseName>.<releaseID>`, type `opmodel.dev/release`, key `inventory`, holding a JSON `ReleaseInventoryRecord` (`cli/internal/inventory/secret.go`, `types.go`). The record carries `CreatedBy`, release metadata, module metadata, and an `Inventory` of `{Revision, Digest, Count, Entries[]}` where each entry is `{Group, Kind, Namespace, Name, Version, Component}` (`cli/pkg/inventory/types.go`). The apply workflow (`cli/internal/workflow/apply/apply.go`) loads the previous inventory, computes a stale set, server-side-applies in weight order, prunes, then writes the Secret — skipping the write on apply failure. Commands `release apply`, `release delete`, `release status`, `release list`, `release diff` all read or write this Secret.

The operator records the structurally identical inventory in `ModuleRelease.status.inventory` (`opm-operator/api/v1alpha1/common_types.go`) — `Inventory{Revision, Digest, Count, Entries[]}` with the same `InventoryEntry` fields. This is not a coincidence: the operator's archived change `2026-04-12-01-cli-dependency-and-inventory-bridge` deliberately copied the CLI's inventory functions (`ComputeStaleSet`, `ComputeDigest`, entry identity) into `opm-operator/internal/inventory/`, and its design explicitly defers "promote to `pkg/` for external reuse" to a later enhancement. The two stores hold the same shape and are populated by near-identical code, but they are disjoint: nothing reads across them.

**Render.** The CLI has its own render/match pipeline (`cli/pkg/render/`, `cli/pkg/loader/`). It does **not** depend on `library` or `opm-operator` — `cli/go.mod` has no edge to either. The operator, by contrast, cut over to the `library` kernel for rendering and matching (operator changes `2026-06-06-wire-library-kernel`, `2026-06-07-cutover-modulerelease-kernel`). So the same release rendered by the CLI and by the operator runs through two different code paths that compute their own render digests independently.

**Ownership.** The CLI inventory record carries `CreatedBy: "cli" | "controller"`, and `cli/pkg/ownership` refuses to let the CLI mutate a controller-owned release (`EnsureCLIMutable`). Both actors stamp `module-release.opmodel.dev/{uuid,name,namespace}` and `app.kubernetes.io/managed-by` on applied resources, and the operator's prune guard already accepts both `opm-cli` and `opm-controller`. The convergence is half-built — same labels, same inventory shape, a marker concept — but no path actually crosses from one actor to the other.

## Gap / Pain

The intended OPM adoption path is: try it with the CLI alone (no operator, no CRDs), grow into GitOps, install the operator, and then have the operator take over already-deployed releases — **without downtime, without orphans, without re-deploying**. Step three is impossible today, for two independent reasons that this enhancement addresses together.

1. **Two disjoint inventory stores.** The CLI's Secret and the operator's `status.inventory` are separate sources of truth with identical content. Handing a release off would mean hand-constructing a `ModuleRelease`, hoping the operator's first reconcile happens to be a no-op, and deleting the Secret — with each side's prune logic blind to the other's record. A mismatch prunes live resources.

2. **Two divergent render pipelines.** Even if the inventories were shared, the zero-downtime property depends on the operator's first post-takeover render producing the *same* resources the CLI deployed. With the CLI on `pkg/render` and the operator on the `library` kernel, render-digest equality is a hope, not a guarantee. Two independent pipelines drift — a defaulting difference, a match-order difference, a transformer the CLI resolved differently — and the operator's first apply is no longer a no-op. The digest-verification gate that should make handoff safe has nothing trustworthy to compare against.

3. **The CLI carries a second copy of logic 0001 is actively redesigning.** Enhancement 0001 rewrites the kernel's match/materialize (path-keyed registry, SemVer FQNs, always-unify). The operator gets that for free by consuming the kernel. The CLI's own pipeline would have to re-implement 0001's matcher to stay consistent — a permanent second implementation of the most intricate part of OPM, drifting from the canonical one with every 0001 follow-up.

## Concrete Example

A user runs `opm release apply` for a `jellyfin` module against their cluster. The CLI renders via `pkg/render`, applies the resources, and writes Secret `opm.jellyfin.<uuid>` with the inventory. Months later they install the operator and want it to manage `jellyfin`.

Today they must: read the Secret, hand-write a `ModuleRelease` whose `spec` they hope reproduces what the CLI deployed, `kubectl apply` it, and pray. The operator renders `jellyfin` through the `library` kernel — a different pipeline than the CLI used — computes a prune set of `previous (empty status.inventory) - current render`, and on its first reconcile sees an empty previous inventory, so it treats every rendered object as new. If its render differs from the CLI's in even one field, server-side apply mutates live objects; if the CLI's Secret listed a resource the operator's render no longer emits, nothing prunes it and it orphans. The "upgrade to GitOps" step risks a visible blip on a running service.

With a shared CR *and* a shared kernel: the CLI has already written the deployed entry set and its render digest into `status.inventory` / `status.lastAppliedRenderDigest`; the operator renders through the same kernel, gets the same digest, sees a matching render (SSA no-op) and a zero stale set (nothing pruned). No resource is touched. That is the property the design exists to produce, and it falls out of sharing both the store and the pipeline rather than engineering a bespoke migration.

## User Stories

- As a **CLI-first adopter**, I want to install the operator and hand my already-deployed releases to it without downtime or re-deploying, so that growing into GitOps is a one-command transition. Today: the CLI's Secret inventory and the operator's CR inventory are disjoint, and their renders diverge, so handoff is a manual, unsafe reconstruction.
- As an **OPM maintainer**, I want exactly one render/match implementation across CLI and operator, so that 0001's matcher redesign and every future kernel change applies to both actors at once. Today: the CLI carries a second pipeline (`pkg/render`) that must be kept in sync by hand.
- As a **cluster operator**, I want CLI-deployed and operator-deployed releases to be inspectable and reconciled through one resource type with one ownership marker, so that `kubectl get modulereleases` shows the whole picture. Today: CLI releases hide in Secrets; only operator releases appear as CRs.

## Why Existing Workarounds Fail

**Hand-constructing a `ModuleRelease` at handoff time.** Reproduces the deployed spec by guesswork, leaves the operator's first reconcile to chance, and requires deleting the Secret out-of-band with no cross-checked prune safety. The very failure modes (mutate-on-apply, orphan-on-prune) it is meant to avoid are the ones it most easily triggers.

**Keeping the CLI's own pipeline and merely sharing the inventory store.** Closes gap 1 but not gap 2: identical inventory entries do not guarantee identical *renders*, and the handoff digest check needs render parity it cannot get from two independent pipelines. Half the convergence buys none of the safety.

**Re-implementing 0001's matcher inside the CLI to keep renders aligned.** Technically closes gap 2 but permanently doubles the maintenance surface of the most subtle code in OPM, and guarantees drift on every 0001 follow-up. A second implementation of match/materialize is exactly what adopting the kernel removes.

None of these produce a single source of truth for *both* what is deployed and how it was rendered. The fix is to put inventory in the shared CR and route the CLI's rendering through the shared kernel, so handoff becomes a no-op by construction rather than a reconstruction by hope.
