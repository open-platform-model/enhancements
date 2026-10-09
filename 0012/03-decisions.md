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
- R4: A live object whose manager label is not an OPM runtime identity, whose instance identity differs from the deleting instance's, or whose adopt annotation names another instance (0012:D8:R8), is skipped by both frontends with the reason named.
- R5: Whether an instance's deletion hold may be released is decided from its policy and the plan's outcome, identically for whichever frontend asks, with the reason named.
- R6: Deletions happen in a defined order that is the same on both frontends.
- R7: Before applying, each object receives a verdict, and the verdict is the same on both frontends. It refuses an existing object that is being deleted, whether or not it is in the instance's inventory. It refuses an existing object outside the instance's recorded inventory that OPM does not manage, that carries another instance's identity, or whose adopt annotation names another instance, unless the adopt annotation of 0012:D8 names this instance. When the instance's identity is known, it also refuses an existing object in the recorded inventory whose adopt annotation names another instance (0012:D8:R8).

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

**Revised:** 2026-10-03: R7 names the two ownership refusals, their scope (objects outside the recorded inventory) and their one override, the adopt annotation, to match 0012:D8. The refusal of an object being deleted is unchanged and covers every object.

**Revised:** 2026-10-04: R4 excepts the operator install's deletion of proven earlier-manifest objects (0012:D8:R7).

**Revised:** 2026-10-05: R7's ownership refusals are no longer limited to objects outside the recorded inventory. It also refuses an object whose adopt annotation names another instance, inside the inventory or outside it, and R4 skips such an object, both to match 0012:D8:R8. R4's exception for the operator install's deletions no longer lifts that skip.

**Revised:** 2026-10-09: R4 and R7 drop the install exceptions, because 0012:D8 withdraws its install admission and install deletions (R6, R7). The adopt annotation is once more the only override.

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

**Amends:** 0009:D4

**Decision:** The Kubernetes runtime decisions 0012:D1 lists (inventory entry construction, the stale set, digests, prune and ownership guards at apply and delete time, deletion ordering and the deletion hold protocol) live in a new library tier, `opm/k8s`, together with conversion of the kernel's compiled output to Kubernetes objects, the label vocabulary, kind-class apply order and readiness evaluation. The tier sits beside the kernel: it is not inside the kernel package and not under the opt-in `opm/helper` tier. Its package split is settled by the implementing changes; the indicative packages are labels, object, inventory, ownership, lifecycle and health.

Five properties bind the tier:

