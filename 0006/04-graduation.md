# Graduation Criteria — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## draft → accepted

The design is frozen and ready for slicing when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- D1–D17 in `03-decisions.md` are locked, and the load-bearing Open Questions are resolved or explicitly deferred. **OQ1** (platform source) is resolved by D11/D12/D17; **OQ2** (dependency topology) is resolved by D13. Still required before `accepted`: **OQ5** (one wave or two) and **OQ10** (`spec.values` capture / render parity) — OQ10 must be resolved by research or explicitly deferred into the kernel-adoption wave with a recorded reason, because it is load-bearing for the zero-downtime no-op claim. OQ3/OQ4/OQ11–OQ14 (and OQ6–OQ9) may resolve in their slices but each must carry a `Status:` decision.
- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/`) and captures the `spec.owner` field and the CLI status subset end-to-end.
- `config.yaml.affects` is final (`cli`, `opm-operator`, `library`).
- `config.yaml.semver` is set. Expected `none` for `opmodel.dev/core` (this enhancement touches no `core` schema); the operator's `ModuleInstance` CRD gains an additive `spec.owner` field within `v1alpha1`.
- `related` (`0001`, `0002`, `0003`) is final and resolves.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch (each verified to exist today).
- OQ1's render-digest parity experiment (CLI obtaining a materialized platform and producing a render digest equal to the operator's for the same release) is **deferred into the C2 kernel-adoption wave with a recorded reason** (D30): it is only measurable once the CLI renders through the `library` kernel, so it lands as a delivery gate on the cli-render slice, not a `draft → accepted` gate. The gate this section permitted is therefore satisfied.
