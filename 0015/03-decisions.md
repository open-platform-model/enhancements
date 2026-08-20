# Design Decisions — Catalog Contracts, Provider Classes, and Transformer Registration

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** When a later decision reverses or amends an earlier one, record it as its own `DN` while the design is in motion, then weave it into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone pointing at where its content went. This keeps the log safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed. Compaction is governed by the `enhancement-compaction` skill; it never touches an `implemented` entry.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific — `"User decision YYYY-MM-DD"`, a URL, or a file path — so the provenance of a choice never gets lost. A decision revised by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered* always survives compaction, because it is what stops a rejected option being re-litigated later.

---

## Decisions

### D1: `#Catalog` publishes its contracts as members, beside its transformers

**Decision:** `#Catalog` gains `#resources`, `#traits` and `#blueprints` beside `#transformers`, each carrying the same kind of pattern constraint that stamps `metadata.modulePath` onto every member. A contract is a published member of the catalog artifact whether or not the same artifact ships an adapter for it.

This cashes in the extension `core/src/catalog.cue`'s own doc comment reserves: *"Adding sibling maps (#resources, #traits, #blueprints) is an additive extension if introspection demand surfaces later."* The demand has surfaced, and it is 0010 D37.

Four things stop being derivations and become lookups:

1. **D37's zero case becomes reportable.** The single-provider guard counts transformers *requiring* a provider-fulfilled contract, and today it can enumerate only contracts reachable from adapters — so zero providers is indistinguishable from a key that exists nowhere. With the contract as a member, materialize enumerates what is *defined* and crosses it against what is *required*.
2. **A platform readiness condition becomes computable with no module in hand.** "This platform subscribes to a contract nothing implements" is answerable at materialize rather than discovered at render by whoever deploys first.
3. **"Unimplemented" separates from "unknown" in the missed-demand diagnostic** — 0010 OQ3, which was left on the table there because the prefix derivation it needed is unreliable for exactly the reason D17 records.
4. **A primitive's owning catalog becomes structural.** 0010 D17 records as explicitly not delivered that "which catalog ships FQN X?" cannot be answered from the FQN, because the kind-segment count is not fixed. The stamp makes it unforgeable for contracts the same way it already is for transformers.

**Alternatives considered:**

- **Ship a no-op transformer so the contract reaches the index.** The only mechanism available today, and it is why this is a gap rather than an inconvenience. It inverts what the artifact means — an adapter that emits nothing is indistinguishable, to the matcher and to a reader, from an adapter that is broken. It is also self-defeating: the stub *is* a provider, so D37's arity guard counts it and the first real provider is the second one and gets refused.
- **Derive the contract set from the transformers' `required ∪ optional` maps and accept the blind spot.** This is today's behaviour and it cannot see the case the design exists to support. A provider-fulfilled contract is by definition one no adapter in its own catalog demands.
- **Put the contract inventory in the Platform rather than the Catalog.** Rejected: the platform would then restate what the catalog already knows, and the restatement can drift from the artifact it describes. The catalog is the thing that has the contracts.
- **One `#contracts` map keyed by kind instead of three maps.** Rejected for symmetry with `#transformers` and with `kindPrefix` (0010 D21), which already admits exactly one path per kind. Three maps mirror three kind prefixes.

**Rationale:** 0010 D37 defines a contract whose declaring catalog deliberately ships no transformer for it, and 0010's own integration points route D37's guard through `materialize/index.go`, which reads only `#transformers`. The design and the substrate disagree; this is the substrate catching up. It is additive to `#Catalog` — no existing catalog value changes meaning — and the values being listed already exist and are already imported by the transformers that demand them, so the catalog-side work is mechanical.

**Source:** User decision 2026-08-05. `#Catalog`'s single member map and its reserved-extension comment read at `core/src/catalog.cue`; the index construction at `library/opm/materialize/index.go:39-41` and `:80-96`, both 2026-08-05.

