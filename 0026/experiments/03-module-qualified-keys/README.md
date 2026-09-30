# 03-module-qualified-keys: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

If every contract key starts with the complete module path of the catalog major that declares it (`opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1`), the shipped `#contracts` fold, provider count and comparability report hold two majors of one catalog on one platform with no change to their logic. This is D9's first rejected alternative, the major in the key.

## Setup

Copied, unmodified, from `core/src/` at commit `cbe93e0` (release `2.0.0-alpha.12` plus two comment-only commits): `resource.cue`, `trait.cue`, `blueprint.cue`, `transformer.cue`, `platform.cue`.

Copied from the same commit and patched; `core.patch` is the exact diff, and applies to core at `cbe93e0` with `git apply core.patch`:

- `types.cue`: `#ContractFQNType` widened additively to accept `<path>@vN/<kind>/<name>@<apiVersion>` beside today's form, and a new `#ContractRef` that splits a key into its declaring module, lineage and legacy-shaped `lineageKey`.
- `identity_package.cue`: `#IdentityPackage` gains `ContractScope: *"module" | "registry"` and a derived `keyPrefix`; `#CatalogMemberFQNGate` builds a contract's expected key from `keyPrefix`, a transformer's from `kindPrefix` as before. `"registry"` is the legacy flag that lets an already published major keep today's keys.
- `catalog.cue`: `#Catalog` asserts that every contract it lists is keyed under its own module path or its own registry path.

Added in `probe/`:

- `members.cue`: one member source instantiated as opm@v3 and opm@v4 (legacy keys, `ContractScope` registry) and opm@v5 and opm@v6 (module-qualified keys), each with a `container` resource, an `expose` trait, a provider-fulfilled `backup` trait and a deployment transformer; provider catalogs k8up@v3 (one build serving opm@v4 and opm@v5, one transformer each), k8up@v3 on opm@v5, k8up@v4 on opm@v6, k8up@v4 on opm@v5; a bridge transformer in opm@v6 requiring opm@v5's container.
- `platforms.cue`: L1 (legacy opm@v4, qualified opm@v5, one k8up build serving both), L2 (opm@v5 and opm@v6, one provider major per declaring major), L3 (the bridge with opm@v5 enabled), L3b (the bridge with opm@v5 disabled), L6 (two provider majors on one declaring major).
- `keys.cue`: key shapes, `#ContractRef`, the gate cases that pass, and a one-major-per-lineage rule for a component's keys.
- `case_refused.cue` (`-t refused`), `case_owner.cue` (`-t owner`, L5), `case_legacy_pair.cue` (`-t legacy`, L4): the cases expected to fail.
- `report.cue`: gathers the measured fields so one export prints them.

The cases are those of a scratch probe run on 2026-09-30 against a full patched copy of `core/src`. The pin files are not copied into `probe/`; the migration cost they show is measured separately, on a core checkout, by the last command under Run. Experiment 08 renders the same key shape through the real library.

## Run

From `probe/`, with cue v0.17.1:

```bash
cue vet -c=false .                  # every untagged case evaluates
cue export -e report .              # L1, L2, L3, L3b, L6, key shapes, gate, lineage rule
cue vet -c=false -t refused .       # key shapes and gate inputs the patch refuses
cue vet -c=false -t owner .         # L5: opm@v6 listing opm@v5's key
cue vet -c=false -t legacy .        # L4: two legacy majors enabled together
```

Migration cost against core's own pins, on a core checkout (any clone of `github.com/open-platform-model/core`):

```bash
git clone https://github.com/open-platform-model/core.git /tmp/core-03 && cd /tmp/core-03
git checkout cbe93e0aa003b8cd5bbc34420f021ec62694c079
git apply <this experiment>/core.patch
cd src && cue vet -c=false . 2>&1 | grep -oE '^_pin[A-Za-z0-9]+' | sort -u
```

## Outcome

Measured 2026-09-30, cue v0.17.1. Keys below drop the `opmodel.dev/catalogs/` prefix.

