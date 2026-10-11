# Evidence for 0020

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0020/`), including its `config.yaml` with the old change history and its `depends_on` field.

- [migration-map.md](migration-map.md): where each of the 22 requirements, 12 decisions and 8 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and source is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The measurements of 2026-08-22 and the worked example of a flag day.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the goals, the affected surfaces per repo, the timeline sketch and the before and after.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps six risks as one line each, and the drawbacks live only here.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the diagnostics each refusal must name, the semver impact, the rollback and the cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the eight open questions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The criteria to move from draft to accepted.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the scope lists and the cross-reference table.
- [delivery-log.md](delivery-log.md): the old `delivery.yaml`, as a table. No repo change had landed, so no task line is ticked.
- [notes-for-accept.md](notes-for-accept.md): one clash that the old requirement lines hold, for the owner at accept.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the tombstone, the catalog map and the promotion field, the worked examples and the specification delta. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, one planned experiment (cross-level promotion). It was never run; the old text makes it a graduation gate.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edit: the names of the seven old documents inside the moved files now read as the new file names above, and the links of the old README to `INDEX.md`, `GRAPH.md`, `config.yaml` and the archived entries are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
