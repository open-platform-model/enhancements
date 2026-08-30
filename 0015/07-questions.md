# Open Questions: Catalog Contracts and Transformer Registration

## Open Questions

- **OQ1: How is a duplicate transformer within one contract bucket resolved?** Status: resolved-by-D5.
- **OQ2: Where does the default class get filled in?** Status: resolved-by-D2.
- **OQ3: How does a consumer reproduce a cluster's render when part of the registry lives in cluster state?** Status: resolved-by-D6.
- **OQ4: Does transformer-predicate stability need a rule beside 0010 D27?** Status: resolved-by-D7.
- **OQ5: What is the migration path when a contract is promoted between catalogs?** Status: deferred. To a future entry on contract aliasing/supersession in the identity keying (no entry filed yet; user decision 2026-08-21). Context for whoever files it: 0010 D47/D49 absorbed the experimental catalog into `catalog_opm` with version-segment filing, so first-party promotion shrank to an apiVersion bump inside one catalog. The cross-catalog flag day survives only for third-party adoption. An experimental contract graduating from `catalog_opm_experimental` to `catalog_opm` changes both the path segment and the `apiVersion`, so the FQN moves. Every consuming module changes an import and every provider adds a `requiredTraits` entry, in one flag day per contract. Under a design that expects a well-known contract set with an experimental on-ramp, this is a recurring cost rather than a one-off. There is no aliasing or supersession mechanism in 0010's keying. Possibly its own entry rather than a decision here.
- **OQ6: What is the blast radius of a registration change, and what does the store key become?** Status: answered. Overtaken by 0019 D8: the held store this question was asked of is deleted outright, so there is no key to re-design; the blast-radius residue transferred to OQ8 and is explicitly accepted in D13.
- **OQ7: Where is a registration refused when the provider requires a build the platform does not run?** Status: resolved-by-D8.
- **OQ8: What regenerates the platform package when the effective registry changes, and what keys it?** Status: resolved-by-D13.
- **OQ9: What does "comparable predicates" mean operationally? How is a duplicate detected?** Status: deferred, to D5's implementation slice. The full operational definition is over-specification at design time (user decision 2026-08-21). Filed 2026-08-20 from D5's guard.

  The slice inherits a measured starting point from the 2026-08-21 walk:

  - Candidate definition: pairwise subset over the three required maps (labels compared as key→value pairs), equality included, optional maps excluded.
  - Validated against catalog_opm's shipped 8-transformer `#ContainerResource` bucket, whose pairs are all incomparable (the five workload transformers disagree on `workload-type` values; service/hpa/pdb each carry a discriminating required trait), with the consequence that a fire-on-everything supplement would be refused.
  - Whatever definition the slice adopts, it must re-validate against the shipped bucket and land the check identically in the operator and `opm platform check`.

  The predicate has three required parts (`requiredLabels`, `requiredResources`, `requiredTraits`) plus optional maps. Open angles:

  - Pairwise subset comparison over which parts exactly (labels as key→value pairs; do optional demands participate?).
  - Whether predicate *equality* and strict subset are treated alike.
  - Whether the check is expressible as a pure CUE pairwise comprehension beside `#ContractRouting` or needs the glue.

  The constraint any answer must satisfy: the 8-transformer `#ContainerResource` bucket stays legal. Its discriminator is `requiredLabels` *values*, so detection must compare full predicates, never resource/trait sets alone.
- **OQ10: When does duplicate detection run?** Status: resolved-by-D5.
- **OQ11: How is ModulePackage readiness defined so registration activation cannot deadlock on itself?** Status: resolved-by-D14.
- **OQ12: May one module ship more than one registration?** Status: resolved-by-D15.
