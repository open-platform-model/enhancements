# Design Decisions: CUE Testing and Conformance

Decisions are numbered sequentially and recorded as they are made; numbers are permanent. While this entry is `draft`, decisions are revised in place; from `accepted`, changes land as new decisions with `**Amends:**` / `**Supersedes:**` fields. Every decision carries `**Kind:**` and passes the admission test: would it still bind a from-scratch rewrite of the affected repos? Mechanism (file layout, runner choice, verb names) belongs to the implementing changes and is recorded here only as evidence under Research.

## Research

### CUE's own test conventions (measured 2026-08-25 against cuelang.org/go v0.17.1 sources)

- **testscript txtar** (`cmd/cue/cmd/testdata/script/`, 422 files): one text archive per case, a leading script (`exec` / `! exec`, `cmp`, `cmpenv`, `stdout` / `stderr` regex, `env`, `[cond] cmd`) and the case's files under `-- name --` headers; a fresh temp directory per case; an update flag that rewrites goldens in place. `vet_concrete.txtar` is a must-fail case whose `expect-stderr` includes the diagnostic's position lines. CUE adds custom verbs and sets `RequireExplicitExec`.
- **cuetxtar** (`cue/testdata/eval/*.txtar`): no script; one input plus named `out/<evaluator>` sections, several evaluator versions recorded side by side in one file, header directives for per-case steering. Internal to CUE's Go module and therefore unusable across CUE *binary* versions, but its per-version recording is the shape this entry's per-cell records take.
- Multiple `cuelang.org/go` versions cannot coexist in one Go module; a CUE version axis is a binary axis.

### Negative assertions in pure CUE (measured 2026-08-25, cue v0.17.1)

- `_rejects: [if (#Def & value) != _|_ {"accepted"}]` with `_rejects: []` yields no error when `value` is rejected and `incompatible list lengths (0 and 1)` when it is accepted. A control case through the same idiom fails, proving the idiom is live.
- An *incomplete* value also satisfies the guard, so "rejected" and "unresolved" are indistinguishable in-language; both fail concrete evaluation.
- An assertion on a value that references an unresolved disjunction (`_ok: metadata.resourceName & #NameType` where `resourceName` is `*default | #NameType`) is inert: it unifies the disjunction, not the chosen branch. A comparison (`==`) forces resolution. Evidence attached to 0019 D16's chosen spelling.
- A failed disjunct's error is discarded with the disjunct; the diagnostic of a validated default is the surviving constraint, never the string. The `try` experiment (v0.16.0 preview) intercepts only optional-reference misses, not validation errors (measured: the `else` never runs).

### The catalog families and upstream definitions (measured 2026-08-25)

- `catalog_opm/opm` depends on `cue.dev/x/k8s.io@v0` v0.10.0 (`default: true`), re-exports its groups under `schemas/kubernetes/`, unifies every transformer `output:` with the upstream definition, and carries 163 `_test*` hidden assertions.
- `catalog_opm/k8s` depends on `core` alone by rule, types inputs as open wrappers, outputs against nothing, and carries no assertion.
- `cue.dev/x/k8s.io` v0.7.0 and v0.10.0 differ in one group version (`scheduling/v1alpha1` → `v1alpha2`); the module records no Kubernetes release number anywhere found. The Central Registry lists `v0.0.0`, `v0.3.0` through `v0.8.0`, and `v0.10.0`.

---

## Decisions

### D1: CUE behaviour is verified at two layers, and the conformance layer lives outside every product repo

**Kind:** scope

**Decision:** OPM's CUE artifacts are verified at two layers with distinct questions. The in-package layer answers "does this definition accept, reject and derive what it claims" and lives beside the definition in the owning repo, run by that repo's own checks. The conformance layer answers "does an unchanged input still produce the same bytes and the same refusal text across versions" and lives outside every product repo, consuming only published artifacts and `cue` binaries. Neither layer replaces the other, and neither replaces `library`'s Go harnesses.

**Alternatives considered:**

- **One layer, in-package only.** Rejected: a `cue.mod` pins exactly one core, one catalog and one `k8s.io`, so a package cannot compare versions of itself, and an in-package file cannot capture a diagnostic's text at all.
- **One layer, external only.** Rejected: rejection and derivation assertions belong next to the definition they describe, where a schema contributor edits them in the same commit as the constraint; an external suite would lag every schema change by a release.
- **The conformance suite inside `library`**, which already has a Go harness and the oracle. Rejected: the suite pins published `core` and catalog builds and must not depend on a checkout of either; `library`'s tests are the kernel's, and the suite's first consumers (0019 D15's gate, catalog releases) are not kernel concerns.

**Rationale:** The two questions have different owners, cadences and toolchains. A schema contributor needs the in-package answer at `task check`; a release maintainer needs the cross-version answer per release. Putting both in one place serves neither.

**Source:** User decision 2026-08-25: "I don't want to mix it up in the core schemas, but outside."

### D2: A refusal's diagnostic text is part of the recorded behaviour

**Kind:** contract

**Decision:** A conformance case's expected outcome is captured verbatim: for an accepted input, the rendered output bytes; for a refused input, the diagnostic's message lines. Refusal text is compared, not only the fact of refusal. A change in a diagnostic between version cells is drift and is treated the same as a change in rendered bytes.

**Alternatives considered:**

- **Assert only exit status for refusals.** Rejected: 0019 D16 chose its spelling for the diagnostic's content (the offending string named, not a bare constraint); an exit-status assertion cannot tell the two apart, and the entire reason that choice was measured would go unrecorded.
- **Assert a regex fragment per refusal.** Not rejected as a form, but not the contract: the record is the full message lines, and a case may additionally declare the fragment it cares about. What the suite guards is that nothing changed unexplained.

