# Design — CUE Testing and Conformance

This document answers the question: "What is the proposed solution and how does it work?" Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- Every definition-level behaviour worth stating has an executable statement beside the definition: what it accepts, what it rejects, what it derives. Rejection is a first-class assertion, in pure CUE, with no Go.
- An unchanged input has a recorded outcome per version cell (CUE toolchain, core, catalog, upstream Kubernetes definitions), and that outcome includes the text of a refusal, not only the fact of one.
- A release of `cue`, `core` or a catalog that changes any recorded outcome is visible as a diff a reviewer reads, before a consumer or a cluster finds it.
- Rendered Kubernetes objects from both catalog families are checked against the upstream `cue.dev/x/k8s.io` definitions for their declared `apiVersion` and `kind`, without the raw family taking the dependency its rules forbid.
- The set of upstream API group versions the raw family represents, and the set it does not, is a mechanical report rather than a belief.
- The suite runs with nothing but `cue` binaries and published artifacts pulled from GHCR under the registry policy; no checkout of a product repo is a precondition.

## Non-Goals

- Testing the kernel's Go behaviour, the CLI, or the operator. The pure-CUE oracle is the renderer here; whether the kernel also joins the version axis is an open question, not a goal.
- Admission or runtime validity of rendered objects beyond upstream type conformance.
- A single golden per case across all versions. Behaviour legitimately changes between releases; the suite records per cell and objects to *unexplained* change.
- Migrating the abstraction family's existing in-module assertions anywhere; they are the in-package layer already.
- A general test framework for CUE. The suite is OPM's conformance record, built from CUE's own conventions (see Research in `03-decisions.md`), not a reusable product.

## High-Level Approach

Two layers, one question each.

```
 layer 1: in-package                          layer 2: conformance suite (external)
 ─────────────────────────────────────        ───────────────────────────────────────────────
 lives beside the definition                  lives outside every product repo
 runs at the toolchain the repo pins          runs at N cue × M core × K catalog × J k8s.io
 "does this definition do X"                  "does this input still produce these bytes,
   accepts / rejects / derives                   and this refusal text"
 asserts in CUE (hidden fields)               asserts by diffing captured output
 gate: the repo's own task check              gate: drift with no matching release change
 owner: each CUE repo                         owner: the suite; consumers: 0019, catalog releases
```

**Layer 1** is the retired v0 catalog's shape brought back with the missing half: test files beside the package, positive assertions pinning derived values, and negative assertions in pure CUE. The negative idiom was measured on cue v0.17.1: a comprehension guarded by `!= _|_` over the unification yields nothing when the value is rejected, and a control case (a valid value through the same idiom) fails, which proves the idiom is live. It distinguishes nothing about *why* a value was rejected; that is layer 2's job.

**Layer 2** is a corpus of cases. A case is one input (a module instance, a bare component, a platform plus instance for a render) with its expected outcome captured verbatim: the rendered output, or the diagnostic of the refusal. The corpus is replayed per version cell, and each cell's outcome is recorded. Two modes: *verify* (diff against the record, fail on difference) and *record* (write the outcome for a new cell, which a reviewer then reads in the diff). The pure-CUE oracle from `library/testdata/parity/oracle` renders the render cases, so the suite needs no kernel: under 0019 D1 that oracle is the contract.

```
 case ──▶ scratch module ──▶ cue (version c) ──▶ outcome ──▶ compare to record[c, core, catalog, k8s.io]
            deps pinned:                           bytes or
            core@M, catalog@K, k8s.io@J            diagnostic                 differs?
                                                                              ├─ release notes explain it → record, review
                                                                              └─ nothing explains it     → FAIL
```

**Catalog conformance** is three case kinds inside layer 2:

- **Output conforms to upstream.** Render a fixture through every transformer, then unify each output object with the upstream definition selected by the object's own `apiVersion` and `kind`. For the abstraction family this repeats what the module already does at vet time; for the raw family it is the first time the passthrough claim is checked, and it is done in the suite precisely so the raw module keeps its core-only dependency.
- **Coverage.** For every raw member, its `(group, version, kind)` exists in `k8s.io` at the pinned snapshot; a member for an API upstream removed is a defect. The inverse, upstream kinds with no member, is a report (whether it ever gates is an open question).
- **Upstream version axis.** The conformance cases replayed across `k8s.io` snapshots, so a field upstream drops or tightens appears as drift on exactly the transformer that emits it.

## Schema / API Surface

No `opmodel.dev/core` change. The suite's own conventions (case shape, record keying, verb set) are the suite's to decide with the code in front of it; the evidence for the candidate shapes is in `03-decisions.md` Research.

## Affected Surfaces

- **The conformance suite (new, location per OQ5).** Owns the corpus, the version matrix, the per-cell records, the `verify` and `record` modes, and the upstream-conformance and coverage checks. Consumes published `core`, catalog and `k8s.io` artifacts from GHCR and the CUE Central Registry, and `cue` binaries by version.
- **`core`.** Gains in-package assertions for its definitions, run by its existing check task; no published definition changes. What a published module contains (whether test files ship inside it) is OQ8.
- **`catalog_opm`.** The abstraction family keeps its in-module assertions. The raw family gains upstream conformance and coverage checks, run outside the module. A catalog release gains the byte-identity gate 0019 D15 names, run against the suite's record.
- **`library`.** Provides the pure-CUE oracle the suite renders with; nothing in the kernel changes. Its schematest fixtures remain the place where message-exact assertions against the *published* core live for the kernel's own purposes.
- **`enhancements`.** The `#Area` enum gains the suite's repo when it is created; `examples.cue`'s "commented-out must-fail" convention can adopt the layer-1 negative idiom.

## Before / After

Before: 0019 D16's seven behaviours are a table in a design document, verified once by hand; the raw family's conformance is a sentence in `CLAUDE.md`; a `cue` bump is tested by rendering the fleet and looking.

After: the seven behaviours are assertions in `core` and seven cases in the suite with their diagnostics recorded per cell; every raw member's output is unified with its upstream definition at each `k8s.io` snapshot in the matrix; a `cue` bump is a matrix column whose diff is empty or explained.
