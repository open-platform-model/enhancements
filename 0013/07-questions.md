# Open Questions: Attribute-Declared Secret Fields

## Open Questions

- **OQ1: Which surface chooses between the supplied and referenced fulfilment kinds?** Status: resolved-by-D10.

  Resolved by keeping the choice in the field's *type*. D1 had removed the disjunction along with the routing metadata, leaving nowhere for the deployer to express "this object already exists"; D10 restores a narrowed `#Secret` whose two arms are exactly that choice, so CUE resolves it by unification as it does today. The three candidate surfaces this question weighed (an attribute argument, a scheme-prefixed value string, and a sibling block on `#ModuleInstance`) are all rejected in D10's alternatives, the first because it bakes a cluster fact into a published module, the other two because they cost more than the disjunction they were replacing.

- **OQ2: Is replacing a user-supplied arm with the kernel-resolved arm a clean value replacement?** Status: resolved-by-D16.

  The kernel rewrites `values.<path>` from `{value: …}` to `{ref: …, key: …}` (D11). `experiments/02-resolve-in-place` performs this by decode → mutate → encode, which sidesteps unification entirely and works. What is unverified is whether anything downstream re-unifies the *original* values against the rewritten ones (the instance file's own conjunct on the `values` vertex, a `ModuleInstance` CR round-trip, or `kernel.Validate` running against real values in the same build) and produces a conflict, since `{value: …} & {ref: …, key: …}` is bottom under `#Secret`'s closed arms.

  Resolving this requires a measurement against the real `library/opm/kernel` path rather than a synthetic one, and it determines whether the kernel needs two builds (one to validate against supplied values, one to render against resolved values) or can do both in one. It is a research item rather than a judgement call, and it is the last mechanical unknown in the design.

  Two candidate implementations to measure: bake-style (the `synth.Instance` path already writes `values.cue` into the build; write the *resolved* values instead, validating the raw values separately) and fill-style (build the instance package with the `values` vertex unset, then `FillPath` the resolved values into the empty slot). Three doors to check for original-conjunct leakage: the file-loaded instance package, the synth path, and a `ModuleInstance` CR round-trip. If the measurement rules out clean omission on every candidate, the recorded fallback is the `#SecretBase` coexistence fill in D11's alternatives (accepting plaintext-in-graph as convention), not `#ctx.secrets`, which additionally moves the author wiring.

  Was the sole blocker to `draft → accepted`. **Measured 2026-08-14 by `experiments/03-kernel-omission/` against the published kernel: clean omission holds on both candidates, override is refuted by the kernel's own fill seam, one graph build suffices. The fallbacks are not needed. Resolved by D16.**

- **OQ3: Can a deployer's values be checked against `#config` without changing what the instance exports?** Status: open. Blocking: implementation.

  Measured in the 2026-09-30 feasibility review: core declares an instance's `values` open and unifies them with `#config` only where a component reads them, so an unfulfilled secret nobody reads, or a value carrying both a literal and a reference, passes plain vet, and the package path accepts the mixed form. Binding `values` to `#config` directly makes CUE check them, but may fill `#config` defaults into the exported values that frontends decode and hash. What would settle it: whether a hidden check field (the values unified with `#config` beside, not into, `values`) catches both cases without changing the exported values; if not, whether the defaults leaking through a direct binding changes any frontend's output.

- **OQ4: Can a platform set a source's settings by unifying into the enabled catalog's transformer?** Status: open. Blocking: implementation.

  D21 needs platform defaults per installed source with no core field. The platform already unifies into each enabled catalog entry's transformers. What would settle it: a source transformer declaring a settings definition, a platform filling it through its catalog entry, and a render reading the filled value.

- **OQ5: Does a synthesised component carrying a source's contract type-check the source's entries at render?** Status: open. Blocking: implementation.

  D18 leaves `#SecretSource.spec` open in core and lets the source's resource schema type it. What would settle it: a synthesised component whose spec is `#SecretSourceInput` with a catalog-typed `entries`, rendering with valid entries and failing, at the entry's path, with invalid ones.

- **OQ6: Does a component key outside the author key space survive every tool that addresses components?** Status: open. Blocking: implementation.

  D23's key cannot be written by an author. What would settle it: a render carrying such a key, then the inventory, the operator's recorded status and CLI component selection each handling it without error.

- **OQ7: Can the render build resolve a source's short name through the annotation?** Status: open. Blocking: implementation.

  D19 resolves `source` against the platform's defined contracts by the value of D20's annotation. What would settle it: zero, one and two contracts carrying a name, giving refusal with the installed list, resolution, and refusal as ambiguous; and the FQN form resolving in the ambiguous case.

- **OQ8: Which rule detects a field typed `#Secret` in every form a module can declare it?** Status: open. Blocking: implementation.

  D13 keys discovery on the type. Measured in the 2026-09-30 feasibility review: following a direct reference misses an embedded `{#Secret}` and a `let`-aliased one, and core's earlier release publishes a different `#Secret` under the same name, so detection must also tell the two apart. What would settle it: a detector run over direct, embedded, aliased, defaulted, disjunction-arm, pattern, list-element and declaration-attribute forms, against both core releases, comparing reference walking, arm-shape matching and a hidden tag on core's arms.
