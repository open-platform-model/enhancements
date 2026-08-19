# Risks, Drawbacks, Alternatives — Kernel render path parity with pure CUE

## Risks and Mitigations

- **A fixture starts shipping a broken value instead of no value.** `TestFlow_WebApp_OnOpmPlatform` builds its instance by `LookupPath` plus `FillPath`, which severs the reference that wires `#instance`. Today `#names.dns.fqdn` is unreachable, so the defect is invisible; once definitions are exposed it becomes a concrete wrong answer (`required field missing: namespace`) that a naive reading blames on this enhancement. Anything else in the workspace constructing instances the same way inherits it. **Mitigation:** the fixture repair is inside the slice that exposes definitions, not after it (D4), and `cli` and `opm-operator` are swept for the same construction shape before that slice lands.

- **The ADR-003 closedness corruption returns through a path not covered by the probe.** The hazard was reproduced once, on one shape (an output-local hidden field consumed in-expression), on the federated surface. A different composition could still trip the unfixed upstream CUE Go-API bug that ADR-003 documents as open. **Mitigation:** both existing regression guards stay in the suite unchanged and gate every slice; the `cueregression` canary pair continues to pin the evaluator behaviour in both directions; the parity harness adds a second, independent detector, since a corrupt value diverges from the CUE oracle by construction.

- **The parity oracle disagrees for reasons that are not defects.** `#context` is projected differently on the two sides (Go-built versus CUE-derived), and a naive structural comparison could fail on field ordering, absent-versus-null, or defaults. A harness that cries wolf stops being read, which is the failure mode of every coverage check. **Mitigation:** the equality is specified before the harness is written (a `draft → accepted` gate), and OQ5 exists partly because making `#context` a projection removes the largest source of legitimate disagreement.

- **`#57`'s nondeterminism becomes load-bearing for rendering.** Definitions on the schema-side component value have been observed going silently absent under catalog-version skew. Match already depends on that value, so the exposure is not new, but rendering would inherit it. **Mitigation:** the exposure is bounded by the fact that 0010 closed the skew window at its source; the parity harness would surface a recurrence as a divergence rather than as an empty match. Not fully mitigated: this is a known residual, and it argues for keeping `#57` open until the harness has run against a skewed tree.

- **The single-build reading is wrong.** OQ1 through OQ3 rest on the claim that 0010 D14 deleted ADR-003's premise. If some consumer still depends on multi-version-per-major composition, or MVS's override of the platform's named version proves unacceptable, the largest deletions in this design do not happen. **Mitigation:** the parity work (D1 through D3) is independent of the single-build question and delivers value on its own; the three OQs gate only the further collapse.

## Drawbacks

- **A Go API break.** `FinalizeValue` is exposed as a public kernel method, so removing it from the render path and then from the surface is a MAJOR library bump with a `MIGRATIONS.md` entry, and it lands while `cli` and `opm-operator` are actively consuming the library.

- **Transformers can now reach further than the execution unit implies.** D2 fixes execution at one component and D3 hands the transformer the whole instance, which contains every sibling. Per-pair independence becomes a convention. OQ4 is where this is decided, but under a strict reading of D1 the likely answer is to accept it, and accepting it costs a structural guarantee.

- **A new authoring rule that CUE does not announce.** A transformer must re-declare a slot in its own `#transform` body to reference it, because CUE resolves references lexically. This is already true for `#component` and is currently invisible because everyone copies an existing transformer. The moment `#moduleInstance` becomes usable, the rule needs documenting, and its failure mode is a build error naming a missing reference rather than anything about the contract.

- **The harness costs maintenance.** Every render-path fixture now has a CUE twin that has to stay in step. That is the price of the oracle, and it is a real ongoing cost rather than a one-time write.

## Alternatives

- **Codify the current behaviour: declare that transformers see data, not definitions.** Document the strip as the contract, and have `core` expose anything a transformer needs as regular fields. **Why not:** it inverts the dependency, since the schema would then be shaped around a Go-side artifact, and it makes the workaround in open-platform-model/core#49 the first of an unbounded series, one per computed projection.

- **Keep the strip and widen `#TransformerContext` instead.** Plumb each needed projection into the context struct as the need arises. **Why not:** every addition is kernel code, so the surface grows in the opposite direction to D1, and the kernel becomes the arbiter of which computed values a transformer may see.

- **Go straight to the single-build render pipeline.** Skip the incremental fills and collapse the whole path in one change. **Why not:** it is blocked on three unresolved questions, one of which is a genuine design fork about whether MVS may override a platform's named catalog version; and the parity fixes are valuable independently of how that resolves.

- **Fix it in `core` only, via open-platform-model/core#49 and open-platform-model/catalog_opm#44.** **Why not:** those are correct and should still land for their own reasons, because the computed name genuinely does not match the rendered name. But they address one value, and they justify their shape by working around this defect rather than by the semantics they want.
