# Risks, Drawbacks, Alternatives: Module-Dictated Catalog Versions and the Generated Platform

Risks describe what could go wrong. Drawbacks describe what definitely costs something. Alternatives describe the high-level paths not taken; per-decision detail lives in `03-decisions.md`.

## Risks and Mitigations

- **A fleet fragments across many catalog releases.** Without a platform pin, forty modules may sit on ten different releases of one catalog, each running that release's transformer bytes. A transformer fix reaches an instance only when its module bumps or the floor rises above it. **Mitigation:** the floor is required and raising it refuses every laggard by name (D2), so the platform team always has a fleet-wide lever; the held versions are recorded per render (D1, OQ1), so the spread is visible before it is a problem.
- **The readiness answer weakens.** 0015 D1's inventory and the module-less readiness build evaluate at reference versions (OQ3). A module pinned above the floor may demand a contract the inventory at the floor never listed, so "unfulfilled" and "unknown key" are exact only at those versions. **Mitigation:** the diagnostic states the reference version it evaluated at; the render build itself still holds the module's version and reports the true answer for that instance.
- **The platform team widens past the author's claim and the operator rejects the rendered CRs.** D6 allows a spec range wider than the provider's window. **Mitigation:** the widening is a warning condition on the registration naming both bounds, attributable to the spec commit and reversible by deleting the entry; the author's claim survives as the baseline.
- **Per-resolution platform generation thrashes on a churning fleet.** Every distinct resolved set is a generated platform; a spec change or an accepted registration invalidates them. **Mitigation:** generation is keyed by the resolved set and shared across renders with the same resolution (D3); the cost is unmeasured and filed as OQ5 rather than assumed away.
- **Ordering checks live outside CUE and drift from the schema.** Floor and ceiling are `#VersionType` strings; CUE cannot compare them, so `floor <= pin <= ceiling` is a kernel check the schema cannot express. **Mitigation:** the spec-level facts CUE can check are checked in CUE (shape, major matching the path); the ordering rules are stated as contract in D2 and tested by the kernel's own fixtures.

## Drawbacks

- **The platform team loses the ceiling by default.** An absent ceiling admits every release of the major at or above the floor, so a module can pull transformer bytes newer than the platform validated. A team that wants validation before admission must author a ceiling and edit it per release.
- **The provider claim gains its first authored field.** 0015 D11's "every field derived or stamped" no longer holds for the window. The trust argument moves from derivation to the RBAC gate the CR already rides.
- **Two more things to explain.** A platform operator now reads a spec, a registration's claim and a registration's status to know what binds a provider catalog. The status carries `source` to keep that readable, but it is three surfaces where 0015 had one.
- **0019 D6's cold path is gone.** Platform generation runs per resolution rather than per CR change. The set stays small in practice, but "generated once" is no longer a property anyone can state.

## Alternatives

- **Platform-exact with a better skew diagnostic.** Keep 0019 D13 and improve the report. **Why not:** the report cannot act; the render list is derived before it is written, and Gaps 1 and 2 stand.
- **Platform floor, module raises, maximum-version selection resolves.** The platform's pin becomes a floor and CUE's resolver picks the higher of platform and module. **Why not:** a pin below the floor is promoted silently, and 0019 D13 measured that involving the resolver is where authority fails by omission.
- **Module-exact with no platform range.** The module's pin is the version, the platform only lists majors. **Why not:** no fleet-wide lever at all; a transformer fix waits on every module author, the Helm chart-library failure.
- **Ranges on the authored `#CatalogEntry`, platform module kept.** **Why not:** the entry embeds an import whose version cannot float; a range on it describes nothing.
- **Ranges in the platform module's `cue.mod` custom block.** **Why not:** keeps the platform an authored CUE module with two authored forms, which generation removes; the block survives tidy and would work, and D2's alternatives keep it on record.