1. **Fence.** No library package outside `opm/k8s` imports it: not the kernel, module, platform, catalog, schema or errors packages, nothing internal, and nothing under `opm/helper`. The kernel imports no `k8s.io` or `sigs.k8s.io` package at all. Beyond the standard library and the CUE SDK that the kernel's output types carry, the tier imports only the kernel's exported packages and `k8s.io/apimachinery`. It never imports `client-go`, `controller-runtime`, any Flux package, any cluster client, `opm/internal` or `opm/helper`. The library's lint refuses, before the first tier package exists, any other `k8s.io` module and any `sigs.k8s.io` module in the tier, Flux, `opm/internal` and `opm/helper` in the tier, any Kubernetes module in the kernel or the helper tier, and `client-go`, `controller-runtime` and Flux anywhere in the library. Any other third-party import into the tier is held by review.
2. **Obligation.** The tier is not opt-in for a frontend that targets Kubernetes. A frontend that adopts a package deletes its own copy of that package's decisions in the same release, with no alias left behind, and from then on its own checks refuse a reintroduced copy. Deletion is a step protocol, so a frontend makes progress only by asking the tier for the next action and cannot route around a guard.
3. **No plan-driving loop and no cluster action, anywhere in the library.** The tier names actions and the frontend performs them with its own client, as library ADR-008 rules 1 to 3 require. ADR-008 rule 1 keeps any loop that drives a plan to completion out of the whole library. No code that performs a planned action against a cluster ships in any tier either. ADR-008 rule 3 allowed opt-in executor backends under `opm/helper/`; an in-place amendment to ADR-008 citing library ADR-011 (open-platform-model/library#159) limits that allowance to executor backends that perform no planned action against a cluster. This amends 0009:D4. 0009's wasm, HTTP, `cue.eval` and local container hosts may still ship opt-in under `opm/helper/`. 0009's k8s get/apply Ops and the container host's Job-rendering variant perform a planned action against a cluster, so the frontend performs them (0012:OQ10). Each frontend writes its own short loop and performs every planned action against a cluster with its own client.
4. **Same Go module.** The tier is versioned and released with the kernel in the library's one Go module. It has no nested module of its own.
5. **Kubernetes apply identity moves in.** The duplicate rendered-identity check that lives in the helper tier today is Kubernetes-specific and moves into the tier with its first package.

0012:D1 says the decisions live in the library with one implementation each, and this decision says where in the library. The kernel itself stays "CUE in, verdicts out". Because the tier shares the library module, `apimachinery` still enters the library's `go.mod` and is still an MVS floor for every embedder.

**Requirements:**

- R1: Every Kubernetes runtime decision the library makes is reachable from one tier, `opm/k8s`, which is neither the kernel package nor part of the opt-in helper tier.
- R2: A program that imports the kernel and not `opm/k8s` compiles no `k8s.io` package.
- R3: Beyond the standard library and the CUE SDK that the kernel's output types carry, `opm/k8s` imports only the kernel's exported packages and `k8s.io/apimachinery`. It imports no `opm/internal` or `opm/helper` package. Its transitive imports contain no `client-go`, `controller-runtime`, Flux package or cluster client, and it opens no connection to a cluster.
- R4: A library change that imports `opm/k8s` from outside it, imports into it a Kubernetes module other than `k8s.io/apimachinery`, Flux, `opm/internal` or `opm/helper`, or imports a `k8s.io` or `sigs.k8s.io` package into the kernel or the helper tier fails the library's own checks.
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

**Source:** Owner decision 2026-10-02, choosing `opm/k8s` over both the kernel and the helper tier, and a second owner decision the same day that no code in the library performs a planned action against a cluster, which limits ADR-008 rule 3's helper-backend allowance to executor backends that perform no planned action against a cluster. A third owner decision that day records this as an amendment of 0009:D4: its hosts that perform no planned action against a cluster stand, and its k8s get/apply Ops and Job-rendering container variant move to the frontend (0012:OQ10). Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier). The helper tier's opt-in definition and its import fence are read from `library/opm/helper/doc.go`.

---

### D4: The library owns the whole deletion sequence but only the per-object verdict and the order for apply

**Kind:** contract

**Decision:** For deletion, the library owns the whole sequence: the plan, each transition naming the next action, and the verdict on releasing the hold. For apply, the library owns the per-object verdict, which permits or refuses the object with a reason, and the order objects are applied in. It does not own the apply engine. The operator keeps its Flux staged server-side apply and the CLI keeps its own server-side apply, each consulting the verdict and the order. Each frontend submits objects in the library's order. An engine's own staging, such as Flux's, may refine that order, for example by sorting within a stage, and never contradicts it. Both halves follow library ADR-008: the library names actions and never performs them.

The deletion protocol is this entry's, not 0009's. This entry defines the deletion plan, its state, the transition and the hold verdict, and both frontends' delete paths use them. The state is a serialisable value the caller holds, so the operator carries it across reconciles and the CLI holds it in memory for one command. The protocol carries no hook semantics: it deletes, skips and releases the hold, and runs no step a module declares around a deletion.

**Requirements:**

- R1: A frontend deletes an object only when the deletion transition names that deletion as the next action, and releases an instance's hold only on a release verdict.
- R2: Before a frontend applies an object, the library's verdict for that object has permitted it; a refused object is not applied and the reason is reported.
- R3: Each frontend submits an instance's objects in the order the library gives. An engine's own staging may refine that order and never contradicts it.
- R4: The CLI's build contains no Flux or `controller-runtime` package as a consequence of this entry.
- R5: A deletion state written out and read back advances identically to one held in memory, and advancing the same plan and state twice names the same next action.
- R6: A deletion plan's actions are only deletions and skips of objects in the instance's inventory, plus the hold verdict; no step a module declares runs as part of it.

**Alternatives considered:**

- **The library owns the apply sequence too, through one shared engine.** Not chosen: the operator's engine is `fluxcd/pkg/ssa`, and forcing it on the CLI pulls `controller-runtime` into it. 0006:D13's static analysis is why that edge is refused.
- **The library owns verdicts only, for delete as well as apply.** Not chosen: a plan a frontend can decline to follow is how the CLI came to lack the CRD exclusion the operator has. Deletion carries no framework opinion, so nothing stops the library owning its sequence.
- **The deletion plan and state owned by 0009's execution half,** as one plan-and-state convention for every flow the kernel plans. Not chosen: 0009 is parked until hooks are wanted, and deletion is needed now by both frontends. Deletion carries no hook semantics, so it needs none of 0009's vocabulary.
- **An apply executor in the opt-in helper tier.** Not chosen: it would be a third apply engine beside the two that exist, and anything in the helper tier may be skipped. ADR-008 rule 3, as amended, allows there only executor backends that perform no planned action against a cluster (0012:D3), and an apply executor performs one.

**Rationale:** The asymmetry follows where the framework opinion is. Deletion is order, fetch, guard and delete, with no opinion to inherit, so the library can own every step and the frontend only performs them. Apply carries Flux's staging opinion in the operator, which the CLI must not inherit. Sharing the verdict and the order still closes the divergence that matters: the apply-time collision guard the operator lacks becomes one verdict both frontends consult.

**Source:** Owner decision 2026-10-02, answering the open half of 0012:OQ1 and part of 0012:OQ8. The refinement rule for engine staging is the owner's answer of the same day. Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier). Owner decision 2026-10-03 on the deletion protocol: "Deletion protocol only, in opm/k8s/lifecycle, owned by 0012 (DeletionPlan, serialisable State, Advance, MayReleaseHold), used by both frontends' delete paths; closes the ownership half of 0012:OQ10. No hook semantics."

**Revised:** 2026-10-03: the deletion protocol is this entry's rather than 0009's, its state is serialisable and caller-held, and it carries no hook semantics (R5, R6). Answers the ownership half of 0012:OQ10.

**Revised:** 2026-10-04: R1 excepts the operator install's deletion of proven earlier-manifest objects (0012:D8:R7).

**Revised:** 2026-10-09: R1 drops that exception, because 0012:D8 withdraws the install deletions (R7).

---

### D5: Ordering is kind-class order in the Kubernetes tier; no module-internal ordering is planned, and cross-module order belongs to a future Bundle

**Kind:** contract

**Decision:** The one object order the library supplies is kind-class order, a fact about Kubernetes: a CustomResourceDefinition before the resources of its kind, a Namespace before the objects in it, and the like. It has one definition, a single weight table in the Kubernetes tier's object package, which both frontends use for apply and delete.

No module-internal ordering is planned. A module does not order its own components or resources. The library applies every object in kind-class order, and Kubernetes' eventual consistency settles the rest, such as a workload that waits for its configuration or a controller that retries until its CRD is served. If module-internal ordering is ever needed, it comes off the CUE build as data the library decodes, per library ADR-008 rule 4, and never as ordering the library derives. Ordering across modules belongs to a future Bundle definition: a bundle of modules whose order is the order the bundle defines them in. This entry does not design it.

ADR-008 rule 4 says the kernel derives no ordering of its own. It is read as: the kernel derives no module-specific ordering. Kind-class order is a property of the Kubernetes API. The kernel does not derive it from a module, so a kind-class table in the tier does not breach rule 4.

**Requirements:**

- R1: The CLI and the operator order the same set of objects by kind class identically, for apply and for delete. For apply, this is the order each frontend submits. An engine's own staging may refine it within a stage and never contradicts it.
- R2: A change to kind-class order is made once, in the library, and reaches both frontends through a library version bump.
- R3: For the same set of objects, the library's apply and delete order is the same whichever module rendered them.

**Alternatives considered:**

- **Module-declared order (hooks, `dependsOn`, phases) as a second ordering layer off the build** (previously adopted, 2026-10-02). Not chosen on revision: the owner never intended ordering within a module. Kind-class order plus eventual consistency is the intended model, and a module-declared layer would be a second order no module asked for. The build stays the only place such ordering could come from if it is ever needed.
- **Kind-class order as CUE data off the build too.** Not chosen: it would make every module, or core, restate a fact about the Kubernetes API that does not vary by module.
- **Each frontend keeps its own kind-class order.** Not chosen: the operator deleted its weight table on 2026-09-13 and orders through Flux, and the CLI lost weight-ordered apply when its render path changed and nothing failed. A rule with two homes has already drifted once.

**Rationale:** Kind-class order comes from the Kubernetes API, which is the same for every module, so it belongs with the other Kubernetes facts in the tier. Order inside a module is not something OPM promises: Kubernetes converges objects applied in any order, and a promise of in-module order would need a vocabulary, a planner and a test surface for a need nobody has shown. Order between modules is a real need, and it has a natural home in a Bundle, where the author already lists the modules in sequence. Keeping both out of the library lets ADR-008 rule 4 keep its point, that the library invents no ordering a module did not ask for.

**Source:** Owner decision 2026-10-02 (kind-class order in the tier). Owner decision 2026-10-03, in the owner's words: "I never intended for dependsOn or ordering within a module, however that could change if deemed necessary. The plan was to eventually create a Bundle definition. A bundle of modules, and in this case build in ordering. But that implementation would likely just use the order you define the modules. This could also be done for component in the module but my intentions were always to let the kernel apply all resources in the order it wants and let k8s eventual consistency handle the rest." Recorded in library ADR-011 (`adr/011-kubernetes-tier-beside-the-kernel.md`, landing in the library change record-kubernetes-tier), which also states the clarified reading of ADR-008 rule 4. The single remaining weight table is read from `cli/pkg/resourceorder` on 2026-10-02.

**Revised:** 2026-10-03: module-declared order is no longer a planned second layer. No module-internal ordering is planned, cross-module order belongs to a future Bundle definition, and R3 is narrowed to its "the library adds no module-specific ordering" half, stated as the observable consequence.

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

---

### D7: The stale set is component-blind, and the inventory digest hashes a canonical field encoding

**Kind:** contract

**Decision:** The tier has one stale-set relation, and it is component-blind. An inventory entry is the same object as a rendered one when their group, kind, namespace and name agree, whichever component rendered it and at whichever API version. An object that moves from one component to another is therefore never stale, so the CLI's separate component-rename filter is unnecessary by construction and goes. Behaviour does not change: the filter existed only to rescue those objects.

The inventory digest has one definition in the tier. It hashes a canonical encoding of each entry, defined field by field, and not the JSON either frontend writes. A frontend may change how it serialises an entry without changing the digest. Both frontends' stored inventory digest changes once, when each first records the new digest, and the release that does so says so in a migration note.

**Requirements:**

- R1: An object whose group, kind, namespace and name appear in the current render is never in the stale set, whichever component rendered it before or now and at whichever API version. The one exception is an object in the inventory that the apply verdict refuses as `adopted-elsewhere` (0012:D8:R8): the instance drops it from the inventory it records, so it is in the stale set, and the deletion plan skips it (as `adopted-elsewhere` unless an earlier skip reason, such as `owner-mismatch`, applies).
- R2: The inventory digest depends only on the entries' field values. It does not depend on the order of the entries or on how either frontend serialises an entry, so a change to an entry's serialised form that keeps every field value leaves the digest unchanged.
- R3: Two inventories that differ in their set of entries, or in any field of an entry, produce different inventory digests.
- R4: The release of each frontend that first records the new inventory digest ships a migration note naming the one-time change of the stored digest.

**Alternatives considered:**

- **Component-aware identity, as the CLI's stale set compares today.** Not chosen: it marks a component rename as stale and then needs a second filter to rescue the object. The operator's component-blind relation gets the same outcome with one rule.
- **Keep hashing each frontend's JSON form of the entries.** Not chosen: the digest would then change whenever a frontend changes a serialisation detail, and the two frontends agree only while their encoders happen to agree. A canonical encoding makes agreement a property of the definition.
- **Keep the old digest values through a compatibility path.** Not chosen: the stored digest is compared only against a digest the same tier computes, so a one-time change with a migration note costs less than carrying two encodings.

**Rationale:** The stale set decides what gets deleted, so it should have one rule, and the rule that needs no rescue filter is the simpler one. The inventory digest is a stored value two frontends must compute identically. Defining its encoding field by field keeps it stable against changes that are not about the inventory at all.

**Source:** Owner decision 2026-10-03: "Inventory digest hashes a NEW canonical field-by-field encoding (independent of JSON tags); both frontends change their stored digest once, with a migration note. Close 0012:OQ7 as component-blind (no behaviour change; drop the CLI rename filter)." Read on 2026-10-03: the operator's inventory digest sorts the entries and hashes their JSON form (`opm-operator/internal/inventory/digest.go`), the operator's component-blind relation compares group, kind, namespace and name (`opm-operator/internal/inventory/entry.go`), and the CLI's rename filter rescues entries a component-aware relation marked stale (`cli/internal/inventory/stale.go`).

**Revised:** 2026-10-05: R1 excepts an object in the inventory refused as `adopted-elsewhere`, which is in the stale set and which the deletion plan skips (0012:D8:R8).

---

### D8: The apply guard runs on every apply, refusing foreign objects outside the inventory and any object adopted by another instance; a per-object adopt annotation is its only override

**Kind:** contract

**Decision:** The apply-time ownership guard, 0012:D4's per-object apply verdict, runs on every apply, not only on an instance's first. It judges every object the instance renders, inside its recorded inventory or not. An existing live object outside that inventory, which OPM does not manage or which carries another instance's identity, is refused with a reason. The one override is per object: the user sets the adopt annotation on the existing live object, and its value is the adopting instance's UUID, the value of that instance's `module-instance.opmodel.dev/uuid` label. The guard then permits that object for that instance. The annotation key is `opmodel.dev/adopt`, fixed by the library's label package, and it is part of this contract (`#AdoptAnnotation` in `contracts/contracts.cue`).

The annotation is also how an object moves between two live instances. When the live adopt annotation of an object in an instance's recorded inventory names another instance, the instance refuses the object with its own reason, `adopted-elsewhere`, and lets go of it: it does not apply it, it drops it from the inventory it records next, and it goes on applying its other objects. The object's UUID label alone never refuses an object in the inventory, so an instance whose own UUID changed keeps applying the objects it records, except an object whose adopt annotation still names its old UUID, which must be re-annotated with the new UUID. Outside the inventory, an object whose adopt annotation names another instance is never applied, so the instance does not take back an object it let go of; when that annotation equals the object's UUID label the hand-over is complete, and the reason is `adopted-elsewhere` rather than `other-instance`. No instance deletes an object whose adopt annotation names another instance. When the instance's own identity is unknown, an object in its inventory is not refused for ownership, while outside the inventory and on delete any adopt annotation counts as another instance's, since an unknown identity is never the one an annotation names.

No command-wide flag overrides the guard, and neither frontend sets the annotation on the user's behalf. Installing the operator gets no exception to the ownership refusals: it meets the guard as any instance's apply does, and it deletes nothing outside its instance's inventory. The adopt annotation naming this instance overrides only the three ownership refusals: `foreign-object`, `other-instance` and `adopted-elsewhere`. The verdict's other refusal, for an object being deleted (0012:D1:R7), covers every object, inside the inventory or not, and nothing overrides it.

A ModulePackage gets a persisted instance identity in an additive status field, so the guard compares identities for objects a ModulePackage owns exactly as it does for a ModuleInstance. This settles the two sub-questions 0012:OQ8 inherited from 0006.

**Requirements:**

- R1: An existing live object that is not in the instance's recorded inventory, and that OPM does not manage or that carries another instance's identity, is refused on every apply with a reason, unless it carries the adopt annotation naming this instance's identity. Creating an object that does not exist is never refused by this guard.
- R2: An object carrying the adopt annotation that names this instance's identity passes the ownership refusals and, unless it is being deleted, is applied and recorded in the instance's inventory. An annotation naming another instance's identity overrides nothing.
- R3: Neither frontend offers another override of the ownership refusals, no refusal message names one, and neither frontend sets the adopt annotation on the user's behalf. Installing the operator is no exception.
- R4: A ModulePackage carries its instance identity in its status across reconciles, and the guard protects objects it owns as it protects a ModuleInstance's. A ModulePackage created before the field existed gains it with no change to its spec.
- R5: An existing object that is being deleted is refused on every apply, whether or not it is in the instance's recorded inventory, and the adopt annotation does not override that refusal.
- R6: Removed (install admission withdrawn 2026-10-09). The number stays so citations resolve.
- R7: Removed (install deletions withdrawn 2026-10-09). The number stays so citations resolve.
- R8: When the instance's identity is known, an existing object in its recorded inventory whose live adopt annotation names another instance is refused with the reason `adopted-elsewhere`; its UUID label alone never refuses it. The instance does not apply that object and drops it from the inventory it records next. Outside the inventory, an existing object whose adopt annotation names another instance is refused as well, whether or not OPM manages it: as R1 states when OPM does not manage it, or when it carries a UUID label naming neither this instance nor the one its adopt annotation names; and otherwise as `adopted-elsewhere`, including when its UUID label names this instance or the instance its annotation names. A refusal as `adopted-elsewhere` does not stop the apply: the instance applies its other objects, records its inventory without the object and reports the reason. The one exception is installing the operator: it needs every object it renders, so when any of them is refused as `adopted-elsewhere` the install refuses before it changes anything, and names the object and the instance its annotation names. Neither frontend deletes an object whose adopt annotation is set and does not name the deleting instance, whatever the object's UUID label and the instance's identity are, whether in a prune or an instance deletion: the deletion plan skips it, with the reason `adopted-elsewhere` unless an earlier skip reason applies. When the instance's identity is unknown, an object in its inventory is not refused for ownership, and outside the inventory and on delete any adopt annotation names another instance.

**Alternatives considered:**

- **Run the guard only on an instance's first apply.** Not chosen: an instance's object set grows across releases, and an object added in a later release can collide with a foreign one as surely as on the first apply.
- **A command-wide force flag.** Not chosen: it overrides every object at once, including ones the user did not mean to take. The CLI's refusal text points at a `--force` that does not override this refusal today (read from the CLI on 2026-10-03; the text is removed by the cli change protect-crds-and-namespaces-in-prune-and-delete).
- **No override at all.** Not chosen: a user bringing an existing object under OPM would have to delete it first, which is the outage the guard exists to prevent.
- **Installing the operator admits, as if adopted, the objects it proves an earlier operator release's install manifest created, and deletes the proven earlier Deployment and the role bindings the module supersedes (previously adopted as R6 and R7, owner decision 2026-10-04).** Withdrawn: it existed only so the first module install could take over an operator installed from a manifest. Nobody runs OPM yet, so there is no such operator to take over, and the admission would keep a second path through the guard for a case that does not occur. An object such an install meets is refused as R1 states, and the user adopts it by annotation or removes it.
- **(moot since the 2026-10-09 withdrawal) Install writes the adopt annotation on the proven objects.** Not kept: what binds is which objects install takes, not whether the take is recorded as an annotation, and the decision names the observable rule only.
- **(moot since the 2026-10-09 withdrawal) Leave the earlier Deployment and role bindings for the user to delete.** Not chosen at the time: Kubernetes refuses to change an existing Deployment's selector, so the install fails until the Deployment is gone, and the earlier bindings would keep granting the operator's service account with no inventory recording them.
- **Let install override the guard for the operator's namespace.** Not chosen: it would take any object a user placed there, which is what a command-wide override was rejected for.
- **Judge only objects outside the recorded inventory (previously adopted, owner decision 2026-10-03).** Not kept: an instance that still records an object never judges it, so when another instance adopts the object the two re-apply it in turn, each relabelling it as its own, and a later prune or delete by either side races the other (enhancements#103).
- **Document the hand-over as "remove the object from the first instance, then adopt it".** Not chosen (enhancements#103): nothing enforces the order, and the fight it leaves possible is silent.
- **Reuse `other-instance` for the refusal inside the inventory.** Not chosen: a frontend leaves its inventory as it is on `other-instance` and drops the object on this refusal, so the two need distinct reasons. The same literal names the delete-time skip, because it states the same fact about the live object.
- **Stop the instance's whole apply on this refusal.** Not chosen: the instance would never record the inventory that drops the object, so it would fail on every apply for as long as its module renders the object.
- **Drop the object from the inventory and let the prune delete it.** Not chosen: the dropped object is in the stale set (0012:D7:R1), and the prune would delete the object the user is handing to another instance. The deletion plan skips it instead.
- **Also refuse an object in the inventory on its UUID label alone (selected, then narrowed, by the owner on 2026-10-05).** Not kept: an instance's UUID derives from its module's registry path, its name and its namespace, so moving a module to a new registry path would refuse and drop every object of every instance of it, and each later apply would refuse them as `other-instance` until each was annotated by hand. A hand-over by annotation is caught without it. Under the annotation rule a UUID change touches only an object the instance once adopted, whose annotation still names the old UUID; it must be re-annotated with the new UUID.

**Rationale:** The guard protects objects OPM did not create, and the risk exists on every apply that adds objects, not only the first. A per-object annotation on the live object makes adoption a deliberate act on exactly the object being taken, and it leaves a record on the object itself. The same annotation ends the hand-over between two live instances: the instance it does not name lets go of the object, neither re-applying nor deleting it, so the instance it names holds it alone. The ModulePackage identity closes the one owner kind the identity comparison could not see.

**Source:** Owner decision 2026-10-03: "Apply guard runs on every apply for objects not already in the instance inventory. Override = per-object adopt annotation on the existing object (e.g. `opmodel.dev/adopt: <instance-uuid>`); remove the broken --force text. ModulePackage gets a persisted UUID in an additive status field so the UUID guard applies. Settles the rest of 0012:OQ8." The CLI refusal text is read from `cli/internal/inventory/stale.go` on 2026-10-03. R6 and R7: Owner decision 2026-10-04 (`opm operator install` deploys the operator module as a CLI-owned instance; its first run over an operator installed from a manifest takes over that operator's objects, recreates the Deployment once and deletes the three earlier `*-rolebinding` objects). R8: Owner decision 2026-10-05 on enhancements#103, selecting "A refuses it too": "The apply guard also refuses an in-inventory object whose live adopt annotation or UUID label names another instance; A drops it from its next inventory. Extends 0012:D8." The owner narrowed that selection the same day to "annotation only": only a live adopt annotation naming another instance refuses an object in the inventory, and a UUID label alone does not, so a module whose registry path moves keeps working. Three parts of R8 are derived from "A drops it from its next inventory" and are not in the selection's text: the instance goes on applying its other objects and records the inventory without the object; an object annotated for another instance is refused outside the inventory too, so the instance does not take it back on its next apply; and no deletion removes such an object, so dropping it hands it over rather than pruning it. The unknown-identity rule is derived as well, because "names another instance" needs an instance to compare against, and so is the `adopted-elsewhere` reason for an object outside the inventory whose annotation equals its UUID label, so a completed hand-over does not fail the first instance's apply. The annotation key and its value, the adopting instance's UUID, are read from the library's label package (`opm/k8s/labels`), recorded here as enhancements#103 asks. The `adopted-elsewhere` literal matches the library change refuse-an-object-another-instance-adopted, which implements R8.

**Revised:** 2026-10-04: installing the operator admits, as if adopted, exactly the objects it proves came from an earlier operator release's manifest (R3 exception, R6), and may delete only the proven earlier Deployment and superseded role bindings (R7).

**Revised:** 2026-10-05: the guard also judges objects in the recorded inventory. An object there whose adopt annotation names another instance is refused as `adopted-elsewhere` and dropped from the next inventory, the apply goes on, and no instance re-takes or deletes an object annotated for another (R8). The annotation key is `opmodel.dev/adopt` and its value is the adopting instance's UUID.

**Revised:** 2026-10-08, by owner decision: R8 excepts the operator install from "does not stop the apply". Asked what `opm operator install` does when it meets an object it needs that another instance owns, the owner chose "Refuse with exit 2 (Recommended)". The install refuses before it changes anything. The owner's answer covers an object the install needs; that this is every object the install renders was settled when the CLI change that builds it was accepted, and the owner has not confirmed that scope. Every other apply still lets go of the object and goes on.

**Revised:** 2026-10-09, by owner decision: the install admission and the install deletions are withdrawn. The owner first decided on 2026-10-05 to remove all legacy-migration code. Asked on 2026-10-09 "The earlier plan (its D8) removes all legacy-migration code: the cli's manifest migration and the library's `Admit`. Since then this swarm's cli ownership guard started taking `Admit` as input. Still remove both?", the owner chose "Remove both (Recommended)". [The D8 in the question is a decision of the rename plan, not 0012:D8; the guard is the CLI's.] R6 and R7 are removed and keep their numbers. R3 no longer excepts install and now carries the rule that neither frontend sets the adopt annotation, which R6 held. R8 no longer refers to the install's admission or deletions; its install refusal of 2026-10-08 stands. The withdrawn rule moves to *Alternatives considered*. The Source line above keeps the 2026-10-04 decision as recorded.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
