# Evidence for 0027

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0027/`), including its `config.yaml` with the old change history and its `depends_on` field.

- [migration-map.md](migration-map.md): where each of the 30 requirements, 11 decisions and 26 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and measurement is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The current state, the three gaps and the worked example.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the CUE sketch of the declaration, the affected surfaces per repo and the before and after examples.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the signals, the semver impact, the rollback and the cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the 26 open questions, with the full candidate answers and measurements.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The six gates to move from draft to accepted, including the prior-art comparison.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the scope lists and the cross-reference table.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the core-schema delta (the definition shape, the instance shape and the projection) and the worked examples. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, six experiments and their shared harness behind the served-schema questions: the stock encoder against the real fleet, offline against live validation, and the secret, union, required-field and presentation measurements.

The old entry had no `delivery.yaml` and no `research/` folder, so there is no delivery log. No repo change of 0027 has shipped, so `../tasks.md` has no ticked line.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule (one line of `schemas/cue.mod/module.cue`). The only other edits: the names of the seven old documents inside the moved Markdown files now read as the new file names above, a CUE comment in `schemas/target.cue` names `questions.md`, and the three links of the old README to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D1`), question numbers (`OQ1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
