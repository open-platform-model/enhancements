# Graduation Criteria — CUE-Native CRD Schemas as Single Source of Truth

This document records the gates that must hold before the enhancement
advances along the design lifecycle. The validator (future) checks the
gate items at each promotion. Treat these as design acceptance criteria,
not as implementation milestones — implementation progress lives in
`config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be implemented when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision recorded in `03-decisions.md` (D1..D8) is locked, and every Open Question is resolved (`resolved-by-D##`, `deferred-to-NNNN`, or `answered`) — in particular OQ2 (status ownership), OQ4 (`ModulePackage` domain anchor), and OQ5 (`core` semver impact), which gate whether the first slice is well-formed.
- `schemas/target.cue` compiles (`cue vet ./...` from the directory passes) and captures the `#CRD` / `#CRDVersion` / `#PrinterColumn` / `#CELValidation` surface plus at least one worked instance (`ModuleInstance` and `Platform`) end-to-end.
- A throwaway spike has demonstrated, against the real `opmodel.dev/core` and CUE v0.17, that `encoding/openapi` with `ExpandReferences` produces a structural schema the API server accepts for at least one of the three kinds — i.e. the central feasibility claim (D3) is validated, ideally captured as an `experiments/` entry.
- `related`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve to existing enhancements.
- `semver` in `config.yaml` is set (major / minor / none), informed by OQ5.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and each path exists today (or is explicitly marked *(new)*).

## accepted → implemented

The enhancement is shipped when:

- `core/` carries `#CRD` (and friends) and the `#CRD` instances for every in-scope kind, with the matching `core/SPEC.md` section co-committed (via the `core-schema-edit` protocol); the existing `#ModuleInstance`/`#Platform` field shapes are reused, not forked.
- `opm-operator/cmd/crdgen` exists, consumes the published `opmodel.dev/core`, and emits both the CRD YAML (`config/crd/bases/*.yaml`) and the Go API types (`api/v1alpha1/*_types.go`), with controller-gen `object` producing `zz_generated.deepcopy.go` over the generated structs.
- The hand-authored API structs are deleted (not aliased); non-type helpers (`conditions.go`, `groupversion_info.go`, `GetConditions`/`SetConditions`) are relocated to clearly non-generated files.
- `opm-operator` builds and its controller tests pass against the generated types; `cli` builds unchanged against the generated `api/v1alpha1` types (the 0006 consumer contract).
- The `crdgen:check` CI gate is wired and demonstrated to fail on an intentional drift, then pass on regeneration (D7).
- The regenerated CRD YAML is byte-compatible (modulo formatting) with the previously shipped CRDs for unchanged fields — i.e. no accidental schema change rides along; any deliberate difference is listed in `README.md ## Deviations from Design`.
- `config.yaml.implementation.status = complete` with `date` set to the landing date; `history` carries events naming the `core` and `opm-operator` landings (with `slice:` refs where the target repo used OpenSpec).
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`, and `## Deviations from Design` lists every deliberate divergence (or says "None").
