# Evidence for 0024

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0024/`), including its `config.yaml` with the old change history and its `README.md`, which was written by hand.

- [migration-map.md](migration-map.md): where each of the 7 requirements, 6 decisions and 9 open questions of the old entry went.
- [cut-requirements.md](cut-requirements.md): the 2 old requirements that are not kept, both tombstones, each with its old text.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. It holds the research with its measurements (the testscript and txtar conventions of CUE, the negative idiom, the upstream module versions), every alternative and every rationale.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. It holds the table of today's coverage per repo and the worked example of the default-name change.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the goals, the non-goals and the affected surfaces per repo.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. Its gates for accept now live in the blocking questions of the proposal and in the first-corpus paragraph of the design.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each and the alternatives as rejected options.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, rollback and cross-repo order the design does not repeat.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions.

The moved files changed in one way only: links to the renamed documents (`03-decisions.md`, `07-questions.md`, `02-design.md`, `04-graduation.md`) now point at the new file names. The old text uses decision numbers (`D2`) and question numbers (`OQ5`); they are history here and appear nowhere in the proposal, design or specs. The old entry had no `delivery.yaml`, `schemas/`, `contracts/`, `experiments/` or `research/` folder, so none moves.
