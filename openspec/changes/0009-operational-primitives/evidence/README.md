# Evidence for 0009

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0009/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 25 requirements, 10 decisions and 7 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative and rationale is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The gap, the migration example and why the workarounds fail.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the integration points per repo and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, versioning, rollback and cross-repo order the design does not repeat.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions and their status.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The gates the old text set for accept.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the park banner, the scope per repo and the cross-reference table.
- [delivery-log.md](delivery-log.md): the old `delivery.yaml`, as a table.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the four constructs, the worked examples and the specification delta. CI runs `cue vet` here as a warning.
- [research/](research/): the old `research/`, the dated note on how durable CUE attributes are.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits: the old document names inside the files read as the new names, three links in `old-readme.md` to INDEX, GRAPH and config.yaml are plain names, and one link in `questions.md` to the old folder of entry 0012 is plain text. The original characters are in git at the commit above. The old text uses decision numbers (`D10`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
