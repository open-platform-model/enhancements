# Problem Statement — Catalog Contracts, Provider Classes, and Transformer Registration

Enhancement 0010 made it possible for a contract declared in one catalog to be fulfilled by a transformer in another, on independent release cadences (D4), and named that shape the supported path rather than an edge of it (D37). This entry is about the three things that shape needs and does not have: somewhere for the contract to *live* when nobody implements it, a way for two providers to coexist, and a way for a provider's runtime installation and its transformer registration to be one act instead of two.

## Current State

**A catalog publishes adapters. It does not publish contracts.**

`core/src/catalog.cue` gives `#Catalog` exactly one member map:

```
#transformers: [#FQNType]: #ComponentTransformer & {...}
```

Its own doc comment records the consequence: *"Resources / Traits / Blueprints are surfaced transitively via each transformer's required/optional maps. Adding sibling maps (#resources, #traits, #blueprints) is an additive extension if introspection demand surfaces later."*

The kernel reads exactly that. `library/opm/materialize/index.go:39-41` looks up `#transformers` on each pulled catalog build and `continue`s past any build that has none; `:80-96` builds the whole `#matchers` reverse index from the `required ∪ optional` maps of those transformers. A primitive reaches the materialized world only by being demanded by an adapter.

**A platform's registry is a static, cluster-scoped list.** `opm-operator/api/v1alpha1/platform_types.go:29-41` projects `#Platform.#registry` as `map[string]Subscription`, and `internal/platform/store.go` holds one `*MaterializedPlatform` in a single slot keyed on the Platform CR's `.metadata.generation`. Every catalog a cluster can render against is named in one file, edited by one team.

**Matching is subset containment, and the match set is a union.** `compile/match.go:344-360`:

```go
missingMapLabels(requiredLabels, compLabels)   // required ⊆ component
fqnSubset(requiredResources, compResources)    // required ⊆ component
fqnSubset(requiredTraits,    compTraits)       // required ⊆ component
```

`:138-157` then pairs *every* candidate in a bucket that unifies and satisfies that predicate, keying `matched` by transformer FQN. There is no arbitration, no ordering, and no notion of one transformer being more specific than another. The discriminator that keeps `catalog_opm`'s 8 `#ContainerResource` consumers from all firing at once is `requiredLabels` — `src/transformers/daemonset_transformer.cue:27-29` carries `{"core.opmodel.dev/workload-type": "daemon"}` — not the resource or trait set.

## Gap / Pain

**Gap 1 — a contract with no adapter is unrepresentable in a published catalog.** 0010 D37 introduces `fulfilment: "provider"`: a contract the declaring catalog deliberately ships no transformer for. Under today's `#Catalog` that contract is importable from the CUE module by an author who knows its path, but it is absent from the *catalog value the kernel materializes*. Two different facts collapse into one — "this catalog **defines** contract X" and "this catalog **implements** contract X" are indistinguishable, and the provider-fulfilled case is exactly where they diverge.

The immediate cost is that D37's own guard cannot see its own zero case. The guard counts transformers *requiring* a provider-fulfilled contract, and it can enumerate only contracts reachable from adapters. Two providers is detectable. One is fine. **Zero means the contract was never indexed**, so materialize cannot distinguish "this platform is missing a provider" from "this key exists nowhere" — and the failure surfaces later, per-instance, at render, once somebody deploys a module that uses it.

**Gap 2 — a provider's install and its registration are two edits in two places.** Making k8up usable on a cluster today is: deploy the k8up module, and separately edit the cluster-singleton Platform CR to subscribe to the k8up catalog. Nothing binds them. Forget the second and every module demanding `backup` fails to render with a diagnostic that does not mention the subscription. Forget the first and the transformer renders Backup CRs against CRDs that do not exist. The two facts — *the k8up operator is installed* and *k8up's transformers are registered* — are one fact in the world and two in OPM.

