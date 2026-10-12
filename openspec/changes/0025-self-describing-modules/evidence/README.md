# Evidence for 0025

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0025/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 18 requirements, 15 decisions and 16 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. D1 to D10 are tombstones that point at entry 0027. D11 to D15 hold every alternative and rationale, and the measured probe of 2026-09-29.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. It holds the current state, the three gaps, the worked example of a module that wants to say what it is, the user stories and the workarounds that fail.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the goals, the non-goals, the affected surfaces per repo and the before and after examples.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. Its four gates for accept: one is the blocking question of the proposal, and two unmet ones are in `notes-for-accept.md`. The map lists where each went.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each and the alternatives as rejected options.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, versioning, rollback and cross-repo order the design condenses.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions. OQ1 to OQ12 and OQ16 belong to entry 0027.
- [notes-for-accept.md](notes-for-accept.md): two things the owner checks at accept, from the old graduation gates. They are notes of the conversion, not old open questions.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the summary, the diagram, the scope lists and the table of cross-references to files of other repos.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the aspect, the module trait and the module transformer, a worked module with three aspects, two instances and a transformer run, and the specification delta. CI runs `cue vet` here as a warning.

One change to the moved files: the one em-dash character in `schemas/cue.mod/module.cue` is replaced by a hyphen, to follow the workspace writing rule. The only other edit: the names of the old documents inside the moved files now read as the new file names above, and the links of the old README to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names. The original characters and names are in git at the commit above. The old text uses decision numbers (`D11`) and question numbers (`OQ13`); they are history here and appear nowhere in the proposal, design or specs.

The old entry had no `delivery.yaml`, `contracts/`, `experiments/` or `research/` folder, so none moves, and no repo change of 0025 has shipped.
