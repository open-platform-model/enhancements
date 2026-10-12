# 05-major-as-matching-scope: Module-Dictated Catalog Versions and the Generated Platform

Status: Concluded

## Hypothesis

If contract keys stay shared across majors and the contract inventory is keyed by the pair of key and declaring major, with the major derived from fields every published primitive already carries, a platform holding two majors of one catalog evaluates, counts providers per declaring major and reports comparability per major. This is D9's second rejected alternative, the major as a matching scope.

## Setup

Copied, unmodified, from `core/src/` at commit `cbe93e0` (release `2.0.0-alpha.12` plus two comment-only commits): `types.cue`, `transformer.cue`, `catalog.cue`, `identity_package.cue`, `component.cue`, `module.cue`, `module_context.cue`. The last three are only the closure `#Component` needs for one refused case.

Copied from the same commit and patched; `core.patch` is the exact diff and applies to core at `cbe93e0` with `git apply core.patch`:

- `resource.cue`, `trait.cue`, `blueprint.cue`: a derived, never authored `metadata.catalog`, the declaring catalog's module path with its major, computed from `modulePath` (with `/<kind>/<apiVersion>` trimmed) and the major of `catalogVersion`.
- `platform.cue`: `#ContractInventory` and the `#contracts` fold keyed by key and then scope: `defined`, `definedBy`, `requiredBy` and `providedBy` gain a scope level, `unfulfilled` and `overSubscribed` become `{contract, scope}` rows, `comparable` rows carry a scope and pairs are compared only inside one (key, scope) bucket. A transformer demand's scope is the `metadata.catalog` of the value it requires.

Added in `probe/`:

- `members.cue`: one member source instantiated as opm@v4 (4.2.0) and opm@v5 (5.0.0), sharing the container and provider-fulfilled backup keys; a provider template; opm@v5 with a bridge transformer requiring opm@v4's container; an identity-skewed build (path opm@v4, version 5.1.0).
- `platforms.cue`: s1 (both majors, no provider), s2 (k8up@v2 on opm@v4, k8up@v3 on opm@v5), s3 (a provider for opm@v4 only), s4 (two providers on opm@v4), s5 (the bridge), s6 (one k8up@v4 build with one transformer per major), s7 (the skewed build).
- `gate.cue`: the shipped publish gate on the shared, major-free key.
- `case_refused.cue` (`-t refused`): one component carrying both majors' copy of one key, and a leaf authoring a wrong scope.
- `report.cue`: gathers the measured fields.

Experiment 09 renders the same design through the real library with a patched render glue.

## Run

From `probe/`, with cue v0.17.1:

```bash
cue vet -c=false .              # every untagged case evaluates
cue export -e report .          # derived scopes, gate, s1 to s7
cue vet -c=false -t refused .   # the two cases expected to fail
```

## Outcome

Measured 2026-09-30, cue v0.17.1. Keys below drop the `opmodel.dev/catalogs/` prefix.

- **Derived scope.** 4.2.0 gives `opm@v4`, 5.0.0 gives `opm@v5`, and the dev build 5.0.0-dev.3 gives `opm@v5`. The shipped gate still accepts the shared key `opm/resources/container@v1beta1`.
- **s1, both majors define the same keys: evaluates.** `definedBy` is `{opm/resources/container@v1beta1: {opm@v4: opm@v4, opm@v5: opm@v5}, ...}`, `requiredBy` for the container is `{opm@v4: [opm/transformers/deployment-transformer@4.2.0], opm@v5: [opm/transformers/deployment-transformer@5.0.0]}`, `comparable` is empty and `discriminated` is `true`. The same shape under the shipped fold fails to evaluate (experiment 01, case A).
- **s2, one provider per declaring major: routable.** `providedBy` is `{opm/traits/backup@v1alpha1: {opm@v4: [k8up@v2], opm@v5: [k8up@v3]}}`, `overSubscribed` empty, `fulfilled` and `routable` `true`. Under the shipped fold this pair is over-subscribed (experiment 02).
- **s3, a provider for opm@v4 only.** `unfulfilled` is `[{contract: opm/traits/backup@v1alpha1, scope: opm@v5}]`.
- **s4, two providers both built on opm@v4: over-subscribed.** `overSubscribed` is `[{contract: opm/traits/backup@v1alpha1, scope: opm@v4}]`, `routable` `false`.
- **s5, a bridge in opm@v5 requiring opm@v4's container: reported, not refused.** `requiredBy` puts the bridge in the opm@v4 bucket beside opm@v4's own transformer, and `comparable` is `[{broader: opm/transformers/deployment-bridge-transformer@5.0.0, narrower: opm/transformers/deployment-transformer@4.2.0, scope: opm@v4, ...}]`, `discriminated` `false`.
- **s6, one k8up@v4 build with one transformer per major: routable.** `providedBy` maps both scopes to `[k8up@v4]`.
- **s7, identity skew (path opm@v4, version 5.1.0): evaluates**, with `definedBy` `{opm@v5: opm@v4}`: the scope follows the version's major, not the path's.
- **Refused.** One component carrying both majors' copy of the container conflicts on `catalogVersion` ("5.0.0" and "4.2.0"); a leaf authoring `metadata.catalog: "opmodel.dev/catalogs/opm@v5"` on an opm@v4 primitive conflicts with the derived value.

**Hypothesis held.** Scoping by the declaring major lets two majors evaluate, count providers per major and report comparability per major with no key change. The cost is that every consumer of the inventory changes shape (a scope level on four maps, rows instead of keys on two lists), the scope is derived by string surgery on provenance fields, and provenance (`catalogVersion`'s major) becomes part of matching. Linked from D9's alternatives, OQ9 and OQ14.
