# Graduation Criteria — Layered Defaults

This document records the entry-specific gates that must hold before this design is frozen.

## draft → accepted

The enhancement is ready to be implemented when:

- OQ1 (blueprint posture: keep defaults permanently vs drop post-D5) is decided — it determines the catalog slice's final shape and the modules cleanup's expected render diff.
- OQ3 (kernel finalize mechanics) is resolved by a concluded experiment under `experiments/`: recursive `Default()` walk vs export-and-rebuild, demonstrating absence preservation for unset optional fields, config-context ambiguity errors, and `#Secret` value passthrough.
- OQ4 (core/catalog landing order) is decided and reflected in `06-operational.md ## Cross-Repo Coordination`.
- OQ2 (L4 gate mechanics) is either resolved or explicitly deferred to the cli gate slice with a note in the decision log.
- The D8 compatibility matrix exists as fixtures: {fresh template, defaulted-config module, collision module, eliminated-default module} × {plain `cue vet`, plain `cue export`, `opm inst build`}, with expected outcomes recorded per cell (C1 all-pass column; C3's two loud divergences in the export column).
- The D5 projection is validated against the real `core` schema (not only the replica): the five-case matrix (unset/set/`optional: false`/typo/unstated posture) plus a blueprint-path component, with `task check` green in `core`.
- `schemas/target.cue` and `contracts/contracts.cue` compile and the `#LayerContract` rules (`contracts/contracts.cue`) match core SPEC.md §6 verbatim.
- `semver` set (`major` — core `feat!` plus catalog `feat!`), the cross-repo ordering constraints stated in `06-operational.md` (affects spans five repos).
- No `{Capitalised}` placeholders; Cross-References table paths verified to exist.
