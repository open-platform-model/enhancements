# Graduation Criteria: Machine-Readable Artifact Metadata in cue.mod/module.cue

These are design acceptance criteria, not implementation milestones: delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`.

## draft → accepted

Ten gates must all hold before promoting this design from draft to accepted:

- Goals and Non-Goals in `02-design.md` are final and reviewed.
- OQ1 resolved: the `catalogs` rule for catalog dependencies outside `opmodel.dev/catalogs/*` is decided and encoded in `schemas/target.cue`.
- OQ2 resolved: whether the gate asserts `kind` against the path prefix inside OPM-owned domains.
- OQ4 resolved: the wording of the 0011 decision that amends D3 and D8 is agreed, so it can be appended to 0011 the moment this entry is accepted.
- `schemas/target.cue` defines `#ModuleFileCustom` and `#ModuleFileCustomGate`; `schemas/examples.cue` shows a cert_manager-shaped block passing and records the drift cases experiment 03 refuses; `schemas/spec.md` drafts SPEC.md §5.4; `cue vet ./...` passes in `schemas/` and `contracts/`.
- Experiments 01 (tidy round-trip) and 02 (publish and fetch verbatim) are concluded, since D1 rests on them.
- `config.yaml.semver` is set. Expectation: `minor` (additive core definitions; the refusal arrives behind D8's window).
- Every decision carries a valid `**Kind:**` and no document prescribes mechanism.
- Cross-References in `README.md` list every file the implementation will touch, each verified to exist.
- No `{Capitalised}` placeholder strings remain; `task vet:one ID=0022` and `task check ID=0022` pass.
