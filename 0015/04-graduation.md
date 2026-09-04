# Graduation Criteria: Catalog Contracts and Transformer Registration

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not implementation milestones: delivery is derived from this entry's `delivery.yaml` log and read back with `task delivery`; the entry's documents store nothing about it.

## draft → accepted

Thirteen criteria must hold:

- **OQ3 is resolved.** Blocking, and the only one that is. D3 puts part of the effective registry in cluster state, which is in direct tension with 0010 D14's "the platform file is the lockfile". Whether a consumer reproduces a cluster render by exporting `Platform.status.registry`, by a controller writing accepted claims back to git, or by accepting the divergence, changes what `cli` builds and what 0014's export path can promise. Accepting the entry without it accepts a reproducibility regression by omission.
- **OQ9's deferral stands as written.** The guard's site is decided (platform-package generation, D5 resolving OQ10); OQ9 is deferred to the implementation slice with the measured candidate definition attached, and the slice must re-validate its adopted definition against the shipped 8-transformer bucket. (OQ1 is resolved-by-D5; OQ2 dissolved with the class rejection, resolved-by-D2.)
- **OQ4 is resolved or deferred.** If transformer-predicate stability gets no rule, the entry must say so, because "additive-only within a major" will otherwise be read as covering a guarantee it does not make.
- **OQ5 may remain open** if it names the entry that inherits it. OQ6 is answered: overtaken by 0019 D8; its blast-radius residue lives in OQ8.
- **OQ7 and OQ8 are resolved or explicitly deferred with a written reason.** Both were filed from 0019's OQ walk (its OQ10's refusal half and its OQ9). OQ7 in particular was deferred here because it needs experiments rather than argument, so resolving it likely means a concluded experiment under `experiments/`; OQ8 decides what the operator slice actually builds, so deferring it past acceptance would leave the D3 integration surface unspecified.
- Goals and Non-Goals in `02-design.md` are final and reviewed.
- Every decision D1..DN is locked and carries the four-field format.
- `schemas/target.cue` compiles (`cue vet ./...` from `schemas/` passes) and captures the target shape end-to-end, with every `// OQN:` marker either tightened or pointing at a still-open question.
- `config.yaml.semver` is set. Expected **major**: D1 adds required stamped members to `#Catalog`, landing inside 0010's core major window.
- `depends_on`, `supersedes`, `superseded_by` in `config.yaml` are final and resolve; every `depends_on` id is carried by a `**Depends:**` line in a live decision.
- **The ordering constraints are stated.** `affects` spans six areas with a real ordering constraint (`core` before `library` before `opm-operator`, and the catalog listing before any provider catalog), so `06-operational.md ## Cross-Repo Coordination` must state those constraints as design facts; landings are logged per change in `delivery.yaml`.
- No `{Capitalised}` placeholder strings remain in any markdown file.
- Cross-References table in `README.md` lists every file path the implementation will touch, and each exists today.
