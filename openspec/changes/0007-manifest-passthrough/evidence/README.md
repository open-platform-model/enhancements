# Evidence for 0007

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0007/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 12 requirements, 5 decisions and 7 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative and rationale is here, with the D2 measurement of 2026-09-29.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The current state, the pain and the worked example.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the affected files per repo and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps six risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. Observability, semver impact, deprecation, rollback and cross-repo order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the 7 open questions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The old draft-to-accepted gates, replaced by the accept checklist of the new layout.
- [scope-and-references.md](scope-and-references.md): the Scope and Cross-References sections of the old `README.md`, moved word for word. The list of repo files the implementation touches.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. Compilable CUE for the declared source shape and the provenance marker. CI runs `cue vet` here as a warning.

There is no `cut-requirements.md` and no delivery log: all 12 requirements are kept, and the old entry had no `delivery.yaml`.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits: one link to the renamed `07-questions.md` now points at `questions.md` (in `decision-log.md`), and one link to enhancement 0005 became words (in `scope-and-references.md`). The original characters are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
