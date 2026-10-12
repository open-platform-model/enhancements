# Source note: seed-catalog-acquisition

This is a seed. It records behaviour the library ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `catalog-acquisition`. Full seed (6 requirements). Written 2026-10-11 from `library` at commit `a87fdda`. The text is rewritten at intent level: no Go symbol, field path, sentinel name or file path in a requirement. No published CUE definition is named, and no Kubernetes kind.

## Sources

All read at the commit named. The repo spec is `library` `openspec/specs/catalog-acquisition/spec.md` (4 requirements; last changed in `893c670`).

| Requirement here | Source requirement in the library spec | Code read |
| --- | --- | --- |
| A catalog is acquired by path and version | "Catalog acquisition from a registry and from a directory", registry half | `opm/kernel/acquire.go:217` (acquire from a registry); `opm/internal/loader/registry.go:96-146` (version spelling, in-memory staging, fetch failure) |
| A catalog is acquired from a directory | same requirement, directory half | `opm/kernel/acquire.go:256`; test `opm/kernel/acquire_catalog_test.go` (`TestKernel_AcquireCatalogFromDir_Subpackage`: module root and package place) |
| A non-catalog artifact is refused by shape | "A non-catalog artifact is refused by shape" | `opm/internal/loader/shape.go:105` (the catalog gate), `:180` (kind check), `:207` (concrete identity; a disjunction with a default is not concrete, `:199-215`, so a defaulted catalog version is refused as a missing required field) |
| A catalog reports its provider-fulfilled contracts | "The provider-fulfilled contract set is derived from the catalog", the report, order and fallback sentences and their scenarios | `opm/catalog/provides.go:57-124` |
| An unreadable provider set is an error | same requirement, its error sentence and two scenarios | `opm/catalog/provides.go:57-124` |
| A catalog's committed requirements are readable | "The catalog's committed dependency requirements are readable" | `opm/catalog/requires.go:40-58` |

The spec has 4 requirements and the seed has 6. Two requirements of the spec hold more than 500 characters of rule, so the registry and directory halves are two requirements, and the provider-set report and its error causes are two.

## Disagreements between spec and code

The code wins.

- The spec says acquisition gates the concrete kind only. The gate also requires a concrete module path and a concrete version in the catalog's metadata (`shape.go:105-108`), and a missing one is refused as a missing required field, not as the wrong kind. The seed states this in "A non-catalog artifact is refused by shape".
- The spec does not say that a version may be written bare or with a leading v. The code accepts both and fetches one tag (`registry.go:99`; test `TestKernel_AcquireCatalogFromRegistry`). The seed states it. The library spec `registry-module-loading` holds the same fact; it is not seeded.
- The spec names the cue context of each call (ADR-007) and the reuse of the module fetch routine. Neither is observable by a consumer. The seed leaves both out.

## Where this capability touches the other seeds

- `registration-acceptance` (archived): "The claimed artifact must be a catalog" and "The provider set is re-derived and compared" are the operator's verdicts. They use what this capability reports: the wrong-kind refusal and the provider-fulfilled list. This seed states how the kernel reads and what it reports, and no verdict. It does not restate the refusal of a claim or the exact-equality comparison.
- `catalog-contracts`: "A catalog derives the provider-fulfilled contracts it implements" holds core's derivation rule (what counts: required demands, not optional ones, not catalog-fulfilled ones; the list is sorted and has no duplicates; an authored list that disagrees fails). This seed states only how the kernel reads that list, when it falls back to the transformers, and what makes the read an error. It says "the same list" and does not restate the rule.
- `single-build-render`: the render's need for a source-carrying input and its dependency promotion stay there. This seed states that an acquired catalog carries its source and a requirement reader; it states no render rule.
- `platform-registry` and `platform-module-generation`: a registry key must match its catalog's declared path, and a generated entry stamps the catalog's version. Those are platform rules. This seed makes no such check at acquisition (see "Left out").
- `platform-artifact` (not yet written): it takes the acquisition-time refusal of a wrong-shaped platform (DECISIONS.md 2026-10-11 08:10). The shape gate here is the catalog's own.

## Left out

- The deprecation of the fallback that derives the provider list from the transformers, and its removal before GA. It is a plan for a mechanism, not a rule a consumer observes. The fallback itself is in the seed as behaviour.
- The core release number from which core derives the provider list. A consumer sees "older core", not the number.
- The reuse of the module fetch routine, the one shape-gate routine, and the per-call evaluation context (ADR-007 and ADR-009): library-internal placement rules that no consumer observes (brief).
- A catalog built straight from a value, not acquired: the code reads its provider list from the field when present and derives it otherwise (its core is unknown), and it has no source, so its requirements cannot be read. Neither half is in the seed: no requirement states the rule and the spec does not describe it (T4.R22 removed the scenario that did); no consumer of acquisition reaches it.
- That a registry-fetched catalog's declared module path is not compared with the coordinate fetched. The code comment says so (`acquire.go`, doc comment of the registry route); no spec text or test states it. Registration and platform build check the path where it matters.
- Classification of a fetch failure (not found, unreachable, unauthorised): library spec `fetch-error-classification`, not seeded (library internals, DECISIONS.md 2026-10-11 06:40).
- Behaviour a live entry owns: none found (T4.1b row 23). 0015 D8, D11 and D12 shipped the acceptance side in the operator. 0026 changes how acceptance compares build compatibility (own major), not how the kernel reads a catalog. 0019 D18 defines the committed-resolution comparison; the comparison is the consumer's.
- Everything of 0006 that 0021 changed: none of it touches this capability.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "A catalog reports its provider-fulfilled contracts" keeps the kernel's read (from the catalog, else derived, and the empty list without an error). The properties of the list (sorted, without duplicates, which demands count) are `catalog-contracts`'s; the sentence and the scenario "Two reads of one catalog are equal" are gone, and the first scenario says the list equals the one core derives.
- Not a duplicate, kept: the module-root rule of "A catalog is acquired from a directory" and the platform seed's rule for a platform directory read the same way, but each source spec states it for its own artifact kind (catalog, platform). The same holds for the registry mapping and the wrong-kind refusal, stated in `platform-artifact` for platforms.

sampled: 2026-10-11 18705155
