# Evidence for 0004

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0004/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 13 requirements, 13 decisions and 6 open questions of the old entry went.
- [notes-for-accept.md](notes-for-accept.md): two points for the owner at accept: the release cascade premise, and two repos outside the closed list.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative and rationale is here. D1, D2, D3 and D4 are the superseded decisions of the first, Renovate-based design: D1 and D2 are replaced by D7, D3 by D8 (its mechanism, not its property), D4 by D9. They stay here with their reasons.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The pain with the current workspace task.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the goals, the integration points per repo and the before and after example.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the rollout order, rollback, deprecation and semver notes.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of six open questions, all closed.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The seven gates for `draft` to `accepted` in the old layout.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word, with its links pointed at the files of this folder. It holds the scope lists and the cross-reference table of the files each repo would touch.
- [research/](research/): the old `research/findings.md`, a measurement of where the CUE modules sit in each repo (2026-09-29).
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. Compilable CUE for the function signature, the registries that need credentials and the pull-request settings. CI runs `cue vet` here as a warning.

There is no delivery log: the old entry had no `delivery.yaml`, and a scan of the sibling repos on 2026-10-11 found no change that delivers any part of it.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits are links: references to the renamed `03-decisions.md` and `07-questions.md` now point at `decision-log.md` and `questions.md`, and the links of the old README point at the files of this folder. The original characters are in git at the commit above. The old text uses decision numbers (`D10`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
