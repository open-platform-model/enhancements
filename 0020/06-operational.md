# Operational Concerns: Contract Promotion and Retirement

OPM's Production Readiness Review (PRR-lite): five fixed prompts, each answered below.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Three new publish-time refusals, each of which must name the member and the two builds involved rather than reporting a bare failure:

- **Incompatible promotion** (D2) names the promoted key, the `promotedFrom` key, the predecessor build, and the path that broke. The comparator already produces path-located violations (`s.b: field removed`, `t: default changed ("a" -> "b")`), so the diagnostic shape is inherited.
- **Promotion carrying a shape change** (D3) names the member and the differing paths, and says explicitly that the fix is two builds rather than one.
- **Removal without a tombstone** (D6) and **dropped tombstone** (D7) both name the key, the build that last published it, and the fact that a tombstone is the remedy.
- **Seasoning floor not met** (D10) names the replacement, the build it first appeared in, and the shortfall.

Two gates produce their diagnostics through CUE rather than through Go, following the pattern enhancement 0011 D21/D22 established: `#PromotionGate` and `#TombstoneGate` are unified against and the author reads CUE's own error. Both must be unified into a non-hidden value, since `cue vet -c` does not check hidden fields.

One consumer-side diagnostic is possible and deliberately left open: a `MissingFQN` for a key the catalog's `#removed` map explains could report when it went and what replaced it. Whether that reaches the match rung or stays in `opm platform check` is OQ5.

A lifecycle report (level census plus outstanding tombstone seasoning) is the natural aid to ship alongside, following enhancement 0010 D35's precedent that a check command is an aid and not a guarantee. It depends on enhancement 0015 D1 for enumeration. Shape is OQ8.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

**No.** Every schema change is additive: a new definition (`#Tombstone`), a new optional map on `#Catalog` (`#removed`), a new optional metadata field on three primitives (`promotedFrom`), and two new gate definitions. `config.yaml.semver` is `minor`.

`opmodel.dev/core` is on `@v2` shipping `v2.0.0-alpha.N` prereleases, so this lands as an alpha increment within the major; no major bump, and no republish is forced on any existing catalog or module. A catalog that never promotes and never removes anything is unaffected by every rule here.

The new *rules* are not additive in the same sense: D6 refuses a build that a previous release of the tooling would have accepted. That is a behaviour change in `opm catalog publish` rather than in the schema, and it binds only builds that remove a beta or GA member, which is the case the rule exists to catch. Catalogs that have already removed members in past builds are not retroactively refused, because the gate compares this build against its predecessor rather than auditing history.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. This entry adds a vocabulary for removal; it does not exercise it on any existing definition.

The one thing it changes in character is the meaning of a level: after this lands, `v1beta1` means "beta, and the author may not withdraw it faster than D10's floor" rather than "beta, withdrawable at will". That is a strengthening of an existing published promise, not a deprecation of one.

`catalog_opm`'s first real promotion is expected to be the proof case, and it will exercise D4's dual-shipping and eventually D6's tombstone against a live fleet. That first promotion is a deliberate rehearsal, not a migration: no consumer is required to act at any point in it.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Clean, and in two independent halves.

The **schema** half rolls back by consumers pinning the previous `core` alpha. Because every addition is optional, a catalog authored against the new schema still validates against the old one, minus the gates. Published artifacts carrying `#removed` or `promotedFrom` remain readable by an older `core` that ignores the fields, since the maps are additive and the primitives' metadata is open.

The **gate** half rolls back by reverting the CLI: `opm catalog publish` stops running the new checks and nothing already published becomes invalid. Enhancement 0011 D10 makes published artifacts immutable, so a tombstone published under the rule stays published and stays truthful whether or not the rule is still enforced.

No cluster state changes. Nothing in this entry reaches the operator, the render path, or a live instance; D12 puts the dependent-side protection explicitly out of scope.

The one thing that does not roll back is a **withdrawal**: if a catalog tombstones a key and the rule is later relaxed, the key is still gone. That is a property of enhancement 0011 D10's immutability rather than of this design, and it is the reason D10's floor exists.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

Four ordering constraints, each a design fact rather than a schedule.

1. **Enhancement 0015 D1 before a value-level inventory, and not before anything else.** Measured 2026-08-22, member enumeration for the publish gates is a filesystem walk over enhancement 0010 D49's `<kind>/<apiVersion>` filing, reading a fetched published build through the same interface as a working tree; the value walk was rejected precisely because `#Catalog` exposes only `#transformers`, which reach about half the members and no blueprints. So D2, D3, D6, D7 and D10 are all deliverable before 0015 D1 lands. What waits on it is a consumer-readable contract inventory: the lifecycle report of OQ8, and any answer the operator or `opm platform check` must give without a filesystem in hand.

2. **`core` before `library`.** The gates and the `#Tombstone` shape are the contract `library` compares against; the comparator cannot be written against a schema that does not exist.

3. **`library` before `cli`.** The cross-build rules live in `opm/compat` so that `opm catalog publish`, `opm catalog registry check` and any CI action share one implementation. This is the same argument enhancement 0010 D32 used for placing its guard in the kernel and 0011 D9 used for placing the comparator there.

4. **`cli` before `catalog_opm`'s first promotion.** The proof case is only a proof if the gate is running when it publishes.

`opmodel.dev` follows the shipped behaviour and constrains nothing.

The upstream artefact at each hand-off is concrete: `core` produces the published `opmodel.dev/core` alpha carrying the new definitions; `library` produces the exported comparator entry points in `opm/compat`; `cli` produces the wired gates in `opm catalog publish`.
