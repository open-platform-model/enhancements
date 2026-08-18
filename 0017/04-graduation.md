# Graduation Criteria — Layered Defaults

This document records the gates that must hold before the enhancement advances along the design lifecycle.

## draft → accepted

The enhancement is ready to be implemented when:

- OQ1 (blueprint posture: keep defaults permanently vs drop post-D5) is decided — it determines the catalog slice's final shape and the modules cleanup's expected render diff.
- OQ3 (kernel finalize mechanics) is resolved by a concluded experiment under `experiments/`: recursive `Default()` walk vs export-and-rebuild, demonstrating absence preservation for unset optional fields, config-context ambiguity errors, and `#Secret` value passthrough.
- OQ4 (core/catalog landing order) is decided and reflected in `06-operational.md` / `plan.yaml`.
- OQ2 (L4 gate mechanics) is either resolved or explicitly deferred to the cli gate slice with a note in the decision log.
- The D5 projection is validated against the real `core` schema (not only the replica): the five-case matrix (unset/set/`optional: false`/typo/unstated posture) plus a blueprint-path component, with `task check` green in `core`.
- `schemas/target.cue` compiles and the `#LayerContract` rules match core SPEC.md §6 verbatim.
- `semver` set (`major` — core `feat!` plus catalog `feat!`), `plan.yaml` scaffolded (affects spans five repos).
- No `{Capitalised}` placeholders; Cross-References table paths verified to exist.

## accepted → implemented

The enhancement is shipped when:

- **core**: optionality-aware projection landed with regression fixtures for the five-case matrix; SPEC.md §2.2/§3.1/§6 co-updated (L5 reworded to the kernel guarantee); shipped in a `v2.0.0-alpha.N` release.
- **library**: finalize-before-fill landed on all three paths (single-source, `ValidateConfigDetailed`, synth/debugValues) with test coverage including the default-as-commitment case (a config default violating a downstream constraint errors; the silent-substitution behavior is gone) and absence preservation.
- **catalog**: workload blueprints carry per-kind narrowing + defaults per OQ1's answer; transformer regression fixtures include blueprint-path components; catalog_opm issue 40's audit either landed or explicitly split out with its remaining scope recorded there.
- **cli**: templates render out of the box (`opm inst build` in CI against every generated template); hand-set strategy lines removed from templates.
- **modules**: extracted boilerplate deleted from the v2 stateless-workload modules; render diff matches OQ1's expectation (empty under the opinionated posture).
- `config.yaml.implementation.status: complete` with `date`; history events name each landing with its slice ref; README carries the implementation-status quote block and a `## Deviations from Design` section.
