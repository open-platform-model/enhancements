# Problem Statement: Catalog Contracts and Transformer Registration

Enhancement 0010 made it possible for a contract declared in one catalog to be fulfilled by a transformer in another, on independent release cadences (D4), and named that shape the supported path rather than an edge of it (D37). This entry is about the things that shape needs and does not have. Two are in scope: somewhere for the contract to *live* when nobody implements it, and a way for a provider's runtime installation and its transformer registration to be one act instead of two. The third (a way for two providers to coexist) was in scope until 2026-08-20 and is now deferred to a successor entry: D2 (as revised) keeps 0010 D37's one-provider rule, and Gap 3 below stands as the record of the deferred problem.

## Current State

**A catalog publishes adapters. It does not publish contracts.**

`core/src/catalog.cue` gives `#Catalog` exactly one member map:

```
#transformers: [#FQNType]: #ComponentTransformer & {...}
```

Its own doc comment records the consequence: *"Resources / Traits / Blueprints are surfaced transitively via each transformer's required/optional maps. Adding sibling maps (#resources, #traits, #blueprints) is an additive extension if introspection demand surfaces later."*

Everything downstream reads exactly that. Measured 2026-08-05 against the pre-0019 kernel: `library/opm/materialize/index.go:39-41` looked up `#transformers` on each pulled catalog build and `continue`d past any build that had none, and `:80-96` built the `#matchers` reverse index from the `required ∪ optional` maps of those transformers.

Enhancement 0019 (accepted 2026-08-20) deletes that machinery:

- The platform embeds each subscribed catalog whole in its registry entry (0019 D5).
- `#matchers` leaves `#Platform` (0019 D17).
- The render build's match glue derives its own buckets from the composed transformer map (0019 D10).

But the gap survives the deletion intact: the buckets still derive from transformers' `required ∪ optional` maps, and a catalog value still has no member map a contract could sit in. A primitive reaches a build only by being demanded by an adapter, before 0019 and after it.

**A platform's registry is a static, cluster-scoped list.** `opm-operator/api/v1alpha1/platform_types.go:29-41` projects the registry as `map[string]Subscription`, and under 0019 D6 the operator encodes those coordinates into a generated `#Platform` CUE package whose entries import the named catalogs (0019 D5). The `internal/platform/store.go` slot that held one `*MaterializedPlatform` keyed on the CR's `.metadata.generation` is deleted by 0019 D8. Nothing built is shared between renders, so the CR and the package generated from it are the whole of the registry state. Every catalog a cluster can render against is still named in one file, edited by one team.

**Matching is subset containment, and the match set is a union.** Measured 2026-08-05 at `compile/match.go:344-360`, and carried verbatim into the render build's CUE match glue that replaces it (0019 D10's gate is reproducing the kernel's exact pair set):

```go
missingMapLabels(requiredLabels, compLabels)   // required ⊆ component
fqnSubset(requiredResources, compResources)    // required ⊆ component
fqnSubset(requiredTraits,    compTraits)       // required ⊆ component
```

`:138-157` then paired *every* candidate in a bucket that unifies and satisfies that predicate, keying `matched` by transformer FQN, and the glue's comprehensions do the same. There is no arbitration, no ordering, and no notion of one transformer being more specific than another. The discriminator that keeps `catalog_opm`'s 8 `#ContainerResource` consumers from all firing at once is `requiredLabels` (`src/transformers/daemonset_transformer.cue:27-29` carries `{"core.opmodel.dev/workload-type": "daemon"}`), not the resource or trait set.

## Gap / Pain

**Gap 1: a contract with no adapter is unrepresentable in a published catalog.** 0010 D37 introduces `fulfilment: "provider"`: a contract the declaring catalog deliberately ships no transformer for. Under today's `#Catalog` that contract is importable from the CUE module by an author who knows its path, but it is absent from *every value derived from the catalog* (the composed transformer map, the match buckets) because every derivation walks `#transformers`. Two different facts collapse into one: "this catalog **defines** contract X" and "this catalog **implements** contract X" are indistinguishable, and the provider-fulfilled case is exactly where they diverge.

The immediate cost is that D37's own guard cannot see its own zero case. The guard counts transformers *requiring* a provider-fulfilled contract, and it can enumerate only contracts reachable from adapters. Two providers is detectable. One is fine. **Zero means the contract was never indexed**, so the platform cannot distinguish "this platform is missing a provider" from "this key exists nowhere". The failure surfaces later, per-instance, at render, once somebody deploys a module that uses it.

