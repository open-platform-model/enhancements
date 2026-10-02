# Design Decisions: Kubernetes as a First-Class Library Tier

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now. While this entry is `draft`, a decision is revised in place and gains a dated `**Revised:**` line, so the log never holds two conflicting decisions. From `accepted`, a change is its own `DN` with an `**Amends:**` or `**Supersedes:**` line. The next compaction pass weaves it into the decision it changes. The merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

This entry is `draft`. Only decisions actually taken are recorded below; everything the design still owes an answer to is an Open Question, including several that carry a recommendation. A recommendation in an Open Question is not a decision.

---

## Decisions

### D1: The Kubernetes runtime surface homes in the library's Kubernetes tier (supersedes only 0006:D31's placement conclusion)

**Kind:** contract

**Depends:** 0006:D9, 0006:D31

**Decision:** The decisions OPM makes about Kubernetes resources live in `library/opm/` and are consumed by both `opm-operator` and `cli`: inventory entry construction, stale-set computation, digests, prune safety exclusions, ownership guards at apply and delete time, deletion ordering, and the deletion hold protocol. Neither frontend keeps a private implementation of any of them.

This supersedes the placement conclusion of enhancement 0006 D31 ("`library/opm/inventory` is reverted… each actor keeps an independently maintained local implementation"). It does **not** supersede D31's data-flow analysis, which stands. Only the `InventoryEntry` wire shape crosses the actor boundary unmediated; that shape is anchored by the CRD's OpenAPI schema, and the handoff instant is independently gated by D7.4's render-digest check. 0006 remains `implemented` as an entry; exactly one of its decisions is replaced.

**Requirements:**

- R1: For the same rendered output, inventory, instance identity, deletion policy and live object state, the CLI and the operator compute the same inventory entries, stale set, digest and deletion plan, with the same skip reasons.
- R2: Neither frontend deletes an object the deletion plan marked as skipped.
- R3: A `Namespace` or a `CustomResourceDefinition` in an instance's inventory is never deleted automatically by either frontend.
- R4: A live object whose manager label is not an OPM runtime identity, or whose instance identity differs from the deleting instance's, is skipped by both frontends with the reason named.
- R5: Whether an instance's deletion hold may be released is decided from its policy and the plan's outcome, identically for whichever frontend asks, with the reason named.
- R6: Deletions happen in a defined order that is the same on both frontends.
- R7: Before applying, each object receives a verdict that refuses an existing object not managed by OPM or one being deleted, and the verdict is the same on both frontends.

**Alternatives considered:**