---

### D2: Two providers of one contract are routed by class, not refused

**Decision:** A provider-fulfilled contract may be implemented by more than one catalog on one platform. Routing is by **class** — a named vocabulary the platform publishes, one default per contract — carried to the matcher as a `matchLabels` entry under 0010 D36. This **amends 0010 D37**, whose exactly-one-provider rule and materialize-time refusal are replaced by an at-most-one-per-class rule.

The mechanism adds nothing to the matcher. D36 already puts `matchLabels` on `#Resource` / `#Trait` / `#Blueprint`, unifies them wholesale onto `#Component.matchLabels`, and repoints `#ComponentTransformer.requiredLabels` at that field. A contract carrying `class: "archive"` projects `matchLabels: {"<contract>/class": "archive"}`; a Velero transformer requiring that label matches and a k8up transformer requiring `"daily"` does not. `compile/match.go:344-360` is untouched.

**A module never names a provider.** It names a class, which is a platform-published vocabulary, or it names nothing and takes the default. The distinction is the whole design: a class is a choice from a menu the platform wrote, a provider name is a dependency on an implementation. A module that could say "k8up" would have no reason to declare a contract at all.

**Alternatives considered:**

- **Keep 0010 D37's exactly-one rule.** Rejected on the case that motivated the entry: restic-for-PVCs and namespace-snapshot backup are two legitimate reasons to back up differently on one cluster, and D37 forces the second one outside OPM — at which point the module stops declaring `backup` and declares a k8up resource, forfeiting the contract. D37 itself records the rule as provisional, pending a real instance to design against; this is that instance.
- **A hard guard on bucket arity — refuse two transformers whose predicates are comparable.** The alternative the author was offered and declined. It is the smaller change and it is strictly a refusal: it makes the two-engine topology a diagnosable error rather than an expressible state. Kept as an option for OQ1's narrower case, where the two transformers are two builds of the *same* adapter rather than two competing engines.
- **Per-contract explicit binding in the platform: contract FQN → one catalog.** This is a class vocabulary with exactly one class and no name, and it degenerates from the chosen design rather than competing with it. Rejected as the *general* answer because it cannot express per-workload routing, which is the requirement.
- **Catalog weights, newest-wins, or predicate-equality detection.** All rejected in 0010 D32 with measurements, and nothing here revives them. A weight arbitrates every contract two catalogs share with one number and records no reason; newest-wins compares versions from unrelated namespaces; predicate equality false-negatives on the real case (k8up requiring `backup` + `schedule` versus Velero requiring `backup` alone).
- **Capability-based routing** — the module states RPO, retention or "needs hooks" and the platform routes to whatever satisfies it. Strictly more expressive and probably the right end state. Deferred rather than rejected: classes degenerate to it cleanly, and it is a whole enhancement whose design should not be entangled with a schema gap and a CRD.

**Rationale:** Kubernetes solved this exact shape — many implementations, one abstract demand, admin-defined selection, app-side reference by name, a default so most consumers say nothing — four separate times: StorageClass, IngressClass, GatewayClass, VolumeSnapshotClass. Adopting the pattern buys a decade of production validation on the precise problem.

The reason to prefer it here specifically is that it costs no matcher change. 0010 D36 was designed for a different purpose and happens to be exactly the substrate a class needs: a label that unifies upward from a primitive to its component and is selected on by `requiredLabels`. Class values are mutually exclusive by construction, so at most one predicate holds — which is what makes this succeed where narrowing a predicate fails. Adding a required trait to one transformer excludes it from components lacking the trait but does nothing to exclude the *other* transformer from components that have it, because `fqnSubset` is subset containment and predicates are monotone.

What is genuinely new is small and bounded: the platform publishes the vocabulary, and something fills the default into demands that name no class. The second is OQ2.

