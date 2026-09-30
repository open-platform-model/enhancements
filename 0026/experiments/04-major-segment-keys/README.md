# 04-major-segment-keys: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

If the catalog major is a path segment of every contract and transformer key (`opmodel.dev/catalogs/opm/v5/traits/backup@v1alpha1`), the shipped `#contracts` fold separates two majors of one catalog with no logic change and a key survives every minor release, but the spelling is ambiguous with a catalog whose path ends in `/v5` unless registry paths of that shape are banned. This is the second spelling of D9's first rejected alternative; experiment 03 measures the `@vN` spelling D9 names.

## Setup

Copied, unmodified, from `core/src/` at commit `cbe93e0` (release `2.0.0-alpha.12` plus two comment-only commits): `types.cue`, `resource.cue`, `trait.cue`, `blueprint.cue`, `transformer.cue`, `catalog.cue`, `platform.cue`.

Copied from the same commit and patched: `identity_package.cue`, where `#IdentityPackage` gains a derived `keyPrefix` (`RegistryPath + "/" + Major + "/<kind>"`, marked `PROBE`) and `#CatalogMemberFQNGate` builds the expected key from `keyPrefix` instead of `kindPrefix`. `kindPrefix`, the filing path, is unchanged, so a primitive's `metadata.modulePath` stays major-free.

Added in `probe/`:

- `ban.cue`: the one other core change, `#ArtifactRef.registryPath` refusing a path ending in `/vN`. In the scratch core it was a conjunct inside `types.cue`; here it is its own file guarded by `@if(!noban)`, so `-t noban` restores the shipped rule.
- `members.cue`: a member set built from an identity package, so keys derive as a catalog leaf authors them; opm@v4 kept flat (legacy), opm@v5 at 5.0.0 and 5.3.1, opm@v6; a provider template shipping one transformer per declaring major it is built against.
- `platforms.cue`: P1 (flat opm@v4 beside segment-keyed opm@v5, k8up@v2 on opm@v4, k8up@v3 on opm@v5), P2 (opm@v5 and opm@v6, one k8up@v4 build serving both), P3 (an opm@v6 bridge requiring opm@v5's container), P4 (k8up@v3 and k8up@v4 both on opm@v5).
- `gate.cue`, `txgate.cue`: the patched gate's accepted inputs, and a publish-time gate refusing a transformer that requires its own catalog's key at another major.
- `case_refused.cue` (`-t refused`), `case_collision.cue` (`-t collision`, P5): the cases expected to fail.
- `report.cue`: gathers the measured fields.

## Run

From `probe/`, with cue v0.17.1:

```bash
cue vet -c=false .                         # every untagged case evaluates
cue export -e report .                     # keys, gate, P1 to P4
cue vet -c=false -t refused .              # gate inputs refused, bridge refused at publish
cue vet -c=false -t collision .            # P5 with the ban: refused at the path
cue vet -c=false -t collision -t noban .   # P5 without the ban: the platform fails to evaluate
```

## Outcome

Measured 2026-09-30, cue v0.17.1. Keys below drop the `opmodel.dev/catalogs/` prefix.

- **Keys.** opm@v5's container is `opm/v5/resources/container@v1beta1` at 5.0.0 and at 5.3.1 (`key_survives_minor: true`); its transformer is `opm/v5/transformers/deployment-transformer@5.0.0`, then `@5.3.1`; the stamped `modulePath` stays `opm/resources/v1beta1`. The shipped `#ContractFQNType` and `#ImplFQNType` accept the segment form unchanged.
- **P1, flat opm@v4 beside segment-keyed opm@v5: evaluates.** `definedBy` is per major, `providedBy` is `{opm/traits/backup@v1alpha1: [k8up@v2], opm/v5/traits/backup@v1alpha1: [k8up@v3]}`, `overSubscribed` and `comparable` empty, `fulfilled`, `routable` and `discriminated` all `true`.
- **P2, one k8up@v4 build serving opm@v5 and opm@v6: routable.** `providedBy` maps both declaring majors' backup keys to `[k8up@v4]`, `overSubscribed` empty.
- **P3, bridge: reported, not refused.** `comparable` is `[{broader: opm/v5/transformers/deployment-transformer@5.0.0, narrower: opm/v6/transformers/deployment-bridge@6.0.0, contracts: [opm/v5/resources/container@v1beta1]}]`, `discriminated` is `false`. The publish-time gate refuses the bridge and a flat own-catalog key (`txBridge.offending`, `txFlat.offending`: `incompatible list lengths (0 and 1)`) and passes own-major keys, other catalogs' keys and a provider requiring two opm majors.
- **P4, a provider's own major upgrade on one declaring major: over-subscribed.** `overSubscribed` is `[opm/v5/traits/backup@v1alpha1]`, `routable` `false`.
- **Gate.** The patched gate accepts segment keys at 5.0.0 and 5.3.1 and the segment transformer key, and refuses a flat key under an opm@v5 identity and an `opm/v4/...` key under opm@v5.
- **P5, a flat-keyed catalog at `opmodel.dev/catalogs/opm/v5@v0` beside opm@v5.** Without the ban it produces opm@v5's keys and the platform fails to evaluate: `definedBy."opmodel.dev/catalogs/opm/v5/resources/container@v1beta1": conflicting values "opmodel.dev/catalogs/opm/v5@v0" and "opmodel.dev/catalogs/opm@v5"`, with matching `defined` conflicts on `modulePath`. With the ban the catalog is refused at its path (`invalid value "opmodel.dev/catalogs/opm/v5" (out of bound !~"/v[0-9]+$")`).

**Hypothesis held.** The segment spelling separates two majors in the unchanged fold and keeps keys stable within a major, but it collides with a legitimate module path ending in a major-shaped element, so it needs a registry-path ban that the `@vN` spelling of experiment 03 does not. The same key shape renders through the shipped library and core with no patch at all (experiment 07, the `majk` cases), because the shipped key type already accepts it. Linked from D9's alternatives, OQ9, OQ14 and OQ15.