- **L1, legacy opm@v4 beside qualified opm@v5, one k8up build serving both: evaluates.** `definedBy` maps `opm/...` keys to opm@v4 and `opm@v5/...` keys to opm@v5. `requiredBy` for `opm/traits/backup@v1alpha1` is `[k8up/transformers/schedule-opm-v4@3.0.0]` and for `opm@v5/traits/backup@v1alpha1` is `[k8up/transformers/schedule-opm-v5@3.0.0]`. `providedBy` lists k8up@v3 once per key, `overSubscribed` and `comparable` are empty, and `fulfilled`, `routable` and `discriminated` are all `true`.
- **L2, opm@v5 and opm@v6, k8up@v3 on opm@v5 and k8up@v4 on opm@v6: evaluates, routable.** `providedBy` is `{opm@v5/traits/backup: [k8up@v3], opm@v6/traits/backup: [k8up@v4]}`, `overSubscribed` empty. The same provider pair under shared keys is over-subscribed (experiment 02).
- **L3, a bridge in opm@v6 requiring opm@v5's container, opm@v5 enabled: reported, not refused.** `comparable` is `[{broader: opm/transformers/deployment-bridge@6.0.0, narrower: opm/transformers/deployment-transformer@5.0.0, contracts: [opm@v5/resources/container@v1beta1]}]` and `discriminated` is `false`. **L3b, opm@v5 disabled:** the bridge is absent from `requiredBy`, because opm@v5's key is no longer defined.
- **L6, k8up@v3 and k8up@v4 both built on opm@v5: over-subscribed.** `overSubscribed` is `[opm@v5/traits/backup@v1alpha1]`, `routable` is `false`. A provider's own major upgrade is still a swap.
- **L4, two legacy majors (opm@v3 and opm@v4): fails to evaluate**, with `defined` conflicting on `catalogVersion` ("3.1.0" and "4.4.2") and `definedBy` on opm@v3 against opm@v4, exactly as experiment 01 case A. Qualified keys fix only pairs that include a qualified major.
- **L5, opm@v6 listing opm@v5's key: refused** by the ownership assertion (`_ownsKeys."opmodel.dev/catalogs/opm@v5/resources/container@v1beta1": conflicting values false and true`).
- **Keys and gate.** The widened type accepts the legacy and the qualified key and refuses `opm@v5/backup@v1alpha1` (no kind), `opm@v5@v6/...` and `opm@5.0.0/...`; `#ImplFQNType` still refuses a qualified transformer key. `#ContractRef` on the qualified backup key gives declaring module opm@v5, lineage `opm` and `lineageKey` equal to the legacy key. The gate accepts a qualified key under an opm@v5 identity and a legacy key under an opm@v4 identity with `ContractScope: "registry"`, and refuses a legacy key under opm@v5, a qualified key under legacy opm@v4, and an opm@v4-qualified key under opm@v5. `#ModulePathType` accepts `opmodel.dev/catalogs/opm/v4@v0`, which is why the qualified form uses `@vN` rather than a `/vN/` segment (experiment 04 measures that spelling).
- **Core's own pins.** With the patch applied to a core checkout, exactly five pins fail: `_pinContractProviderOnlyCatalog`, `_pinGateBlueprint`, `_pinGateResource`, `_pinGateResourceGA` and `_pinGateTrait`. Every other pin holding a legacy key still evaluates, so the type widening is additive.
- **Control.** The shipped `#ContractFQNType` refuses the qualified key (`invalid value "opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1" (out of bound ...)`), so the type change is required; experiment 08 shows the same refusal through a real render.

**Hypothesis held.** With module-qualified keys the shipped fold, provider count and comparability report separate two majors with no logic change, one provider build serves both majors, and a provider's own major upgrade stays over-subscribed. The cost is the widened key type, a third authored identity field for legacy majors, a changed publish gate and an ownership assertion, and two legacy majors still fail together. Linked from D9's alternatives, OQ9 and OQ14.