**Source:** User decision 2026-08-05 ("I prefer class over guard if possible"). `candidateSatisfied` and `fqnSubset` read at `library/opm/compile/match.go:344-379`; the shipped discriminator measured at `catalog_opm/src/transformers/daemonset_transformer.cue:27-29`; 0010 D36's `matchLabels` wiring from that entry's Integration Points, all 2026-08-05.

---

### D3: A transformer registration is a cluster-scoped CR, gated by the RBAC the operator already enforces

**Decision:** Transformers reach a platform by two paths. The first is unchanged: a subscription written into the Platform CR's `spec.registry`. The second is a new cluster-scoped `TransformerRegistration` CR that a provider module ships among its rendered resources. Only a module applied under a platform-team identity can create one, because `opm-operator` already impersonates a per-tenant ServiceAccount during apply and a tenant role does not carry create on a cluster-scoped resource.

The CR is a **claim**, not a fact. The Platform reconciler validates it — catalog resolvable, declared contracts present in the subscribed catalogs' contract maps (D1), class not already taken — and records acceptance in `Platform.status.registry`. There remains exactly one writer to the materialized set, and one place to reject.

Three properties follow from the registration being an object rather than an event:

- **Activation is health-gated.** `spec.providerRef` names the provider's ModulePackage; the claim is accepted but inactive until that is Ready. This is the thing a static subscription structurally cannot express — a subscription is live from the moment it is written, while the CRDs its transformer renders against exist only once the provider is running.
- **Removal is refusable.** A finalizer blocks deletion while instances demand contracts the registration provides, naming the count.
- **The effective set is enumerable.** `kubectl get transformerregistrations` answers "what can this cluster render", and `Platform.status.registry` carries the resolved union.

**Alternatives considered:**

- **No second path — keep the Platform CR as the sole registry.** The status quo, and it is Gap 2: the provider's installation and its registration are one fact in the world and two edits in OPM, with no ordering relationship between them. Rejected, but its central objection is *not* answered by this decision and is carried as OQ3 — see Rationale.
- **Authoring-time splice: the provider catalog ships a `#Platform` fragment and a CLI command writes the subscription into the platform file.** Genuinely attractive, because it preserves 0010 D14's "the platform file is the lockfile" property completely and adds no runtime state. Rejected as the primary mechanism because it cannot health-gate — a file cannot say "not until the CRDs exist" — and because it still leaves the two acts separable. Worth building anyway as an ergonomic layer on top; it is how a GitOps platform team would prefer to author the subscription half.
- **Registration by annotation or label on the ModulePackage.** Rejected: it puts a cluster-scoped privilege on a namespaced object, which is exactly the escalation the CR exists to prevent, and it gives no place to record acceptance, health, or a finalizer.
- **A mutating admission webhook that writes accepted claims into the Platform CR's spec.** Rejected: it makes the Platform CR's spec no longer author-owned, so a GitOps reconciler and the webhook fight over the same field. Status is the correct home for a derived set.
- **Namespace-scoped registration, so a provider serves only its own namespace.** Rejected for the motivating case — backup is cluster infrastructure — and because a per-namespace match table multiplies the materialized platform by the namespace count. Worth revisiting only if a genuinely tenant-scoped adapter appears.

**Rationale:** The objection to a second registration path was never the mechanism, it was the privilege: a transformer is arbitrary CUE producing arbitrary Kubernetes objects, so the ability to register one is the ability to change how another team's `#Backup` trait renders. A cluster-scoped CR resolves that against a permission model the operator already has, rather than inventing one.

What this decision does **not** resolve is reproducibility. 0010 D14 deleted subscription resolution specifically so a render is reproducible from a commit — "the platform file is the lockfile". Once part of the effective registry lives in cluster state, a local `opm module render` and the operator's render can diverge, and 0014's export path sees a platform that is not the one in git. The CR makes the effective set enumerable and therefore fetchable, which is most of the value back, but "the platform file plus a cluster query" is a weaker property than "the platform file". That is OQ3, and it is a blocking question for `draft → accepted` rather than an implementation detail.

