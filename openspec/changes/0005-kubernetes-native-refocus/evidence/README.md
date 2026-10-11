# Evidence for 0005

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md` and `../design.md`. It has no `specs/` folder: the entry states a posture and no requirement. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0005/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 0 requirements, 3 decisions and 6 open questions of the old entry went, and where the rest of the old text went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and the measurement of 2026-09-29 is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The current state, the pain and the worked examples.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. The goals, the integration points per repo and the before and after examples.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. The observability, semver, deprecation, rollback and cross-repo answers.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the six open questions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The accept checklist of the new layout replaces it.
- [old-readme.md](old-readme.md): the old `README.md`, moved. Its scope lists and cross-references table are kept.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. Compilable CUE for the generation manifest, the lifecycle metadata block and the override field. CI runs `cue vet` here as a warning.

The edits to the moved files are these. In `contracts/` every em-dash character is replaced by a hyphen, to follow the workspace writing rule. In `decision-log.md` one link to the renamed `07-questions.md` now points at `questions.md`. In `old-readme.md` the links to `INDEX.md`, `GRAPH.md` and `config.yaml` became plain names, and the seven links to the numbered documents point at the new file names. The original characters and links are in git at the commit above. The old text uses decision numbers (`D1`) and question ids (`OQ1`); they are history here and appear nowhere in the proposal, design or tasks.
