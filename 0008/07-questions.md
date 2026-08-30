# Open Questions: CUE-Native CRD Schemas as Single Source of Truth

## Open Questions

Track unresolved questions surfaced during design. Each entry carries a
`Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or
`answered` when the question resolves.

- **OQ1: Where does the generator live long-term: `opm-operator/cmd/crdgen` or a shared workspace tool?** Status: open. D2 starts it in `opm-operator` to co-locate with the first consumer, but the CLI also consumes the types; if a second independent consumer needs to regenerate, a shared `cmd/` (or a tiny dedicated repo) may be warranted. Resolved by deciding whether `cli` ever regenerates independently of `opm-operator`.
- **OQ2: How are status fields handled: same `#CRD` body, or a `core`-side split of authored spec vs operator-owned status?** Status: open. Blocking: acceptance (gates whether the first slice is well-formed). The operator owns rich status (`conditions`, `inventory`, `history`, `failureCounters`); some of it has no domain meaning in `core`. Does `core` define the full status shape, or does `#CRD` reference a status fragment that lives partly in operator-owned CUE? Resolved by mapping each existing status field to an owner.
- **OQ3: Commit the generated artefacts, or generate at build time only?** Status: partial. D7 assumes committed-and-diffed for reviewability and buildability without the generator. Open sub-question: do downstream consumers (CLI) ever need the generator in their build path, which would argue for committed artefacts as the only practical option.
- **OQ4: Does the `ModulePackage` kind have a `core` domain definition to anchor its `#CRD`, or is it operator-only?** Status: open. Blocking: acceptance (gates whether the first slice is well-formed). `ModuleInstance` and `Platform` map cleanly to existing `core` definitions; `ModulePackage` (Flux-sourced) may be operator-specific. If operator-only, either add a minimal `core` definition or scope `ModulePackage` out of the first slice. Resolved by checking `core/src` for a ModulePackage shape and deciding ownership.
- **OQ5: What is the semver impact on `opmodel.dev/core`?** Status: partial. Blocking: acceptance (sets config.yaml.semver). Adding `#CRD` and `#CRD` instances is additive (minor) for `core`'s schema. But if anchoring the CRDs forces any change to the existing `#ModuleInstance`/`#Platform` field shapes, that could be breaking. Resolved once the `core` slice is spiked and the diff to existing definitions is known (feeds `config.yaml.semver`, required for `accepted`).
