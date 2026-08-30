# 0024: CUE Testing and Conformance

See [`config.yaml`](config.yaml) for metadata; it is the sole source.

## Summary

OPM's behaviour is mostly CUE evaluation, and today that behaviour is verified unevenly:

- The abstraction catalog carries 163 hidden assertions and types every rendered object against upstream Kubernetes definitions.
- The raw passthrough catalog carries none, and types against nothing.
- The core schema has no committed test at all.
- No repo can say whether a CUE toolchain or core release changed what an unchanged input produces.

This enhancement gives OPM two layers of verification: in-package assertions that live beside each definition (positive and negative, in pure CUE), and an external conformance suite. The suite replays fixtures across CUE, core, catalog and upstream Kubernetes versions, records rendered bytes and refusal text per version cell, and fails on drift no release explained.

## Documents

1. [01-problem.md](01-problem.md): CUE behaviour is verified by hand, unevenly, and never across versions
2. [02-design.md](02-design.md): Two layers: in-package assertions and an external, matrix-replayed conformance suite
3. [03-decisions.md](03-decisions.md): DN decision log
4. [04-graduation.md](04-graduation.md): Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md): Operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md): OQN Open Questions register

No `schemas/`: this entry changes no `opmodel.dev/core` definition (`core_schema: false`).

## Scope

### In scope

- The verification of CUE-evaluated artifacts: the core schema, both catalog families, and the module fleet's CUE, as observed through `cue` evaluation and the pure-CUE render oracle.
- In-package assertions for definitions: what a definition accepts, what it rejects, and what it derives.
- An external conformance suite: fixtures whose recorded outcome (rendered output, or the diagnostic of a refusal) is the contract, replayed across a version matrix.
- Conformance of rendered Kubernetes objects to the upstream `cue.dev/x/k8s.io` definitions, for both catalog families, and a mechanical account of which upstream API versions the raw family represents.
- The gate 0019 D15 relies on ("no default-named golden changes by a byte"), given an owner.

### Out of scope

- A testing strategy for the Go repos (`library`, `cli`, `opm-operator`): each has its own constitution and Go test suite; this entry consumes `library`'s pure-CUE oracle and does not restructure its tests.
- Cluster admission and runtime behaviour: a rendered object that is well-typed can still be rejected by an admission webhook or fail at reconcile; that is `opm-kind-demo` territory.
- Replacing the parity harness in `library` (0019): the harness compares the kernel against the oracle; this suite compares versions of the oracle's inputs and outputs against each other.
- Go-level assertions on CUE evaluator internals (the `cueregression` canary stays in `library`).

## Delivery Log

Delivery is recorded in this entry's `delivery.yaml` once changes land; nothing is forecast here.

## Diagrams

ASCII diagrams in `01-problem.md` and `02-design.md` show the current verification coverage and the two-layer shape.

## Deviations from Design

None at this stage.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `enhancements/0019` | Pure-CUE unification is the render oracle (D1); the D15 sweep's byte-identity gate and the D16 default flip are the first consumers of this suite |
| `enhancements/0021` | Versioning policy: what a release may change; this entry is how a release's actual change is observed |
| `core/CLAUDE.md`, `core/openspec/config.yaml` | The schema repo's rules: pure CUE, no Go, SPEC.md co-update |
| `catalog_opm/CLAUDE.md` | Two families; the raw family depends on `core` alone; contract `apiVersion` mirrors upstream at adoption (0010 D48) |
| `library/testdata/parity/oracle/render.cue` | The pure-CUE renderer the suite's render cases use |
| `library/opm/internal/cueregression/closedness_test.go` | A hand-built instance of cross-version drift detection, the shape this entry generalises |
| https://registry.cue.works/source/cue.dev/x/k8s.io@v0.7.0 | Upstream Kubernetes CUE definitions the catalog outputs are checked against |
