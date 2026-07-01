# Graduation Criteria — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## draft → accepted

The design is frozen and ready for slicing when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- D1–D17 in `03-decisions.md` are locked, and the load-bearing Open Questions are resolved or explicitly deferred. **OQ1** (platform source) is resolved by D11/D12/D17; **OQ2** (dependency topology) is resolved by D13. Still required before `accepted`: **OQ5** (one wave or two) and **OQ10** (`spec.values` capture / render parity) — OQ10 must be resolved by research or explicitly deferred into the kernel-adoption wave with a recorded reason, because it is load-bearing for the zero-downtime no-op claim. OQ3/OQ4/OQ11–OQ14 (and OQ6–OQ9) may resolve in their slices but each must carry a `Status:` decision.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/`) and captures the `spec.owner` field and the CLI status subset end-to-end.
- `config.yaml.affects` is final (`cli`, `opm-operator`, `library`).
- `config.yaml.semver` is set. Expected `none` for `opmodel.dev/core` (this enhancement touches no `core` schema); the operator's `ModuleInstance` CRD gains an additive `spec.owner` field within `v1alpha1`.
- `related` (`0001`, `0002`, `0003`) is final and resolves.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch (each verified to exist today).
- OQ1's render-digest parity experiment (CLI obtaining a materialized platform and producing a render digest equal to the operator's for the same release) is **deferred into the C2 kernel-adoption wave with a recorded reason** (D30): it is only measurable once the CLI renders through the `library` kernel, so it lands as an `accepted → implemented` gate on the cli-render slice (below), not a `draft → accepted` gate. The gate this section permitted is therefore satisfied.

## accepted → implemented

Shipped when, across the sliced OpenSpec changes:

- **library:** no inventory package (D31 reverted `library/opm/inventory`, originally D13) — `library`'s role in this enhancement is the kernel only (D9).
- **opm-operator:** `spec.owner` field + skip-reconcile path + `ManagedExternally` condition landed and CRD regenerated (D3); `internal/inventory` stays in place, unchanged (D31 reverted the D13 plan to migrate it to `library`); `k8s.io/*` + `controller-runtime` bumped to the CLI's latest-stable line (Problem 3); all behind tests.
- **cli:** module renamed to `github.com/open-platform-model/cli` (D15); Secret-specific inventory code (`internal/inventory`'s Secret CRUD/marshaling) deleted; the entry-identity/stale-set/digest logic (`internal/inventory`, `pkg/inventory`) stays in place, ported onto the CR-backed flow (D31 reverses D13's plan to replace it with a shared `library` import); CR-backed inventory (as `unstructured`) in apply/delete/status/list/diff (D1, D2); one-time Secret migration (D8/D14, no deprecation window); `opm install crds|operator` + `uninstall` (D5); `opm instance handoff` forward-only with verification (D7, no reverse mode — D16); both local and cluster Platform sources wired with no admin required on non-`handoff` paths (D11/D17). CLI go.mod gains `library` only, for the kernel (D9), no `opm-operator` (D13).
- **cli render:** `pkg/render` and the `pkg/loader` match path deleted; release rendering routed through the `library` kernel (D9); CLI-side SSA apply retained with manager `opm-cli` (D10). Gated on 0001's `library` slice having shipped.
- **render-digest parity experiment (deferred OQ1, D30):** a CLI render and an operator render of the same `ModuleInstance` against the same `Platform` spec produce a byte-equal `lastAppliedRenderDigest`, covering both a bare published-module reference and a release with non-trivial layered values (D19/OQ10). This is the empirical confirmation of the structural parity D9/D20 establish; it gates the cli-render slice.
- e2e against a kind cluster: CLI apply writes a CR; `handoff` flips ownership with zero resources changed and zero pruned (the no-op property), verified by inventory revision + diff.
- `config.yaml.implementation.status = complete` with `date`; `history` carries each landing milestone (use the `slice` field per OpenSpec change); `README.md` Implementation Status quote block added; `## Deviations from Design` filled (or "None").
