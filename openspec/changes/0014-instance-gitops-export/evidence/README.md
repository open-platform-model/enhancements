# Evidence for 0014

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0014/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 14 requirements, 4 decisions and 6 open questions of the old entry went, and the three requirements that moved in from 0013.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and the 2026-09-29 measurement of the fields a CLI-written instance carries are here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The file and line evidence for the pain.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the five-step approach, the field table, the integration points per file and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps six risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, versioning, deprecation, rollback and cross-repo notes.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions with their candidates.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. It holds the accept gates, among them the field-manager experiment that the proposal's fourth question needs.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. It holds the scope lists and the cross-reference table of files in other repos.
- [notes-for-accept.md](notes-for-accept.md): two clashes that the old requirement lines hold and one added sentence, for the owner at accept.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. Compilable CUE for the request, the gate chain, the field split, the exported set and the adoption property. CI runs `cue vet` here as a warning.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The other edits: the seven old document names inside the files now read as the new names, and links to other entries and to `INDEX.md`, `GRAPH.md` and `config.yaml` are plain names (they would not resolve from here). The original characters are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
