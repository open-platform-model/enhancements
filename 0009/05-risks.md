# Risks, Drawbacks, Alternatives — Operational Primitives: Op, Action, Lifecycle, Workflow

Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **The closed primitive set is too small and authors route around it.** If the Op vocabulary cannot express common needs, authors fall back to a raw `exec` container for everything — re-creating the Helm "arbitrary script" problem inside OPM. **Mitigation:** ship a useful initial vocabulary plus ready-made `#Action` compositions; treat the container/exec backend as a heavyweight, reviewable escape hatch; let the catalog grow the vocabulary without a library release (D6).

- **Pluggable, remotely-loaded executable artifacts are a supply-chain and trust surface.** An `@op(ref=…)` pointing at a wasm/OCI artifact pulls and runs third-party code. **Mitigation:** artifact form (OQ1) should favor sandboxed execution (wasm) for the default; backends are frontend-registered so an environment can refuse classes of execution; pinning/version + provenance ride the same registry trust model as catalog transformers. Needs explicit treatment in `06-operational.md` once OQ1 lands.

- **Kernel neutrality erosion.** Pressure to "just run it here" could leak side effects into the planner. **Mitigation:** the `opm/flow/` planner/runner must stay I/O-free with the `Executor` interface the only egress; enforced by the same review discipline as the render half and Principle I.

- **Lifecycle hooks behave non-convergently under reconcile.** If phase steps are treated as fire-and-forget, the operator re-runs them every reconcile. **Mitigation:** lean on convergent executors and completion records (OQ3 design); `#Workflow` (the genuinely non-idempotent case) is on-demand and separated from the reconcile path.

- **Attribute drift between schema and SDK.** The `@op(...)` grammar is a contract between `core` definitions and the library planner; a mismatch fails silently (attribute ignored) rather than loudly. **Mitigation:** validate the attribute grammar in the planner and add fixtures asserting every shipped Op's attribute parses to a registered protocol.

- **Dependence on CUE attributes as a language feature.** The entire dispatch mechanism (D5/D6) assumes CUE keeps `@attr(...)` and the `cue.Value.Attribute` SDK reader. **Mitigation / assessment (`research/cue-attribute-longevity.md`, 2026-06-29):** researched directly — no removal or deprecation is planned; the SDK API carries no deprecation notice; attributes are being *extended* (list-element attributes, attribute-query builtins); and CUE's own custom-function feature is itself attribute-based (`@extern`), so the "custom functions" direction consumes attributes rather than replacing them. Residual risk is low. One adjacent surface *is* experimental — CUE's evaluation-time WASM `@extern` interface — which only matters if OQ1 (artifact form) leans on CUE's eval-time functions rather than OPM's runtime backends; 0009's runtime-dispatch use of attributes as inert metadata is the most stable dependency available.

## Drawbacks

- A second execution model in the kernel is real surface area to learn, test, and maintain alongside rendering.
- The two-level plugin system (backends + artifacts) is more moving parts than a compiled-in implementation; the payoff is pluggability without library releases.
- Authors and platform teams take on a new authoring surface (flows, phases, backend registration) that did not exist before.

## Alternatives

- **Render operations as resources through the existing transformer pipeline.** Operations become Jobs emitted by `opm/compile/`. **Why not:** the render half has no sequencing/ordering model and conflates "what exists" with "what happens" (D1).
- **Compile op implementations into the library (hof.io model).** **Why not:** every new operation needs a library release; the system must be pluggable and catalog-sourced (D6).
- **Adopt Helm-style hooks.** **Why not:** arbitrary script as a hook is the exact maintainability failure this enhancement exists to avoid.