**Gap 2: a provider's install and its registration are two edits in two places.** Making k8up usable on a cluster today is: deploy the k8up module, and separately edit the cluster-singleton Platform CR to subscribe to the k8up catalog. Nothing binds them. Forget the second and every module demanding `backup` fails to render with a diagnostic that does not mention the subscription. Forget the first and the transformer renders Backup CRs against CRDs that do not exist. The two facts (*the k8up operator is installed* and *k8up's transformers are registered*) are one fact in the world and two in OPM.

**Gap 3: exactly one provider per contract is too strict, and the mechanism that would relax it does not exist.** *(Descoped 2026-08-20: D2, as revised, keeps the rule and defers routing to a successor entry; the gap stands as a record.)* 0010 D32/D37 refuse a second provider at platform assembly. That is one backup engine per cluster: restic-for-PVCs (k8up) and namespace-snapshot backup (Velero) cannot coexist, and switching is a big-bang subscription replacement rather than a per-workload migration. D32 records this as deliberate and provisional: *"arbitration is a design question with no real instance to design against… when the first genuine overlap arrives its shape is what an override gets designed against."*

## Concrete Example

A platform team wants `#Backup` as a well-known trait: modules declare that a volume needs backing up, and the cluster decides how. Two engines are in use: k8up for media PVCs, Velero for namespace-scoped snapshots of the database tier.

```
  catalog_opm                     catalog_k8up                catalog_velero
  ───────────                     ────────────                ──────────────
  traits/backup@v1beta1           imports the contract        imports the contract
    fulfilment: "provider"        transformers/k8up@1.2.0     transformers/velero@2.0.1
    NO adapter                      requiredTraits: backup      requiredTraits: backup

           │                                │                          │
           │  never reaches the match       │  reaches it              │  reaches it
           │  buckets (they derive from     │                          │
           │  #transformers' demands only)  ▼                          ▼
           │                        ┌───────────────────────────────────────┐
           └───────────────────────▶│ buckets.traits[".../backup@v1beta1"]  │
                 invisible          │   [ k8up@1.2.0, velero@2.0.1 ]        │
                                    └───────────────────────────────────────┘
                                                     │
                             0010 D37: two providers ─▶ the platform REFUSES
```

Three failures in one picture. The contract itself never reaches the buckets, so a platform subscribed to `catalog_opm` alone gets no signal that `backup` is unfulfilled until a module trips over it. Subscribe to one provider and it works. Subscribe to both (the actual requirement) and the platform refuses, so the platform team's real topology is unexpressible.

And a fourth, which is the same picture with `fulfilment: "catalog"`: two transformers that both satisfy a component's predicate both pair and both render, with no guard at all, because D32's check keys on the contract's declared fulfilment.

## User Stories

- As a **platform team operator**, I want to install k8up and have its transformers become available in the same act, so that a working provider and a registered provider cannot drift apart. Today: two edits in two places, and forgetting either produces a failure whose diagnostic does not name the missing half.
- As a **platform team operator**, I want two backup engines on one cluster with workloads routed to the right one, so that a migration is per-workload rather than cluster-wide. Today: 0010 D32/D37 refuse the second provider at platform assembly. *(Descoped 2026-08-20 to a successor entry, D2, as revised.)*
- As a **catalog author**, I want to declare a contract I deliberately do not implement and have consumers see it as a published promise, so that "nobody provides this yet" is a platform-level answer rather than a render-time surprise. Today: `#Catalog` has no map to put it in, and the kernel's index cannot see it.

## Why Existing Workarounds Fail

**Ship a stub transformer so the contract reaches the match buckets.** This is the only way to publish a contract today, and it inverts the meaning of the artifact: an adapter that emits nothing is indistinguishable, to both the matcher and the reader, from an adapter that is broken. It also makes the contract permanently self-fulfilled: the stub *is* a provider, so D37's arity guard counts it, and the real provider added later is the second one and gets refused.

**Keep the Platform CR in sync by convention or by CI.** The drift is detectable by a linter that reads the Platform CR and the deployed ModulePackages, and that linter is worth having. It does not fix the ordering problem: a subscription is live from the moment it is written, while the CRDs its transformer renders against exist only once the provider is Ready. A convention cannot express "not yet".

**Pick one backup engine.** This is the current answer, and it holds right up until a cluster has two legitimate reasons to back up differently. At that point the choice is between running one engine badly and running the second outside OPM entirely, which forfeits the contract's whole purpose, since the module stops declaring `backup` and starts declaring a k8up resource.

**Disambiguate two providers by giving one a narrower predicate.** This does not work in the direction it needs to, and the reason is the subset rung. Adding a required trait to the Velero transformer excludes Velero from components that lack the trait; it does nothing to exclude k8up from components that have it, because k8up's predicate is a *subset* of what the component declares and subset containment is satisfied. Predicates are monotone: specificity can be added, never subtracted. A more-specific transformer supplements a less-specific one instead of displacing it.
