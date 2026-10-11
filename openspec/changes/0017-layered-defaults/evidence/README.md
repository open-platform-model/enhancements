# Evidence for 0017

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0017/`), including its `config.yaml` with the old change history and its `depends_on` field.

- [migration-map.md](migration-map.md): where each of the 23 requirements, 8 decisions and 5 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and source is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The file and line evidence for the pain, and the failing example.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the compatibility clauses C1 to C3, the integration points per repo, and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps six risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the signals, the semver impact, the deprecations, the rollback and the cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the five open questions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The criteria to move from draft to accepted, including the experiment and the fixture matrix the open questions need.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the per-repo scope, the out-of-scope list and the cross-reference table of files and issues.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the core delta (the optionality-aware component projection), six assertion pins, and the specification delta. CI runs `cue vet` here as a warning.
- [notes-for-accept.md](notes-for-accept.md): two points for the owner at accept: the parity divergence, and `breaking`.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. The layer contract L1 to L6 as rule data, and the blueprint narrowing idiom. CI runs `cue vet` here as a warning.

The old entry had no `delivery.yaml`, `experiments/` or `research/` folder, so there is no delivery log. The two repo changes that shipped are ticked in `../tasks.md` by commit, because neither had an OpenSpec change or a pull request number that the repos record.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edit: the names of the seven old documents inside the moved files now read as the new file names above, and the three links of the old README to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
