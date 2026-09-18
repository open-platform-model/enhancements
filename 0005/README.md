# Enhancement 0005: Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

OPM ships two catalogs, meaning published libraries of building blocks a module draws on: an opinionated one whose blueprints hide Kubernetes detail, and a raw mirror whose transformers pass native objects through unchanged. Both hand-maintain their own copy of the Kubernetes type schemas, and the two copies drift. This entry makes the Kubernetes OpenAPI the one source both are generated from, in two renderings: closed types for the opinionated catalog and open ones for the mirror. The generator also stamps each kind with the lifecycle facts the operator needs to order, wait on and prune it.

All entries: [INDEX.md](../INDEX.md). How this one relates to others: [GRAPH.md](../GRAPH.md). Metadata: [config.yaml](config.yaml).

## Summary

- The Kubernetes OpenAPI is the single source of Kubernetes type truth, and both catalogs consume generated output instead of schemas they keep themselves (D1). Pointing the same generator at a bundle of custom resource definitions, cert-manager's for example, emits a typed catalog for that operator, so the long tail no longer needs hand-written transformers.
- One source, two projections. The strict one closes the types and backs the opinionated catalog's constructing transformers, which build an object from a small authored surface. The open one leaves the leaves open, so the mirror's pass-through transformers accept any valid native field. Being backed by the complete generated type is also what gives an abstraction its trapdoor: an explicit way to override a native field the sugar does not expose.
- Each generated kind carries lifecycle metadata: namespaced or cluster-scoped, which apply phase it belongs in, how to tell it is ready, and how it is owned and pruned. That turns today's hardcoded apply-order list into per-kind data the operator reads.
- Composition, meaning one catalog projecting its own abstractions onto another's resources in pure CUE, is a supported capability and never a mandate (D2). The two base catalogs share the generated types and keep their own transformers; composition is for provider golden-path catalogs layered on top.
- Nothing in core changes (D3). The transformation model stays single-pass, and multi-phase lowering, where a transformer's output re-enters matching, becomes a separate core entry only once a concrete case shows that pure-CUE projection cannot express it.

## How it works

```mermaid
flowchart LR
    k8sapi["Kubernetes OpenAPI for one minor"] --> gen
    crds["CRD bundle, e.g. cert-manager"] --> gen
    gen["Generator"] --> strict["Strict projection: closed types"]
    gen --> loose["Open projection: leaves left open"]
    gen --> meta["Lifecycle metadata per kind: scope, apply order, readiness, prune policy"]
    strict --> abstractions["Opinionated abstractions, with an override trapdoor down to any native field"]
    loose --> mirror["Raw mirror: typed resource plus pass-through transformer per kind"]
    meta --> reconcile["Operator reconcile: ordering, readiness, pruning"]
    abstractions --> golden["Third-party golden-path catalog composed on top"]
    mirror --> golden
```

A pass-through transformer is uniform across kinds, which is what makes the mirror generatable rather than hand-authored: only the group, version, kind and scope differ. Readiness is the one piece the OpenAPI does not carry, because it encodes status conventions, so it is curated per kind with a generic fallback. The rightmost node is the point: a provider layers a golden path on either catalog without changing either.

## Documents

1. [01-problem.md](01-problem.md): two catalogs encoding Kubernetes from divergent hand-maintained sources that drift and do not scale
1. [02-design.md](02-design.md): the generator, the two projections, the lifecycle stamp, and optional composition
1. [03-decisions.md](03-decisions.md): the decision log, D1 to D3
1. [04-graduation.md](04-graduation.md): what must hold before `draft` becomes `accepted`
1. [05-risks.md](05-risks.md): risks, drawbacks, alternatives not taken
1. [06-operational.md](06-operational.md): rollout, versioning, rollback, cross-repo ordering
1. [07-questions.md](07-questions.md): the open-questions register, OQ1 to OQ6

The entry carries [`contracts/`](contracts/): compilable CUE sketching the generation manifest, the lifecycle metadata block and the override field.

## Scope

### In scope

- Generation tooling that ingests the Kubernetes OpenAPI and CRD schemas and emits CUE types, resources, pass-through transformers, catalog manifests and lifecycle metadata.
- Two projections from the one source: strict for the opinionated catalog, open for the mirror.
- Regenerating the mirror catalog as generated output; re-pointing the opinionated catalog at the shared strict types and adding the trapdoor.
- Per-resource lifecycle metadata, plus the library and operator changes that consume it.
- Documentation of the generation workflow and of the provider golden-path composition pattern.

### Out of scope

- Any change to core (D3, which keeps the transformation model single-pass).
- Multi-phase lowering, where transformer outputs re-enter matching. It is staged as a separate evidence-gated core entry, and OQ6 asks what case would trigger it.
- Non-Kubernetes platforms: Nomad, Docker Compose, Swarm.
- A runtime reconcile engine. This entry produces the lifecycle metadata; consuming it is operator work.

## Deviations from Design

None at this stage. Update this section when implementation lands and any deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `catalog_kubernetes/CLAUDE.md` | The pass-through mirror, which becomes the open projection's generation target |
| `catalog_opm/CLAUDE.md` | The opinionated catalog, which consumes the strict projection and hosts the trapdoor |
| `catalog_opm/src/blueprints/workload/stateless_workload.cue` | The existing pure-CUE projection that composition builds on |
| `catalog_kubernetes/src/transformers/deployment_transformer.cue` | The pass-through transformer shape the generator templates |
| `core/src/transformer.cue` | The transformer contract, unchanged here, kept friendly to typed outputs later |
| `library/` (`pkg/resourceorder`) | Today's hardcoded apply order, to be generalized onto the generated metadata |
| `opm-operator/CLAUDE.md` | The reconcile loop that consumes the generated lifecycle metadata |
