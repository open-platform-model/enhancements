# Evidence for 0026

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0026/`), including its `config.yaml` with the old change history and its `depends_on` and `amends` fields.

- [migration-map.md](migration-map.md): where each of the 36 requirements, 9 decisions and 18 open questions of the old entry went.
- [notes-for-accept.md](notes-for-accept.md): the calls the conversion made, for the owner at accept.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and measurement is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The current state and the gaps.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the before and after tables.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the rollout, rollback, deprecation and cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the 18 open questions, with the full candidate answers and measurements.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The gates to move from draft to accepted.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the summary and the cross-reference table.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the authored platform, the example instances and the specification delta. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, nine runnable experiments behind the side-by-side majors.

The old entry had no `delivery.yaml` and no `research/` folder, so there is no delivery log. One repo change that names 0026 has shipped, `index-build-compat-by-major` in `opm-operator`, and `../tasks.md` ticks it.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits: the names of the seven old documents inside the moved files now read as the new file names above, a CUE comment in `schemas/target.cue` names `questions.md`, and the three links of the old README to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D1`), question numbers (`OQ1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
