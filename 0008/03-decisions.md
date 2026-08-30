# Design Decisions: CUE-Native CRD Schemas as Single Source of Truth

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made; numbers are permanent, never reused or renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass. The merged decision keeps the lower number; the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives
considered, Rationale, Source. The Source field is specific: `"User
decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a
choice never gets lost.

---

## Decisions

### D1: CUE in `core/` is the single source of truth; Go types and CRD YAML are generated

**Kind:** contract

**Decision:** The `ModuleInstance`, `ModulePackage`, and `Platform` type definitions are authored once in CUE in `core/`. The operator's `api/v1alpha1` Go structs and the `config/crd/bases/*.yaml` manifests become generated artefacts derived from that CUE.

**Alternatives considered:**

- **Go stays source of truth, CUE derived** (via `cue get go` / `cue get crd`). Rejected: formalises the inversion the problem statement names: `core/` would become a *derived* artefact of `opm-operator/`, contradicting its role as the published upstream contract. (Examined as an alternative in `05-risks.md`.)
- **CRD YAML as the pivot**, with both Go and CUE derived from it. Rejected: there is no first-class CRD→Go path, so the Go types would be orphaned; awkward and tool-poor (`research/findings.md` §7).

**Rationale:** `/CLAUDE.md` already designates `core/` as "the source of truth every downstream consumes," and `core/SPEC.md` already constrains `spec` surfaces to OpenAPIv3 specifically so they can be projected to non-CUE consumers. Direction A makes the running system match the stated model.

**Source:** User decision 2026-06-25 (direction selected after research synthesis); `research/findings.md` §7.

### D2: Generation runs downstream over the *published* `core`; `core/` stays pure CUE

**Kind:** policy

**Decision:** The generator is a Go tool in `opm-operator` (`cmd/crdgen/`) that imports `opmodel.dev/core` as a published module dependency. `core/` itself gains no Go and no build-time codegen.

**Alternatives considered:**

- **Codegen inside `core/`.** Rejected: `core/CLAUDE.md` mandates a pure-CUE module with no Go; adding a generator there violates the constitution and the release-please publish model.
- **A standalone shared codegen repo.** Deferred, not rejected; see OQ1. Starting in `opm-operator` keeps the first consumer and the generator co-located.

**Rationale:** Consuming the published OCI artefact (the same one the kernel loads) guarantees the generated types match what the runtime evaluates, and keeps `core/`'s purity and publish workflow intact.

**Source:** User decision 2026-06-25; `core/CLAUDE.md` (pure-CUE rule); `research/findings.md` §7.

### D3: The CRD schema body is emitted via CUE's `encoding/openapi` in structural mode

**Kind:** policy

**Decision:** Generate each version's `openAPIV3Schema` with `cuelang.org/go/encoding/openapi` using `Config{ExpandReferences: true}`, which produces the structural-OpenAPI form Kubernetes CRDs require.

**Alternatives considered:**

- **`encoding/jsonschema.Generate`.** Rejected: it currently emits only JSON Schema Draft 2020-12 (runtime-enforced) and the Kubernetes versions are decode-only: wrong output dialect for a CRD body (`research/findings.md` §1, §5).
- **Hand-written schema bodies.** Rejected: defeats the single-source-of-truth goal.

**Rationale:** The openapi encoder ships `crd.go` ("functionality for structural schema, a subset of OpenAPI used for CRDs") and `ExpandReferences` is documented as enabling exactly the structural form CRDs need (verified against the installed v0.17.0-alpha.1 source).

**Source:** `research/findings.md` §1; `cuelang.org/docs/concept/how-cue-works-with-openapi/`; `encoding/openapi/crd.go` @v0.17.0-alpha.1.

### D4: Non-schema CRD facets are modelled as CUE data, not Go markers

**Kind:** contract

**Decision:** Scope, short names, status subresource, printer columns, and CEL validations are expressed as fields on the `#CRD` / `#CRDVersion` value in CUE, and spliced into the assembled CRD manifest by `cmd/crdgen`. They are no longer authored as kubebuilder marker comments.

**Alternatives considered:**

- **Keep these as kubebuilder markers on the generated Go.** Rejected: markers on generated code are clobbered on regeneration, and it would split the CRD definition across CUE (schema) and Go comments (everything else), the exact two-places problem this enhancement removes.
- **A separate non-CUE overlay file (YAML) merged at assembly.** Rejected: re-introduces a second authored artefact; CUE already models these cleanly as data.

**Rationale:** The openapi encoder emits only the schema body; everything above it (the CRD wrapper and vendor facets) is plain data and belongs with the schema in one CUE value (`research/findings.md` §1, §6).

**Source:** `research/findings.md` §1, §6; `book.kubebuilder.io/reference/controller-gen.html`.

### D5: deepcopy stays controller-gen's job, run over the generated Go

**Kind:** policy

**Decision:** `cmd/crdgen` emits the Go API structs (with json tags and `+kubebuilder:object:root=true` on root types); controller-gen `object` then generates `zz_generated.deepcopy.go` from those structs, unchanged from today.

**Alternatives considered:**

- **Generate deepcopy from CUE too.** Rejected: deepcopy/`runtime.Object` is produced only by controller-gen/deepcopy-gen, which consume Go source: there is no CUE input path (`research/findings.md` §3). Writing a deepcopy generator is disproportionate scope.

**Rationale:** Reuse the battle-tested tool for the one artefact CUE provably cannot produce; keep the kubebuilder/controller-runtime contract intact.

**Source:** `research/findings.md` §3; `sigs.k8s.io/controller-tools/pkg/deepcopy`.

### D6: CEL `x-kubernetes-validations` rules are carried verbatim, never translated

**Kind:** policy

**Decision:** CEL rules (today: the `Platform` `self.metadata.name == 'cluster'` singleton rule) are stored as opaque strings in `#CELValidation.rule` and injected as-is into the assembled CRD. No CEL↔CUE translation is attempted in either direction.

**Alternatives considered:**

- **Derive CEL from CUE constraints.** Rejected: the CUE maintainers call CEL↔CUE "a big lift," and CEL's `oldSelf` transition rules are unrepresentable in stateless CUE (`research/findings.md` §4).

**Rationale:** Verbatim passthrough is lossless and zero-risk; translation is unbounded work with correctness hazards.

**Source:** `research/findings.md` §4; cue-lang/cue#2691.

### D7: Drift is blocked by a regenerate-and-diff CI gate

**Kind:** policy

**Decision:** A `crdgen:check` CI step regenerates the CRD YAML and Go types from `core` and fails the build if the result differs from the committed artefacts. Regeneration is also a local `task` target.

**Alternatives considered:**

- **Trust review to keep artefacts current.** Rejected: that is the status-quo failure mode (unenforced, cross-repo).
- **Generate at build time, never commit.** Deferred (see OQ3); committing keeps the diff reviewable and the repo buildable without the generator on every path.

**Rationale:** The whole value proposition is that drift becomes impossible to merge, not merely discouraged.

**Source:** User decision 2026-06-25; `01-problem.md` (unenforced-drift pain).

### D8: `gengotypes` is an optional implementation detail, not a load-bearing dependency

**Kind:** policy

**Decision:** `cmd/crdgen` owns Go-struct emission. It may shell out to `cue exp gengotypes` or use a small in-tree emitter via the CUE Go API; either way the project does not depend on `gengotypes` being stable or on its exact output.

**Alternatives considered:**

- **Depend directly on `cue exp gengotypes` as the Go generator.** Rejected as the *sole* mechanism: it is experimental ("may be changed or removed at any time") and collapses disjunctions to `any`, losing enum/union typing in the Go struct (`research/findings.md` §2).

**Rationale:** Keeping emission behind our own tool boundary insulates the pipeline from an experimental upstream command and lets us control the disjunction handling (e.g. emit a named string type with an enum-validated CRD field).

**Source:** `research/findings.md` §2; `cue help exp gengotypes` (v0.17.0-alpha.3).

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
