# Design Decisions — Kubernetes as a First-Class Kernel Platform

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

This entry is `draft`. Only decisions actually taken are recorded below; everything the design still owes an answer to is an Open Question, including several that carry a recommendation. A recommendation in an Open Question is not a decision.

---

## Decisions

### D1: The Kubernetes runtime surface homes in the library kernel — supersedes 0006 D31's placement conclusion, not its analysis

**Decision:** The decisions OPM makes about Kubernetes resources — inventory entry construction, stale-set computation, digests, prune safety exclusions, ownership guards at apply and delete time, deletion ordering, and the deletion hold protocol — live in `library/opm/` and are consumed by both `opm-operator` and `cli`. Neither frontend keeps a private implementation of any of them.

This supersedes the placement conclusion of enhancement 0006 D31 ("`library/opm/inventory` is reverted… each actor keeps an independently maintained local implementation"). It does **not** supersede D31's data-flow analysis, which stands: only the `InventoryEntry` wire shape crosses the actor boundary unmediated, that shape is anchored by the CRD's OpenAPI schema, and the handoff instant is independently gated by D7.4's render-digest check. 0006 remains `implemented` as an entry; exactly one of its decisions is replaced.

**Alternatives considered:**

- **Keep independent implementations, close the gaps with documented conventions.** Rejected on measured evidence rather than principle: this is precisely what 0006 chose, and OQ15 and OQ16 are that convention in its strongest available form — written down on 2026-07-01, reviewed, and carried through a graduation gate on 2026-07-20 that explicitly acknowledged them as unresolved. Twenty-six days after they were recorded neither has been implemented in either repo, and two further divergences that no convention documented (the CLI's missing CRD exclusion and its missing delete-time ownership guard) were found by inspection on 2026-07-27.
- **A shared package in a fourth repo, or in `opm-operator` consumed by `cli`.** Rejected: 0006 D13 established with static-analysis evidence that importing `opm-operator/api/v1alpha1` drags `controller-runtime/pkg/scheme`, `fluxcd/pkg/apis/meta`, and `apiextensions-apiserver` into any importer, because Go compiles whole packages. That finding is unchanged and rules out the operator as the home. A fourth repo adds a module edge and a release cycle without the compensating benefit that `library` carries, which is that both frontends already depend on it.
- **Reference-only shared code — publish the logic, let each frontend port it.** Rejected for the reason D31 itself gave when rejecting the same option: a package presented as kernel contract that nothing imports is actively misleading to future readers.

**Rationale:** Two of the three facts underpinning D31's revert have changed since it was made on 2026-07-01.

Its cost argument — "a `go.mod` edge, alpha-tag version pinning, a release cycle blocking downstream slices, exactly the friction already observed blocking B1 on `library v1.0.0-alpha.4`" — expired 19 days later when 0006's own C2/D9 slice added that edge for the kernel. As of 2026-07-27 `cli/go.mod:11` and `opm-operator/go.mod:15` both require `github.com/open-platform-model/library v1.0.0-alpha.8`, the same version. The coordination cost is already paid and already bought the harder half of the pipeline.

Its "third representation" objection — that a shared library type "adds a third representation everything maps through rather than collapsing the two that actually matter" — was aimed at the runtime-neutral entry type D13.1 specified. Under D2 there is no third representation: the library type is the Kubernetes type, which is the same shape the CRD already anchors and which enhancement 0008 intends to generate from CUE.

What D31 got right and this decision preserves is that none of this logic is *cross-actor compared*. That is why the failure did not appear as a handoff bug. It appeared as three single-actor defects instead — a CLI that deletes CRDs, a CLI that prunes without checking live ownership, and an operator that force-applies over foreign objects — each invisible to a cross-actor argument, and each the direct consequence of a component existing twice.

**Source:** User decision 2026-07-27, from an explore-mode session investigating enhancement 0010's OQ10. Evidence gathered in the same session and recorded in [`01-problem.md`](01-problem.md); every file reference verified against the working tree that day.

---

### D2: The kernel is written for Kubernetes; no portability abstraction is maintained on its behalf

**Decision:** Kubernetes is the kernel's platform, not one of several the kernel abstracts over. New kernel surface is written directly against Kubernetes concepts — GVK, namespace, labels, ownerReferences, finalizers, propagation policy — without an intervening neutral vocabulary, and without generalisation work undertaken to keep a non-Kubernetes backend viable. `k8s.io/apimachinery` becomes a library dependency and therefore, by MVS, a floor for every embedder.

The dependency is bounded to `apimachinery`. `client-go`, `controller-runtime`, and Flux are explicitly excluded — the first because the kernel does not resolve credentials, the second and third because they are the operator's framework and must not become the CLI's.

**Alternatives considered:**

- **Retain the neutral `core.Resource` / `Identity` contract and add Kubernetes as an implementation of it.** Not chosen. It is the smaller change and would satisfy D1 on its own, but it preserves an abstraction with exactly one implementation and no named consumer, and it forces every new Kubernetes concept — propagation policy, finalizers, ownerReferences, subresources — through a vocabulary that cannot express it. Whether the neutral contract is deleted outright or left in place unused is a narrower question about semver blast radius, deferred to OQ3.
- **Keep the kernel platform-neutral and put the Kubernetes tier in a fourth module.** Rejected: it reproduces D31's coordination cost that D1 just established is no longer necessary to pay, and it splits the kernel's version line for no consumer's benefit.

**Rationale:** The neutral contract is not currently earning its cost. `library/opm/core/resource.go` names docker-compose, Nomad, Terraform, and Crossplane as the platforms it exists to serve; none exists, none is scheduled, and the abstraction's only effect today is to stop Kubernetes logic from living in the kernel — which is the direct cause of the duplication D1 addresses. Generalising in advance of a second platform is the speculative-abstraction failure, and paying for it with a real correctness defect in the one platform that does exist is a bad trade.

The narrower reading also matters for what this decision is *not*: it does not license controller concerns into `opm/`. The kernel gains Kubernetes vocabulary, not a runtime. Principle I's substance — determinism, no globals, no hidden environment, I/O at the edges with caller-supplied configuration — is unaffected, and the existing OCI registry loader is the precedent for edge I/O under exactly those terms.

**Source:** User decision 2026-07-27, restated after an initial recommendation to keep the neutral contract and add Kubernetes as a tier beneath it. The user's framing: the kernel should be written for Kubernetes "so we don't have to think about portability and generalization".

---

## Open Questions

Each carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or `answered`. Several carry a recommendation — a recommendation is not a decision and does not close the question.

### Kernel boundary

- **OQ1: How far past the render line does the kernel go — Rung 2 (decides), Rung 3 (acts), or a split?** Status: open. [`02-design.md`](02-design.md) argues Rung 2 alone reproduces D31's failure mode, because a plan a frontend can decline to follow is how the CLI came to lack a CRD exclusion the operator has; and that Rung 3 cannot apply uniformly, because the operator's apply is `fluxcd/pkg/ssa` and the CLI must not inherit it. The recommendation is asymmetric: the kernel owns execution for delete (no framework opinion) and verdicts only for apply. Resolving this fixes the shape of every slice below it. What would resolve it: agreement on whether "behaves the same" must be structurally enforced or may rest on each frontend choosing to call the planner.

- **OQ2: Does the kernel take a cluster client, and what is the minimal interface?** Status: open. Rung 3 requires the kernel to GET and DELETE. The proposal is a two-method interface over `*unstructured.Unstructured` supplied by the caller, keeping the library on `apimachinery` with no `client-go` edge; the operator adapts its controller-runtime client and the CLI its dynamic client in roughly fifteen lines each. Precedent exists — `opm/helper/loader/registry` already performs OCI network I/O under caller-supplied configuration — but this would be the first time the kernel touches a cluster. What would resolve it: deciding whether cluster I/O belongs in `opm/helper/` (opt-in tier, consistent with the registry loader) or is refused outright, which forces OQ1 to Rung 2.

- **OQ3: Is the neutral `core.Resource` / `Identity` contract deleted, or retained and implemented?** Status: open. D2 settles that no portability work is undertaken for it; it does not settle its fate. Deletion is a library-major break requiring a `MIGRATIONS.md` entry and coordinated frontend updates; retention leaves an unused abstraction that the next contributor must be told to ignore. This question sets `config.yaml.semver`, so it blocks promotion to `accepted`.

### Deletion and ownership

- **OQ4: `ownerReferences` — candidate (a), (b), or (c) from 0010's OQ10?** Status: open, with a recommendation. [`01-problem.md`](01-problem.md) §6 establishes that Kubernetes garbage-collects a dependent when all its owners are gone regardless of `controller` or `blockOwnerDeletion`, so there is no read-only ownerReference; and that `spec.prune` defaults to false, whose contract is that workloads survive. An ownerReference therefore contradicts the default policy for exactly the namespaced subset. Conditioning it on `prune: true` removes the contradiction and also the benefit, since the hold already prunes in that case. The recommendation is (a) — inventory, labels, and a kernel-owned hold, with no ownerReferences at all — for a stronger reason than the cluster-scope limitation OQ10 leads with. What would resolve it: confirming the residual value of ownerReferences as a backstop when a hold is force-removed, and whether that outweighs a policy contradiction.

- **OQ5: Does `spec.prune` keep defaulting to false?** Status: open. It is the difference between "the hold exists" and "the hold does anything", and no amount of kernel work substitutes for it. Flipping it is a one-line CRD default that silently begins deleting workloads on delete for every existing instance, so it needs an explicit decision and a migration note. Leaving it means orphan-by-default remains the shipped behaviour and the tooling's job is to say so loudly. Owned by `opm-operator` but decided here because the deletion protocol's meaning depends on it.

- **OQ6: Do CLI-owned instances carry a deletion hold?** Status: open. Today `handleCLIOwned` deliberately adds no finalizer so the operator never prunes CLI-owned resources, which means `kubectl delete moduleinstance` removes the CR — the only inventory record — and orphans every workload with nothing left to find them by. The options are a hold the CLI itself releases, a hold the operator honours on behalf of a CLI-owned instance (which reintroduces the ownership confusion the owner-skip gate exists to prevent), or an explicit accepted leak with a warning surface. This is the one gap in the area that code-sharing alone does not close.

- **OQ7: Which stale-set base relation wins — component-aware or component-blind?** Status: open. Absorbed from 0006 OQ15, which classified it "product-consistency, not safety" and deferred it. Standardising on the operator's component-blind `K8sIdentityEqual` makes the CLI's separate `ApplyComponentRenameSafetyCheck` post-filter unnecessary by construction rather than merely redundant, which is an argument for that direction. What would resolve it: confirming no CLI behaviour depends on the post-filter's distinct reporting.

- **OQ8: Does the apply-time collision guard land in this entry?** Status: open. Absorbed from 0006 OQ16, which called it "a real, presently-shipping exposure" and deferred it. Both apply paths force SSA field ownership unconditionally, and the operator's delete-time guard cannot backstop an apply-time mislabel — a successful colliding apply relabels the foreign object as `opm-controller`-managed, so it looks legitimately owned from then on. Open sub-questions inherited from OQ16: whether the guard runs on every reconcile that grows the entry set or only on an instance's first, and whether refusal has an override.

### Relationships to other entries

- **OQ9: Does the library own the CRD Go types, and how does that interact with 0008?** Status: open. 0008 makes `core/` CUE the source of truth for `ModuleInstance` / `ModulePackage` / `Platform` and generates the Go types into `opm-operator/api/v1alpha1`. If the shared Kubernetes vocabulary homes in `library` under D1, the generation target is arguably `library` with the operator re-exporting — which would also dissolve 0006 D13's constraint that the CLI cannot import the operator's types. Note that 0008's README currently states the CLI "consumes those same Go types", which is not the case: `cli/go.mod` has no `opm-operator` dependency and `cli/internal/inventory/cr.go` hardcodes the CRD coordinates precisely to avoid one. Resolving this needs a joint decision with 0008 rather than a unilateral one here.

- **OQ10: How does this entry's kernel surface relate to 0009's execution half?** Status: open. 0009 adds `opm/flow/` — a planner plus orchestrator for `#Op` / `#Action` / `#Lifecycle` / `#Workflow` — with an opt-in executor backend layer and a caller-composed backend set. That is structurally the same move this entry makes for deletion: a pure planner in the kernel, execution behind a caller-supplied seam. If both land independently they will invent two different executor conventions. The two should share one, and deciding which entry owns it is cheaper before either ships. 0009's initial Op vocabulary already includes `k8s get/apply`, which is the overlap made concrete.

- **OQ11: Where does label stamping live?** Status: open. Today `core/src/transformer.cue` composes the label set and the runtime fills `#runtimeName`, so labels are stamped in CUE and only read in Go — while `opm-operator/pkg/core/labels.go` and its CLI twin hold the Go-side vocabulary that reads them. Enhancement 0010 separately moves the `module.opmodel.dev/version` label "from the schema to the kernel". If the kernel is to own ownership decisions, the question of whether it also owns stamping — and how that splits against `core/`'s CUE — needs an answer that 0010 and this entry agree on.
