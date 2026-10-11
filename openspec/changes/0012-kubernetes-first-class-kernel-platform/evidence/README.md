# Evidence for 0012

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0012/`), including its `config.yaml` with the old change history and its `depends_on` and `amends` fields.

- [migration-map.md](migration-map.md): where each of the 39 requirements, 8 decisions and 11 open questions of the old entry went.
- [cut-requirements.md](cut-requirements.md): the 11 old requirements that are not carried as requirements of their own: 9 name Go packages or hold a library-internal rule and go to the owning repo, 2 are tombstones of lines the owner withdrew. Each has its old text. The owner samples these lines before the cut binds.
- [delivery-log.md](delivery-log.md): the old `delivery.yaml`, as a table, and the list of shipped repo changes that the tasks tick beyond it.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale, source and revision note is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The file and line evidence for the duplication and the divergence, checked on 2026-07-27.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the rungs, the package table, the integration points per repo and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps six risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the signals, the semver impact, the deprecations, the rollback and the cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the 11 open questions and their resolutions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The criteria to move from draft to accepted.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the scope, the out-of-scope list and the cross-reference table of files.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. Compilable CUE for the ownership vocabulary, the inventory wire shape, the deletion policy, the verdicts and the owner-reference predicate. CI runs `cue vet` here as a warning.

The old entry had no `experiments/`, `research/` or `schemas/` folder.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edit: the names of the seven old documents inside the moved files now read as the new file names above, and the three links of the old README to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
