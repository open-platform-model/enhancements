# Enhancement 0026: Module-Dictated Catalog Versions and the Generated Platform

A platform is the cluster-side declaration of which catalogs a render may use, and today it pins one exact version of each. Every module then renders against that pin, whether or not it is the version the module's author tested, and a module that needs a newer definition has to wait for a platform edit. This entry splits that one number into the two jobs it was doing. The platform admits a catalog lineage, meaning a catalog path at one major, and bounds it with a required lowest version and an optional highest one. The module's own committed pin then picks the version inside that range, and a pin outside it is refused by name rather than quietly promoted.

All entries: [INDEX.md](../INDEX.md). How this one relates to others: [GRAPH.md](../GRAPH.md). Metadata: [config.yaml](config.yaml).

## Summary

**Admission is the platform's, selection is the module's (D1, D2).** The platform authors a pure-data spec: for each catalog lineage it admits, a required floor, the lowest version accepted, and an optional ceiling, the highest. A module's committed catalog dependency is the version its render holds, provided that version lies inside the range. Outside it, the render is refused, naming the module, the path, the pin, the bound and whose bound it was. Raising the floor is therefore a loud fleet-wide lever: it stops the instances below it rather than moving them.

**A spec entry admits and bounds, and never loads a catalog (D4).** The spec has no dependencies and imports nothing, so the same fields serve as a cluster resource's spec and as an offline file for the CLI.

**The platform value is generated, and its shape does not change (D3).** For each render the kernel builds a platform module from the spec plus the module's pins: one import and one registry entry per catalog. That value is today's platform definition, unchanged, so nothing downstream learns anything new. Two renders with the same resolved set share one generated platform, and a fleet clusters on a handful of catalog releases, so the set stays small. The offline and cluster authoring forms converge on the one spec.

**Provider catalogs follow the same rule (D5, D6).** A provider is a module that registers transformers, and its own catalog pin already fixes the version its registration carries. That version is the pick for any render that does not pin the provider's catalog itself. The registration gains a window, a floor and a ceiling that default to that exact version. A platform spec entry for the provider's catalog path is optional; when present, its range replaces the author's window, and the registration's status reports which window is in effect and where it came from.

**The shared-path check runs twice (D7).** When two catalogs must agree on a path, the requirement is checked per render against the consumer's pins, and at acceptance time against the platform's floors.

**Nothing else moves (D8).** Matching, the derivation of the transformer set, who holds admission authority, and provider routing are all unchanged.

## How it works

```mermaid
flowchart TD
    spec["Platform spec, authored data: catalog lineages by path with major, required floor, optional ceiling"] --> kernel
    pins["Consumer module's committed pins, plus the tidied closure"] --> kernel
    reg["Accepted provider registrations: each catalog at its version, inside the provider's window"] --> kernel
    kernel["Kernel: for each catalog the module imports, is the path admitted and the pin inside the range?"] --> refuse["No: refuse by name, naming module, path, pin, bound and whose bound it was"]
    kernel --> gen["Yes: generated platform module, one import and one registry entry per catalog"]
    gen --> build["One render build"]
    build --> rendered["Rendered objects, with the catalog versions held recorded"]
    gen -.-> share["Shared by every render with the same resolved set"]
```

The tidied closure is the module's full committed dependency list, the one the render already promotes into its build. Nothing is resolved at render time: no tidy runs, no registry is consulted, and no highest-version selection happens. What changes is only which file supplies the version on a catalog path, and what the kernel does when that version falls outside what the platform admits.

## Documents

1. [01-problem.md](01-problem.md): one platform pin admits a lineage and picks every instance's version at once, and the two jobs conflict as soon as two modules want different releases
1. [02-design.md](02-design.md): a pure-data platform spec with ranges, module pins as the held version, a generated render-time platform, and the same rule for provider catalogs
1. [03-decisions.md](03-decisions.md): the decision log, D1 to D8
1. [04-graduation.md](04-graduation.md): what must hold before `draft` becomes `accepted`
1. [05-risks.md](05-risks.md): risks, drawbacks, alternatives not taken
1. [06-operational.md](06-operational.md): rollout, versioning, rollback, cross-repo ordering
1. [07-questions.md](07-questions.md): the open-questions register, OQ1 to OQ6

Compilable CUE lives in [`schemas/`](schemas/): the core-schema delta, the example instances whose unification is the test, and the specification delta.

## Scope

### In scope

- The platform spec and its subscription entries in `core`: a lineage by path with its major, an enable flag, an optional registry override, a required floor and an optional ceiling (D2). No existing core definition changes shape.
- The source of a catalog version in the render list: the module's committed pin, admitted by the spec and refused by name outside the range (D1, D2). The build records the catalog versions it held.
- Per-resolution generation of the unchanged platform value from spec plus pins, and the convergence of the offline and cluster authored forms on the spec (D3).
- The registration window: a floor and a ceiling on the registration contract, defaulting to its exact version, plus the optional spec entry that overrides it. The effective window and its source are reported in the registration's status (D5, D6).
- The shared-path requirement check, per render against the consumer's pins and at acceptance against the floors (D7).

### Out of scope

- A change to matching, to the transformer set, or to which catalogs a platform admits. Admission stays with the platform spec and the access-gated registration.
- Provider routing, classes and capability-based selection: successor material to the one-provider-per-contract rule of entry 0015 (0015:D2).
- Floating an instance forward within a range without an owner's act. That waits on entry 0021's compatibility answers and belongs to a later entry.
- Module-hosted transformers. The ruling that transformers never ship inside a module artifact stands (0015:D10).
- Generating the Platform custom resource definition from the spec, which is entry 0008's route. This entry states the spec's shape, not how that definition is produced.
- Self-service kinds over published modules, which is entry 0025 and reuses this entry's range vocabulary.

## Deviations from Design

None at this stage. Update this section when implementation lands and any
deliberate divergences from the design need to be documented.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `enhancements/0019/` | The single-build render pipeline this entry is baselined on: embedded catalogs (D5), the operator-generated platform package (D6), and the promotion rule whose catalog-path source this entry changes (D13) |
| `enhancements/0015/` | The provider half this entry extends with a window and an optional spec override: the registration resource (D3), its derived claim (D11), the shared-path comparison (D8) and the contract inventory (D1) |
| `enhancements/0010/` | Identity is the module path with its major (D1); the committed platform module is the resolution (D14); evolution inside a major is additive (D27) |
| `enhancements/0021/` | The module compatibility surface, and the concrete case of a patch release orphaning a claim; it gates any future in-range floating |
| `enhancements/0008/` | CUE-native CRD schemas: the route from the platform spec to the Platform custom resource definition |
| `enhancements/0025/` | Self-service kinds, the consumer of this entry's range vocabulary for an offering's update policy |
| `core/src/platform.cue` | The shipped platform and catalog-entry definitions this entry keeps unchanged and generates |
| `core/src/module_instance.cue` | Why core injects nothing tied to a catalog contract, the reason the registration window is not injected into a module's configuration schema |
| `CONSTITUTION.md` (per target repo) | Core design principles governing changes in each touched repo |