- **Keep independent implementations, close the gaps with documented conventions.** Rejected on measured evidence rather than principle: this is precisely what 0006 chose, and OQ15 and OQ16 are that convention in its strongest available form: written down on 2026-07-01, reviewed, and carried through a graduation gate on 2026-07-20 that explicitly acknowledged them as unresolved. Twenty-six days after they were recorded neither has been implemented in either repo, and two further divergences that no convention documented (the CLI's missing CRD exclusion and its missing delete-time ownership guard) were found by inspection on 2026-07-27.
- **A shared package in a fourth repo, or in `opm-operator` consumed by `cli`.** Rejected: 0006 D13 established with static-analysis evidence that importing `opm-operator/api/v1alpha1` drags `controller-runtime/pkg/scheme`, `fluxcd/pkg/apis/meta`, and `apiextensions-apiserver` into any importer, because Go compiles whole packages. That finding is unchanged and rules out the operator as the home. A fourth repo adds a module edge and a release cycle without the compensating benefit that `library` carries, which is that both frontends already depend on it.
- **Reference-only shared code: publish the logic, let each frontend port it.** Rejected for the reason D31 itself gave when rejecting the same option: a package presented as kernel contract that nothing imports is actively misleading to future readers.

**Rationale:** Two of the three facts underpinning D31's revert have changed since it was made on 2026-07-01.

Its cost argument was: "a `go.mod` edge, alpha-tag version pinning, a release cycle blocking downstream slices, exactly the friction already observed blocking B1 on `library v1.0.0-alpha.4`." That argument expired 19 days later when 0006's own C2/D9 slice added that edge for the kernel. As of 2026-07-27 `cli/go.mod:11` and `opm-operator/go.mod:15` both require `github.com/open-platform-model/library v1.0.0-alpha.8`, the same version. The coordination cost is already paid and already bought the harder half of the pipeline.

Its "third representation" objection was aimed at the runtime-neutral entry type D13.1 specified: a shared library type "adds a third representation everything maps through rather than collapsing the two that actually matter." Under D2 there is no third representation: the library type is the Kubernetes type, which is the same shape the CRD already anchors and which enhancement 0008 intends to generate from CUE.

What D31 got right and this decision preserves is that none of this logic is *cross-actor compared*. That is why the failure did not appear as a handoff bug. It appeared as three single-actor defects instead, each invisible to a cross-actor argument and each the direct consequence of a component existing twice:

- a CLI that deletes CRDs
- a CLI that prunes without checking live ownership
- an operator that force-applies over foreign objects

**Source:** User decision 2026-07-27, from an explore-mode session investigating enhancement 0010's OQ10. Evidence gathered in the same session and recorded in [`01-problem.md`](01-problem.md); every file reference verified against the working tree that day.

**Revised:** 2026-10-02: the title names the library's Kubernetes tier (0012:D3) where it named the kernel. The decision text and its requirements are unchanged.

---

### D2: The library is written for Kubernetes; no portability abstraction is maintained on its behalf

**Kind:** policy

**Decision:** Kubernetes is the library's one platform. The library abstracts over no other. Its Kubernetes surface lives in the library's Kubernetes tier (0012:D3) and is written directly against Kubernetes concepts: GVK, namespace, labels, ownerReferences, finalizers, propagation policy. There is no intervening neutral vocabulary, and no generalisation work is undertaken to keep a non-Kubernetes backend viable. `k8s.io/apimachinery` becomes a library dependency, imported by that tier only, and therefore, by MVS, a floor for every embedder.

The dependency is bounded to `apimachinery`. `client-go`, `controller-runtime`, and Flux are explicitly excluded. The first is excluded because the library does not resolve credentials. The second and third are the operator's framework and must not become the CLI's.

**Requirements:** none (vocabulary and dependency posture; every behaviour it enables is stated under D1)

**Alternatives considered:**

- **Retain the neutral `core.Resource` / `Identity` contract and add Kubernetes as an implementation of it.** Not chosen. It is the smaller change and would satisfy 0012:D1 on its own, but it preserves an abstraction with exactly one implementation and no named consumer. It also forces every new Kubernetes concept (propagation policy, finalizers, ownerReferences, subresources) through a vocabulary that cannot express it. Whether the neutral contract was deleted outright or left in place unused was a narrower question about semver blast radius. 0012:OQ3 answered it on 2026-09-01: the contract was deleted.
- **Keep the library platform-neutral and put the Kubernetes tier in a fourth module.** Rejected: it reproduces 0006:D31's coordination cost that 0012:D1 just established is no longer necessary to pay, and it splits the kernel's version line for no consumer's benefit.

**Rationale:** The neutral contract was not earning its cost. `library/opm/core/resource.go` named docker-compose, Nomad, Terraform, and Crossplane as the platforms it existed to serve (the file was deleted 2026-09-01, 0012:OQ3). None exists, and none is scheduled. The abstraction's only effect was to stop Kubernetes logic from living in the library, the direct cause of the duplication 0012:D1 addresses. Generalising in advance of a second platform is the speculative-abstraction failure, and paying for it with a real correctness defect in the one platform that does exist is a bad trade.

The narrower reading also matters for what this decision is *not*: it does not license controller concerns into `opm/`. The library gains Kubernetes vocabulary in its Kubernetes tier and gains no runtime. Principle I's substance is unaffected: determinism, no globals, no hidden environment, I/O at the edges with caller-supplied configuration. The existing OCI registry loader is the precedent for edge I/O under exactly those terms.

**Source:** User decision 2026-07-27, restated after an initial recommendation to keep the neutral contract and add Kubernetes as a tier beneath it. The user's framing: the kernel should be written for Kubernetes "so we don't have to think about portability and generalization".

**Revised:** 2026-10-02: "kernel" now reads as the library's Kubernetes tier (0012:D3). The kernel package itself imports no Kubernetes package. The platform, the dependency bound and the absence of a portability layer are unchanged. The first alternative records 0012:OQ3's 2026-09-01 answer.

---

### D3: The Kubernetes runtime decisions live in a fenced tier, `opm/k8s`, beside the kernel and inside the library module

**Kind:** contract

**Depends:** 0009:D4

**Decision:** The Kubernetes runtime decisions 0012:D1 lists (inventory entry construction, the stale set, digests, prune and ownership guards at apply and delete time, deletion ordering and the deletion hold protocol) live in a new library tier, `opm/k8s`, together with conversion of the kernel's compiled output to Kubernetes objects, the label vocabulary, kind-class apply order and readiness evaluation. The tier sits beside the kernel: it is not inside the kernel package and not under the opt-in `opm/helper` tier. Its package split is settled by the implementing changes; the indicative packages are labels, object, inventory, ownership, lifecycle and health.

Five properties bind the tier:

1. **Fence.** No library package outside `opm/k8s` imports it: not the kernel, module, platform, catalog, schema or errors packages, nothing internal, and nothing under `opm/helper`. The kernel imports no `k8s.io` package at all. The tier's outward bound is a denylist. Beyond the standard library and the CUE SDK that the kernel's output types carry, the tier imports only the kernel's exported packages and `k8s.io/apimachinery`. It never imports `client-go`, `controller-runtime`, any Flux package, any cluster client, `opm/internal` or `opm/helper`. The fence is checked mechanically on every library change, and the check exists before the first package does.
2. **Obligation.** The tier is not opt-in for a frontend that targets Kubernetes. A frontend that adopts a package deletes its own copy of that package's decisions in the same release, with no alias left behind, and from then on its own checks refuse a reintroduced copy. Deletion is a step protocol, so a frontend makes progress only by asking the tier for the next action and cannot route around a guard.
3. **No plan-driving loop and no cluster action, anywhere in the library.** The tier names actions and the frontend performs them with its own client, as library ADR-008 rules 1 to 3 require. ADR-008 rule 1 keeps any loop that drives a plan to completion out of the whole library. No code that performs a planned action against a cluster ships in any tier either. ADR-008 rule 3 allowed opt-in executor backends under `opm/helper/`; an in-place amendment to ADR-008 citing library ADR-011 narrows that allowance rather than retiring it (open-platform-model/library#159). It keeps the backends that do not act on a cluster, the wasm, container, HTTP and `cue.eval` hosts 0009:D4 places there, and excludes any backend that acts on a cluster. Each frontend writes its own short loop and performs every cluster action with its own client.
4. **Same Go module.** The tier is versioned and released with the kernel in the library's one Go module. It has no nested module of its own.
5. **Kubernetes apply identity moves in.** The duplicate rendered-identity check that lives in the helper tier today is Kubernetes-specific and moves into the tier with its first package.

0012:D1 says the decisions live in the library with one implementation each, and this decision says where in the library. The kernel itself stays "CUE in, verdicts out". Because the tier shares the library module, `apimachinery` still enters the library's `go.mod` and is still an MVS floor for every embedder.

**Requirements:**

- R1: Every Kubernetes runtime decision the library makes is reachable from one tier, `opm/k8s`, which is neither the kernel package nor part of the opt-in helper tier.
- R2: A program that imports the kernel and not `opm/k8s` compiles no `k8s.io` package.
- R3: Beyond the standard library and the CUE SDK that the kernel's output types carry, `opm/k8s` imports only the kernel's exported packages and `k8s.io/apimachinery`. It imports no `opm/internal` or `opm/helper` package. Its transitive imports contain no `client-go`, `controller-runtime`, Flux package or cluster client, and it opens no connection to a cluster.
- R4: A library change that imports `opm/k8s` from outside it, imports a forbidden dependency into it, or imports a `k8s.io` package into the kernel fails the library's own checks.
- R5: `opm/k8s` is released under the same module version as the kernel; an embedder pins one library version for both.
- R6: From the release in which a Kubernetes frontend adopts an `opm/k8s` package, that frontend carries no implementation of its own of the decisions the package makes and no alias to it, and its checks refuse a reintroduced copy.
- R7: The duplicate rendered-identity check is served by `opm/k8s` and no longer by the helper tier.
- R8: No library package, in any tier, contains a loop that drives a plan to completion or code that performs a planned action against a cluster.

**Alternatives considered:**

- **Inside the kernel package**, as 0012:D1's title and 0012:D2's wording read before their 2026-10-02 revision. Not chosen: the kernel would import `apimachinery`, and ADR-005, ADR-007 and ADR-008 reason about a kernel that takes CUE in and gives verdicts out. Keeping the kernel free of Kubernetes types keeps that reasoning intact at no cost, since nothing in the kernel needs them.
- **Under the opt-in `opm/helper` tier.** Not chosen: the helper tier is opt-in by definition, and a frontend may skip it. A safety guard a frontend may skip is the shape 0006:D31 reverted, because nothing forced its use.
- **A nested Go module for the tier.** Not chosen: it adds a hop to the release cascade and allows version skew between the kernel and the tier. Both first-party frontends already depend on `apimachinery`, so the MVS floor the shared module imposes costs them nothing. Revisit only if a non-Kubernetes embedder appears.
- **A fence added once the first package lands.** Not chosen: a package written before its fence can acquire a forbidden import that the fence then has to argue away.

**Rationale:** The kernel and the Kubernetes tier have different reasons to change and different dependency budgets. Putting them side by side in one module gets the single version line 0012:D1 relies on while keeping the kernel's import graph free of Kubernetes. Making the tier mandatory rather than opt-in is what separates it from the package 0006:D31 removed. The fence follows the precedent the library already runs for the helper tier, where an import linter refuses a kernel package importing anything under it on every PR.

**Source:** Owner decision 2026-10-02, choosing `opm/k8s` over both the kernel and the helper tier, and a second owner decision the same day that no code in the library performs a planned action against a cluster, which narrows ADR-008 rule 3's helper-backend allowance to backends that do not act on a cluster and leaves 0009:D4 standing. Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier). The helper tier's opt-in definition and its import fence are read from `library/opm/helper/doc.go`.

---

### D4: The library owns the whole deletion sequence but only the per-object verdict and the order for apply

**Kind:** contract

**Decision:** For deletion, the library owns the whole sequence: the plan, each transition naming the next action, and the verdict on releasing the hold. For apply, the library owns the per-object verdict, which permits or refuses the object with a reason, and the order objects are applied in. It does not own the apply engine. The operator keeps its Flux staged server-side apply and the CLI keeps its own server-side apply, each consulting the verdict and the order. Each frontend submits objects in the library's order. An engine's own staging, such as Flux's, may refine that order, for example by sorting within a stage, and never contradicts it. Both halves follow library ADR-008: the library names actions and never performs them.

**Requirements:**

- R1: A frontend deletes an object only when the deletion transition names that deletion as the next action, and releases an instance's hold only on a release verdict.
- R2: Before a frontend applies an object, the library's verdict for that object has permitted it; a refused object is not applied and the reason is reported.
- R3: Each frontend submits an instance's objects in the order the library gives. An engine's own staging may refine that order and never contradicts it.
- R4: The CLI's build contains no Flux or `controller-runtime` package as a consequence of this entry.

**Alternatives considered:**

- **The library owns the apply sequence too, through one shared engine.** Not chosen: the operator's engine is `fluxcd/pkg/ssa`, and forcing it on the CLI pulls `controller-runtime` into it. 0006:D13's static analysis is why that edge is refused.
- **The library owns verdicts only, for delete as well as apply.** Not chosen: a plan a frontend can decline to follow is how the CLI came to lack the CRD exclusion the operator has. Deletion carries no framework opinion, so nothing stops the library owning its sequence.
- **An apply executor in the opt-in helper tier.** Not chosen: it would be a third apply engine beside the two that exist, and anything in the helper tier may be skipped. ADR-008 rule 3, as narrowed, allows only backends that do not act on a cluster there (0012:D3), and an apply executor acts on one.

**Rationale:** The asymmetry follows where the framework opinion is. Deletion is order, fetch, guard and delete, with no opinion to inherit, so the library can own every step and the frontend only performs them. Apply carries Flux's staging opinion in the operator, which the CLI must not inherit. Sharing the verdict and the order still closes the divergence that matters: the apply-time collision guard the operator lacks becomes one verdict both frontends consult.

**Source:** Owner decision 2026-10-02, answering the open half of 0012:OQ1 and part of 0012:OQ8. The refinement rule for engine staging is the owner's answer of the same day. Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier).

---

### D5: Ordering has two layers: kind-class order in the Kubernetes tier, module-declared order as data off the build

**Kind:** contract

**Decision:** Object ordering has two layers with two homes. Kind-class order is a fact about Kubernetes: a CustomResourceDefinition before the resources of its kind, a Namespace before the objects in it, and the like. It has one definition, a single weight table in the Kubernetes tier's object package, which both frontends use for apply and delete. Module-declared order (hooks, `dependsOn`, phases) is data the CUE build emits and the library decodes, per library ADR-008 rule 4.

That rule says the kernel derives no ordering of its own. It is read as: the kernel derives no module-specific ordering. Kind-class order is a property of the Kubernetes API. The kernel does not derive it from a module, so a kind-class table in the tier does not breach rule 4.

**Requirements:**

- R1: The CLI and the operator order the same set of objects by kind class identically, for apply and for delete. For apply, this is the order each frontend submits. An engine's own staging may refine it within a stage and never contradicts it.
- R2: A change to kind-class order is made once, in the library, and reaches both frontends through a library version bump.
- R3: Any ordering a module declares reaches the frontend as data from the module's CUE build; the library adds no module-specific ordering of its own.

**Alternatives considered:**

- **Kind-class order as CUE data off the build too.** Not chosen: it would make every module, or core, restate a fact about the Kubernetes API that does not vary by module.
- **Each frontend keeps its own kind-class order.** Not chosen: the operator deleted its weight table on 2026-09-13 and orders through Flux, and the CLI lost weight-ordered apply when its render path changed and nothing failed. A rule with two homes has already drifted once.

**Rationale:** The two layers have different sources of truth. One is the Kubernetes API, which is the same for every module and belongs with the other Kubernetes facts in the tier. The other is what a module author declares, which can only come from the module. Keeping them apart lets ADR-008 rule 4 keep its point, that the library invents no ordering a module did not ask for.

**Source:** Owner decision 2026-10-02. Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier), which also states the clarified reading of ADR-008 rule 4. The single remaining weight table is read from `cli/pkg/resourceorder` on 2026-10-02.

---

### D6: Labels are stamped by the CUE render; the shared render digest ignores the runtime-name label value

**Kind:** contract

**Depends:** 0010:D9

**Decision:** OPM's labels are stamped on rendered objects by the CUE build at render, as core's transformer contract does today, with the runtime name filled into core's `#runtimeName` by whichever frontend renders. Go code reads the labels and never stamps them. The render digest has one definition in the Kubernetes tier. It excludes the value of the runtime-name label (`app.kubernetes.io/managed-by`). So the CLI and the operator digest the same render to the same bytes, though each stamps its own name. This is what lets 0012:D1's first requirement hold for digests.

This agrees with 0010:D9 as revised. The schema declares the module version label, and the kernel verifies it. Nothing in either entry moves stamping out of CUE.

**Requirements:**

- R1: Every OPM label on a rendered object is present in the output of the CUE render, before any frontend code handles the object.
- R2: For the same rendered objects, the CLI and the operator compute the same render digest, whichever runtime name each stamped.
- R3: Two renders that differ in any other label, or in any other content of an object, produce different render digests.

**Alternatives considered:**

- **The library stamps labels in Go after render.** Not chosen: it would split the label set between CUE and Go, and core's transformer contract already composes it, with the runtime name as the one input a frontend supplies.
- **Keep the managed-by value in the digest.** Not chosen: the two runtimes stamp different values, so the digests of one render can never agree, and the byte-for-byte parity the CLI's digest comment claims holds only for the algorithm, never for the value.
- **Each frontend digests its own way.** Not chosen: that is the hand-synced duplication 0012:D1 removes.

**Rationale:** Stamping belongs where the label set is composed, and that is CUE. The digest's job is to say whether two renders produced the same objects, and which runtime rendered them is not part of that answer. Excluding exactly one label value keeps every other change visible. It is also what lets 0006:D7's handoff check hold. The CLI records `status.lastAppliedRenderDigest` so a later ownership transfer has a value to verify against, and today that comparison cannot match, because each runtime stamps its own name.

**Source:** Owner decision 2026-10-02, answering 0012:OQ11. Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier). Read on 2026-10-02: `cli/internal/inventory/digest.go` hashes each object's full JSON, managed-by label included, and `core/src/platform_and_match_pins.cue` shows the runtime filling `#runtimeName`. 0010:D9 is read from `archive/0010/03-decisions.md`.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
