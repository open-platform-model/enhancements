# Risks, Drawbacks, Alternatives: Attribute-Declared Secret Fields

This document records the honest costs of the proposed design. Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **A mistyped marker is invisible.** `@opm(secrit, group=db)` is a perfectly valid CUE attribute. It evaluates, vets, and publishes without complaint, and the field is silently *not* discovered, so the kernel never resolves it and the deployer's `{value: "…"}` reaches the render as plaintext. This is the sharpest risk in the design, because the failure is silent and the consequence is disclosure.

  Partial mitigations: the kernel warns on any `@opm(...)` whose position-0 kind is not in its known set, which catches `secrit` but not a misspelled *argument*; `opm module inspect` lists what was discovered, so an author can see a field missing. Neither is airtight.

  **The airtight check:** a field typed `#Secret` that discovery did not find is a contradiction, and the kernel can reject it outright. That check has no analogue in the current design, where a secret is only ever identified by the same `$opm` field a typo would break.

- **A module reads `.value` of a resolved secret.** An author writing `"password=\(#config.db.password.value)"` vets fine against `debugValues` (arm 1 has `value`) and then breaks at render, because the resolved value is arm 2 and has no `value` field. The bare CUE error, `undefined field: value`, does not say why.

  **Mitigation:** the kernel knows exactly which paths it rewrote, so `opm/compile` catches that error and re-reports it against the config path: *"module reads `.value` of the secret at `db.password`; secret data is not readable during render."* Listed as a graduation criterion. This is the one place the design is less legible than the superseded handle approach, and it is the first thing an author will try when they want a secret inside a rendered file.

- **Group disagreement is a new authoring error.** Two fields in one group declaring different `type`, or different `immutable`, has no sensible resolution. **Mitigation:** the kernel rejects it with both member paths named. Listed as a graduation test.

- **Attributes are not part of CUE's evaluated value, so a tool that reconstructs values loses them.** Anything that exports to JSON and reimports drops the marks. **Mitigation:** mostly benign by design: the marks live in the module's `#config`, which is CUE source and travels as source through `cue mod publish`, and it is precisely why discovery reads the schema rather than anything derived. It remains a real constraint on any future tool that wants to round-trip a module through a non-CUE representation. Measured in experiment 01: `Syntax()` preserves attributes under every option set; `MarshalJSON` does not.

- **CUE removing or changing attributes.** The design rests on a language feature. **Mitigation:** investigated for enhancement 0009 and recorded in `enhancements/0009/research/cue-attribute-longevity.md` (2026-06-29): no deprecation exists or is proposed, the API is stable, CUE's own custom-function mechanism is built *on* an attribute (`@extern`), and attributes are being actively extended. Residual risk is low. The one placement constraint that dossier found (attributes attach *after* a field, never before an identifier) is what this design already does. Note the blast radius is now smaller than under the superseded D4: if attributes vanished, the *fulfilment* contract (`#Secret`) still works and only routing would need a new home.

- **The resolved-arm rewrite conflicts with a retained conjunct.** `{value: …} & {ref: …, key: …}` is bottom under `#Secret`'s closed arms, so if anything downstream re-unifies the original values against the rewritten ones (the instance file's own conjunct, a CR round-trip, `kernel.Validate` in the same build), the render fails outright rather than subtly. **Mitigation:** none yet; this is **OQ2**, and it is the blocker to acceptance precisely because it is load-bearing. Experiment 02 performs the rewrite by decode → mutate → encode, which sidesteps unification and works, but that has not been measured against the real kernel path. The failure mode is at least loud rather than silent.

## Drawbacks

- **The kernel becomes a required participant in producing a deployable result.** `cue eval` on a module still works (that is what keeping both arms as structs bought), but the resolved values, and therefore the actual object names, exist only after the kernel has run. Accepted: one name authority and no plaintext in the graph are not expressible in CUE alone.

- **`{value: "hunter2"}` rather than `"hunter2"` in a `ModuleInstance` CR.** The bare-scalar form was rejected in D10 because it makes the value's *kind* change across resolution, which would force every consumption site in the catalog to be retyped and would break `cue vet` on a module carrying a referenced secret. The wrapper is the price of kind stability. It is also the status quo, so nobody has to change anything.

- **A secret's value cannot drive CUE control flow, and cannot be interpolated at all.** `if #config.db.password != "" { … }` and `"password=\(#config.db.password)"` both fail. This is not a regression, since today that field is a struct too, but it becomes a permanent, deliberate property that the authoring docs must state, rather than an accident of the encoding.

- **A published `core` breaks.** D9/D12 remove definitions and narrow `#Secret`'s arms in a published module. Any consumer outside this workspace using `core.#Secret`'s current shape breaks with no shim. Accepted because the consumer set is known and `cli` has no external users.

- **Migration touches a live cluster.** `modules/metallb`'s rendered Secret name changes, and its RBAC `resourceNames` scoping references the old name. Getting this wrong takes the speaker's gossip encryption down. Called out as an explicit migration step in `06-operational.md` rather than left to be discovered.

## Alternatives

- **Keep the current design; fix only what is broken.** Unify core and catalog on one definition, repair the three name formulas, add validation comparing `$secretName` to the `spec.secrets` map key. **Why not:** it costs most of the same migration for none of the structural wins. Routing is still stated twice, plaintext is still in the render, and the mechanism that produced the name drift survives.

- **Remove the contract type entirely and mark with the attribute alone.** This was D1, and it was the entry's first design. **Why not:** superseded by D10 within the drafting session. Removing the disjunction removed the deployer's only slot for choosing fulfilment, and every replacement surface cost more than the disjunction did. The routing metadata was the problem; the type was not.

- **Move secret handling entirely into the catalog, with no kernel involvement.** A catalog-shipped transformer discovers and materialises, as `#AutoSecrets` was meant to. **Why not:** discovery must read the schema side (D3), and a transformer sees only its own component's resolved spec: it cannot reach `#module.#config`. This is also what the ten-level pyramid was an attempt at, and its depth ceiling and list blind spot are consequences of doing the walk in CUE.

- **Make secrets a first-class primitive in `core`**, with real metadata and versioned identity, as `SPEC.md` currently and wrongly claims. **Why not:** it forces core to name a catalog primitive's FQN, which is exactly what enhancement 0010 OQ9 established core cannot do, and what `7500c5d` removed. D12 keeps `#Secret` in core as a *type*, which carries no identity and so does not repeat that error.

- **Handle secrets entirely outside OPM**: the module declares nothing, the operator wires Kubernetes Secrets by hand. **Why not:** it discards the one thing the module author knows and the operator does not, which is *which fields are sensitive*. That knowledge is what makes redaction, inspection, and fulfilment checking possible at all.
