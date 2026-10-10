# Source note: seed-registration-acceptance

This is a seed. It records behaviour the operator ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `registration-acceptance`. Full seed (8 requirements). Written 2026-10-10 from the operator at commit `cb97ffb0`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path, condition reason or file path.

| Requirement here | Source requirement in the operator's spec | Code read |
| --- | --- | --- |
| Every claim receives a verdict | `opm-operator` `openspec/specs/registration-acceptance/spec.md` at `cb97ffb0`, "Every claim receives a verdict" | |
| The claimed artifact must be a catalog | same file, "The claimed artifact must be a catalog" | |
| The provider set is re-derived and compared | same file, "The claimed provider set is re-derived and compared for exact equality" | |
| A claim must come from its named instance | same file, "The claim must come from the instance it names" | |
| A second claim for one provider is refused | same file, "A second claim for one provider is refused naming the claimant" | |
| A contract has one provider | same file, "A contract has one provider" | |
| A build-incompatible provider is refused at acceptance | same file, "A build-incompatible provider is refused at acceptance" (first paragraph only) | `internal/controller/transformerregistration_buildcompat.go` at `cb97ffb0` (`buildIncompatibility`) |
| An accepted claim survives a transient registry failure | same file, "An accepted claim keeps its verdict through a transient registry failure" and "A token endpoint answer is judged by its status" (merged) | |

## Left out

- "Acceptance holds on both paths of the provider-set derivation": it describes how a test is built, a mechanism.
- The own-major comparison in "A build-incompatible provider is refused at acceptance" (the second half of that requirement and its two last scenarios). The spec marks it `Source: 0015:D8, 0026:D7:R2, 0026:D9:R7`. A live entry owns it, so the seed holds the shipped behaviour of enhancement 0015 only. The code already has the own-major comparison (change `index-build-compat-by-major`, 2026-09-30).