**Source:** User decision 2026-08-05 ("We only allow cluster admins to deploy OPM modules with this. Could be done by adding a new CR to the operator… This will enable us to gate it behind RBAC"). Tenancy model read at `opm-operator/docs/TENANCY.md` and the store's generation key at `internal/platform/store.go`, 2026-08-05.

---

### D4: Contracts and adapters stay in one CUE module

**Decision:** No packaging split. A catalog ships its contracts and its adapters in one CUE module, one `cue.mod`, one release, one subscription entry. `catalog_opm` is not divided into `catalogs/opm_contracts` + `catalogs/opm`.

This is recorded as a decision rather than left undecided because the timing is asymmetric: a contract FQN embeds its declaring catalog's registry path, so splitting changes **every contract FQN in the system** — every module import, every transformer's `requiredTraits` key. Riding 0010's already-major break costs nearly nothing; a standalone break later is a second flag day across five repos. Declining by default would have been a decision made by omission.

**Alternatives considered:**

- **Split contracts into their own module, so provider catalogs take a thin dependency.** The real benefit, and it is smaller than it looks: CUE fetches per module but evaluates per imported package, so `catalog_k8up` importing `opmodel.dev/catalogs/opm/traits` pays a fetch, not the evaluation of 23 adapters. Against it: every contract FQN moves, every platform's subscription list doubles, and a new skew failure mode appears between a contract module and its adapter module at different majors.
- **Split for governance — contracts are the standard, anyone ships adapters.** Rejected because the governance signal already exists without a packaging boundary. 0010 D34 settles `apiVersion` levels per catalog, so "this is stable API and that is churn" is expressible as `v1beta1` contracts alongside build-versioned adapters in one artifact.
- **Split for release cadence.** Rejected as already solved. 0010 D4's key split is precisely the mechanism: a contract key carries its own `apiVersion` and does not move on a catalog release, which is why two key schemes were invented in the first place.
- **One module, two subpackages (`…/contracts`, `…/adapters`).** Rejected as the worst of both: a CUE module is the release unit, so this buys no cadence decoupling, while still moving every contract FQN.

**Rationale:** With D1 in place, one catalog can already express "I define these contracts and implement only some of them" — which is the capability the split was wanted for. A third party defining its own contract publishes its own catalog carrying both halves, also without a split. The split therefore buys packaging hygiene and a modestly thinner dependency graph, at the cost of a system-wide FQN change and a new skew axis.

**Source:** User decision 2026-08-05 ("IMPORTANT QUESTION: Do we really need to split contract/adapter?" — answered no). CUE's fetch-per-module / evaluate-per-package behaviour and `catalog_opm`'s single-module layout (`src/{resources,traits,blueprints,transformers}/`) read 2026-08-05.

---

## Open Questions