**Gap 3 — exactly one provider per contract is too strict, and the mechanism that would relax it does not exist.** 0010 D32/D37 refuse a second provider at materialize. That is one backup engine per cluster: restic-for-PVCs (k8up) and namespace-snapshot backup (Velero) cannot coexist, and switching is a big-bang subscription replacement rather than a per-workload migration. D32 records this as deliberate and provisional — *"arbitration is a design question with no real instance to design against… when the first genuine overlap arrives its shape is what an override gets designed against."*

## Concrete Example

A platform team wants `#Backup` as a well-known trait: modules declare that a volume needs backing up, and the cluster decides how. Two engines are in use — k8up for media PVCs, Velero for namespace-scoped snapshots of the database tier.

```
  catalog_opm                     catalog_k8up                catalog_velero
  ───────────                     ────────────                ──────────────
  traits/backup@v1beta1           imports the contract        imports the contract
    fulfilment: "provider"        transformers/k8up@1.2.0     transformers/velero@2.0.1
    NO adapter                      requiredTraits: backup      requiredTraits: backup

           │                                │                          │
           │  never reaches #matchers       │  reaches it              │  reaches it
           │  (index.go:39-41 walks         │                          │
           │   #transformers only)          ▼                          ▼
           │                        ┌───────────────────────────────────────┐
           └───────────────────────▶│ matchers.traits[".../backup@v1beta1"] │
                 invisible          │   [ k8up@1.2.0, velero@2.0.1 ]        │
                                    └───────────────────────────────────────┘
                                                     │
                              0010 D37: two providers ─▶ materialize REFUSES
```

Three failures in one picture. The contract itself never reaches the index, so a platform subscribed to `catalog_opm` alone gets no signal that `backup` is unfulfilled until a module trips over it. Subscribe to one provider and it works. Subscribe to both — the actual requirement — and materialize refuses, so the platform team's real topology is unexpressible.

And a fourth, which is the same picture with `fulfilment: "catalog"`: two transformers that both satisfy a component's predicate both pair and both render, with no guard at all, because D32's check keys on the contract's declared fulfilment.

## User Stories

- As a **platform team operator**, I want to install k8up and have its transformers become available in the same act, so that a working provider and a registered provider cannot drift apart. Today: two edits in two places, and forgetting either produces a failure whose diagnostic does not name the missing half.
- As a **platform team operator**, I want two backup engines on one cluster with workloads routed to the right one, so that a migration is per-workload rather than cluster-wide. Today: 0010 D32/D37 refuse the second provider at materialize.
- As a **catalog author**, I want to declare a contract I deliberately do not implement and have consumers see it as a published promise, so that "nobody provides this yet" is a platform-level answer rather than a render-time surprise. Today: `#Catalog` has no map to put it in, and the kernel's index cannot see it.

## Why Existing Workarounds Fail

**Ship a stub transformer so the contract reaches the index.** This is the only way to publish a contract today, and it inverts the meaning of the artifact: an adapter that emits nothing is indistinguishable, to both the matcher and the reader, from an adapter that is broken. It also makes the contract permanently self-fulfilled — the stub *is* a provider, so D37's arity guard counts it, and the real provider added later is the second one and gets refused.

**Keep the Platform CR in sync by convention or by CI.** The drift is detectable by a linter that reads the Platform CR and the deployed ModulePackages, and that linter is worth having. It does not fix the ordering problem: a subscription is live from the moment it is written, while the CRDs its transformer renders against exist only once the provider is Ready. A convention cannot express "not yet".

**Pick one backup engine.** This is the current answer and it holds right up until a cluster has two legitimate reasons to back up differently, at which point the choice is between running one engine badly and running the second outside OPM entirely — which forfeits the contract's whole purpose, since the module stops declaring `backup` and starts declaring a k8up resource.

**Disambiguate two providers by giving one a narrower predicate.** This does not work in the direction it needs to, and the reason is `fqnSubset`. Adding a required trait to the Velero transformer excludes Velero from components that lack the trait; it does nothing to exclude k8up from components that have it, because k8up's predicate is a *subset* of what the component declares and subset containment is satisfied. Predicates are monotone — specificity can be added, never subtracted — so a more-specific transformer supplements a less-specific one instead of displacing it.
