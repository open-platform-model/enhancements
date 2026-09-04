# Graduation Criteria: CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## draft → accepted

The design is frozen and ready for slicing when:

- Design Goals and Non-Goals in `02-design.md` are final and reviewed.
- D1–D17 in `03-decisions.md` are locked. Every load-bearing Open Question must be resolved or explicitly deferred before `draft → accepted`:
  - Resolved: **OQ1** (platform source) by D11/D12/D17; **OQ2** (dependency topology) by D13.
  - Still required: **OQ5** (one wave or two) and **OQ10** (`spec.values` capture / render parity). OQ10 must be resolved by research or explicitly deferred into the kernel-adoption wave with a recorded reason, because it is load-bearing for the zero-downtime no-op claim.
  - May resolve in-slice: OQ3/OQ4/OQ11–OQ14 (and OQ6–OQ9), each carrying a `Status:` decision.
- `contracts/contracts.cue` compiles (`cue vet ./...` from `schemas/`) and captures the `spec.owner` field and the CLI status subset end-to-end.
- `config.yaml.affects` is final (`cli`, `opm-operator`, `library`).
- `config.yaml.semver` is set. Expected `none` for `opmodel.dev/core` (this enhancement touches no `core` schema); the operator's `ModuleInstance` CRD gains an additive `spec.owner` field within `v1alpha1`.
- `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- The Cross-References table in `README.md` lists every file path the implementation will touch (each verified to exist today).
- OQ1's render-digest parity experiment (CLI obtaining a materialized platform and producing a render digest equal to the operator's for the same release) is **deferred into the C2 kernel-adoption wave with a recorded reason** (D30): it is only measurable once the CLI renders through the `library` kernel, so it lands as a delivery gate on the cli-render slice, not a `draft → accepted` gate.
