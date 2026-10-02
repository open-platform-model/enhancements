# Risks, Drawbacks, Alternatives: Kubernetes as a First-Class Kernel Platform

Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken. Per-decision alternatives live in [`03-decisions.md`](03-decisions.md).

## Risks and Mitigations

**Whether this holds**

- **This gets reverted again.** The direct precedent is 0006 D31, which deleted this exact package after it shipped. A second revert would be worse than never starting, because it would burn both frontends' migration a second time and settle the question by exhaustion rather than evidence. **Mitigation:** D1 supersedes D31 on named facts that changed (the `go.mod` edge now exists; the neutral-type objection does not apply under D2), so a future revert has to argue against those facts rather than re-litigate the original ones. The `accepted → implemented` gate also requires a conformance test rather than a helper package: the shape D31 correctly identified as "actively misleading… that nothing actually imports" is specifically not what ships.

- **The library becomes the operator's second implementation rather than its only one.** If the operator keeps its Flux SSA staging and the library grows a parallel apply path, the duplication returns with an extra layer. **Mitigation:** the apply/delete asymmetry is a decision, not an omission (0012:D4): the library owns apply *verdicts* and order, never an apply *engine*. A library apply executor is out of scope and should be refused if proposed during implementation.

- **A `client-go` or `controller-runtime` dependency creeps into `library`.** The dependency bound is the whole reason the CLI can adopt this. One convenience import and the CLI inherits the operator's framework, which 0006 D13 ruled out on static-analysis evidence that has not changed. **Mitigation:** 0012:D3 fences the tier mechanically from day one, before any tier package exists, the same way the helper tier is fenced today: nothing outside the tier imports it, the kernel imports no Kubernetes package, and the tier imports only the kernel's output types and `apimachinery`. Library ADR-011 states the bound.

**Dependency and migration mechanics**

- **The `apimachinery` MVS floor breaks a consumer.** `library` sets a version floor for every embedder, exactly as it already does for the CUE SDK. `cli` is on `k8s.io/apimachinery v0.36.0` and `opm-operator` on `v0.36.2` today, so nothing breaks now, but the library now constrains a dependency it does not otherwise use, and a future Kubernetes-version disagreement between the two frontends becomes a library problem. **Mitigation:** pin conservatively (floor at the lower of the two consumers), and record the floor in `MIGRATIONS.md` the way the CUE floor already is.

- **The migration window is a period where guards exist in three places.** Between the tier landing and both frontends adopting, each divergence is live in the old copy, the new tier, and possibly a partially-migrated frontend. **Mitigation:** slice so each tier package and its first consumer land together, and delete the old copy in the same change rather than leaving a deprecation window: 0006's own operational note established no-deprecation-window as the convention here.

**What could still go wrong after this ships**

- **`ownerReferences` land anyway and silently break the `prune: false` contract.** If OQ4 resolves toward candidate (b) without handling the interaction, namespaced resources are garbage-collected on instance delete for users who explicitly relied on orphaning. The failure is silent and irreversible. **Mitigation:** OQ4 is a `draft → accepted` blocker, and any resolution that stamps references must state the `spec.prune` interaction explicitly rather than leaving it implied.

- **Flipping `spec.prune`'s default (OQ5) destroys workloads on the next delete.** Every existing instance was created under orphan-by-default; a default flip changes the meaning of a `kubectl delete` that operators have already learned is safe. **Mitigation:** treat it as a breaking operational change with its own migration note, or leave the default and improve the warning surface. Not a decision to make incidentally alongside the code move.

- **Divergence reappears above the tier.** Nothing in the library stops a frontend from adding a new local guard next year. **Mitigation:** partial by nature. The conformance test covers the plan-versus-execution gap, and under 0012:D3 a frontend that has adopted a tier package refuses a reintroduced copy of it in its own checks. Neither stops a genuinely new decision being written in the wrong place; library ADR-011 names `opm/k8s` as the required home for Kubernetes decisions so a reviewer has something to point at.

## Drawbacks

- **The library stops being platform-neutral, and says so.** `opm/core/resource.go`'s promise to docker-compose, Nomad, Terraform, and Crossplane is withdrawn. If a second platform is ever wanted, the generalisation work is done then, against a real second consumer, and it will be more expensive than maintaining the abstraction would have been. D2 accepts that trade deliberately.
- **`library/CONSTITUTION.md` is amended.** Principle III's package list and Principle IV's "MUST NOT import command, controller, or runtime-specific concerns" both change. Amending a constitution to fit a design is a cost even when the amendment is correct, and it lowers the bar for the next amendment.
- **Library changes now carry cluster-destructive blast radius.** A bug in `DeletionPlan` is a bug in what both tools delete. The current arrangement at least fails independently. Test coverage on the tier's decision paths has to be materially better than what either frontend carries today, not equivalent.
- **The library's release cadence becomes a dependency for frontend safety fixes.** Fixing a prune guard means a library release plus two frontend bumps, where today it is one PR in one repo. This is D31's coordination-cost objection, and it is real even though its magnitude has dropped now that the edge exists.
- **A larger public API surface under SemVer.** Everything in `opm/k8s/` is mandatory contract for a Kubernetes frontend, not the opt-in `helper/` tier (0012:D3), and it ships in the library's one module, so its shape is a compatibility obligation from the first release.

## Alternatives

- **Documented conventions instead of shared code.** Each frontend keeps its implementation; the guards and comparators are specified in prose both repos follow. **Why not:** measured and failed: 0006's OQ15 and OQ16 are exactly this, recorded 2026-07-01 and still unimplemented on 2026-07-27, while two further divergences that no convention documented went unnoticed over the same period.
- **The tier inside the kernel package, or under the opt-in helper tier.** **Why not:** inside the kernel it brings `apimachinery` into the package that ADR-005, ADR-007 and ADR-008 reason about as "CUE in, verdicts out"; under the helper tier it becomes skippable, the shape 0006:D31 reverted. See 0012:D3.
- **The tier in a nested Go module.** **Why not:** an extra release-cascade hop and version skew between kernel and tier, to spare embedders an `apimachinery` floor neither first-party frontend minds. Revisit if a non-Kubernetes embedder appears (0012:D3).
- **A cross-repo conformance suite over independent implementations.** Keep both implementations, add a shared test corpus each must pass. **Why not:** it fixes behaviour without fixing cost: every new capability is still written twice, which is the generative problem D1 targets rather than its symptoms. It would have been the enforcement mechanism had OQ1 resolved to Rung 2; it resolved to a caller-driven transition instead (0012:D4).
- **Fold the CLI's cluster-mutating paths into the operator entirely**: the CLI edits CRs and never applies or deletes directly. **Why not:** it deletes a supported workflow (CLI-solo, no operator installed) that 0006 built deliberately, and it answers a duplication problem by removing a product capability.
- **Move the shared surface into `core/` as CUE and generate both Go sides.** **Why not:** the surface in question is decision logic (ordering, guards, state machines), not schema. CUE is the right home for the wire shapes and the policy vocabulary, which is why `contracts/contracts.cue` carries them; it is not the right home for `DeletionPlan`. Enhancement 0008 owns the part that genuinely is schema.