**Rationale:** Diagnostics are what an author reads. The measurements in Research show the same input producing two different refusals under two spellings on the same toolchain; only text comparison makes that difference an observable behaviour rather than a footnote.

**Source:** User decision 2026-08-25: "validating that the output we get is as expected, even the failures, like the name that is too long."

### D3: Outcomes are recorded per version cell, and drift fails unless a release explains it

**Kind:** policy

**Decision:** The conformance record is keyed by version cell: the CUE toolchain version, the `opmodel.dev/core` version, the catalog version(s), and the `cue.dev/x/k8s.io` version. A cell's recorded outcome is expected to be reproducible for as long as those artifacts exist. When a new cell's outcome differs from its predecessor along one axis, the suite fails unless the difference is recorded as intentional. Recording a new cell is a reviewed act, and its diff is the human-readable account of what that version changed. Versions on every axis are published artifacts (GHCR for OPM, the Central Registry for `k8s.io`, released `cue` binaries), never checkouts.

**Alternatives considered:**

- **One golden per case, updated in place on every release.** Rejected: it erases the history that makes the suite useful and cannot distinguish "changed on purpose" from "changed".
- **Per-cell records only for cases that differ, one default otherwise.** Not rejected; this is a storage choice for the implementing change. The policy is that every cell has a determinable expected outcome.
- **Checkouts on the OPM axes (test `main` before it is released).** Rejected as the default: the suite's claim is about what consumers can pin. A pre-release run against a branch-published `-dev.*` tag is the same mechanism with a different version and needs no exception.

**Rationale:** Cross-version reproducibility is the requested capability, and it is only meaningful if each version's behaviour is a durable record rather than a moving target. Failing on unexplained drift is what turns the record into a gate; requiring the explanation in a reviewed diff is what keeps intentional change cheap.

**Source:** User decision 2026-08-25: "reproduce this across versions of OPM and CUE to make sure it still outputs the same stuff as before."

### D4: Rendered Kubernetes objects conform to upstream definitions, verified outside the catalog

**Kind:** contract

**Decision:** Every object a catalog transformer renders satisfies the `cue.dev/x/k8s.io` definition selected by the object's own `apiVersion` and `kind`, for both catalog families. For the raw passthrough family this conformance is verified by the conformance suite, which imports the upstream definitions; the raw module itself keeps its core-only dependency. Every raw member's `(group, version, kind)` exists in the upstream snapshot the suite pins. The abstraction family's in-module unification with upstream definitions remains its in-package layer and is additionally exercised by the suite.

**Alternatives considered:**

- **Give the raw family the `k8s.io` dependency and type its outputs in-module.** Rejected: the core-only rule is deliberate in `catalog_opm/CLAUDE.md` (the raw family's wrappers are hand-written and dependency-free), and the suite can check conformance without changing that.
- **Type the raw family's open wrappers against upstream instead of its outputs.** Rejected as insufficient: the wrappers are inputs, and a passthrough's promise is about what comes out; input typing is a later, separate choice for the catalog.
- **Treat conformance as the abstraction family's concern only.** Rejected: the raw family is the one whose entire promise is upstream fidelity and the one with no check.

**Rationale:** "Native Kubernetes APIs passed through as-is" is a claim about upstream conformance; the upstream CUE definitions exist, are versioned, and are already consumed by the sibling module. Checking outside the module honours both the claim and the dependency rule.

**Source:** User decision 2026-08-25: "use the upstream k8s CUE manifests as the way to ensure we are conformant."

### D5: The conformance suite renders through the pure-CUE oracle

**Kind:** scope

**Decision:** Render cases in the conformance suite are rendered by pure-CUE unification, using the oracle 0019 D1 names as the render contract. The kernel is not required to run the suite. Whether the kernel's render also joins the version matrix is an open question (OQ1) and, if adopted, is an additional axis rather than a replacement.

**Alternatives considered:**

- **Render through the `opm` CLI.** Rejected as the baseline: it would put `library` and `cli` versions on the axis of a suite whose subject is the CUE artifacts, and the parity harness already proves the kernel agrees with the oracle.
- **Both from the start.** Deferred to OQ1: valuable for catching kernel-side drift in the same corpus, but it doubles the matrix before the corpus exists.

**Rationale:** Under 0019 D1 the pure-CUE result is the definition of correct; a suite that renders with only `cue` binaries has the fewest moving parts and can run against any historical cell.

**Source:** Design discussion 2026-08-25; 0019 D1.

### D6: In-package assertions state rejection as well as acceptance

**Kind:** policy

**Decision:** The in-package layer asserts what a definition rejects, in pure CUE, beside the assertions of what it accepts and derives. A negative assertion is paired with a positive one on the same idiom so that an inert assertion is detectable. The in-package layer does not assert diagnostic text; that is the conformance layer's (D2).

**Alternatives considered:**

- **Positive assertions only, negatives in the suite.** Rejected: a constraint and the case it exists to refuse belong in the same commit, under the same `SPEC.md` co-update; the suite lags by a release.
- **Negatives as commented-out cases with the observed error** (the `examples.cue` convention). Rejected: a comment cannot fail.

**Rationale:** Research shows the idiom is expressible and that inert assertions are a real failure mode (the disjunction case); pairing is the cheapest guard against it.

**Source:** Measurement 2026-08-25 (Research above); design discussion 2026-08-25.

Open Questions live in [`07-questions.md`](07-questions.md).