- **OQ1: How is a duplicate transformer within one contract bucket resolved?** Status: open. Two transformers may both satisfy a component's predicate — the case that arises when `catalog_opm` and `catalog_opm_experimental` both ship a daemonset adapter, or when a more-specific adapter is meant to *replace* a less-specific one. Measured 2026-08-05: `compile/match.go:344-360` is subset containment, so a more-specific transformer supplements rather than displaces, and `:138-157` pairs both — two DaemonSets from one component, with no guard, because 0010 D32's check fires only for `fulfilment: "provider"` contracts. Three candidate shapes, and they are not equivalent: a **guard** (refuse comparable predicates in one bucket, diagnosable but forbids the topology), a **class** (mutual exclusion by label value, which is D2's mechanism applied one level down), or **refinement** (most-specific-predicate-wins, which is the only one that expresses "override" and the only one that puts ordering into a matcher that has deliberately had none since 0001). The author has flagged this as needing further investigation; it is scoped out of the design until it has one.
- **OQ2: Where does the default class get filled in?** Status: open. A component naming no class must still route somewhere, and the default is platform-published, so the fill cannot live in the module. It must happen after materialize (the vocabulary is there) and before match (the label must be on the component). Candidates: a kernel step between materialize and match; a unification against a platform-supplied default struct during finalize; or a matcher-side fallback that tries the classless key when no class label is present — the last being the only one that changes `match.go`, which D2 exists to avoid.
- **OQ3: How does a consumer reproduce a cluster's render when part of the registry lives in cluster state?** Status: open. **Blocking for `draft → accepted`.** 0010 D14 deleted subscription resolution so the platform file is a lockfile; D3 reintroduces resolution as accepted claims. Candidates: `Platform.status.registry` is exportable to a `#Platform` file and the CLI fetches it (`opm platform pull`); or accepted claims are written back into a git-tracked platform file by a controller, keeping the lockfile literal at the cost of a write-back loop; or the divergence is accepted and documented, with the CLI defaulting to a cluster query. Interacts with 0014, whose export path must produce a platform that reproduces the render it exported.
- **OQ4: Does transformer-predicate stability need a rule beside 0010 D27?** Status: open. D27's additive-only promise, and `#ContractCompatibility` with it, is a relation between two builds of one **primitive** at one `apiVersion`; a transformer is an adapter under 0010 D44, not a primitive. So a new catalog build may add a `requiredTraits` entry to an existing transformer, or add a whole new transformer to an existing bucket, without violating anything — and the second is OQ1's duplicate case arriving by upgrade. Additive-only makes *contract shapes* safe to float across builds; it does not make *transformer sets* safe to float. Whether that gap gets its own rule, and whether that rule is a publish gate (0011 D9's shape) or a materialize check, is unresolved.
- **OQ5: What is the migration path when a contract is promoted between catalogs?** Status: open. An experimental contract graduating from `catalog_opm_experimental` to `catalog_opm` changes both the path segment and the `apiVersion`, so the FQN moves — every consuming module changes an import and every provider adds a `requiredTraits` entry, in one flag day per contract. Under a design that expects a well-known contract set with an experimental on-ramp, this is a recurring cost rather than a one-off. There is no aliasing or supersession mechanism in 0010's keying. Possibly its own entry rather than a decision here.
- **OQ6: What is the blast radius of a registration change, and what does the store key become?** Status: open. `opm-operator/internal/platform/store.go` holds one materialized platform keyed on the Platform CR's `.metadata.generation`. Under D3 the key must cover the accepted-claim set as well, and every accepted or revoked claim invalidates it — which re-renders every ModuleInstance in the cluster, moving every render digest. Whether that is acceptable as-is, needs rate limiting, or needs the materialized platform to be diffable so unaffected instances can skip, is unmeasured.
- **OQ7: Where is a registration refused when the provider requires a build the platform does not run?** Status: open. Filed 2026-08-20 from 0019's OQ10, deferred here at that entry's OQ walk. Under 0019 D13 the platform's dependency list always wins every shared path of the render build, so a provider whose transformers were authored against a newer `core` (or any other shared dependency) than the platform runs would execute against the platform's bytes — or trip 0019 D5's derived-version tripwires at render time, where the failure names an unrelated module instance rather than the provider. The natural refusal site is D3's claim-and-accept gate, at registration time, so the failure names the provider. Deferred rather than decided there because the angles need in-depth discussion and testing rather than argument (user decision at the 0019 walk). The positions carried from that walk: the registry is contributed to by both a static Platform CR (likely only the base catalog) and a dynamic per-registration CR the operator renders and re-discovers, and provider catalogs are NOT dependent on the base catalog or on each other — a provider's transformers may import helpers from other catalogs without depending on their contracts — so the shared surface may be as narrow as `core`. Open angles: what "requires" even means for a provider catalog under that independence, what compatibility check the reconciler can run without paying a full build, whether acceptance re-runs when the Platform CR's catalog moves, and what happens to already-accepted registrations on a platform upgrade.
