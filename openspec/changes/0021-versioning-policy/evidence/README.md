# Evidence for 0021

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0021/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 57 requirements, 11 decisions and 17 open questions of the old entry went.
- [cut-requirements.md](cut-requirements.md): the 1 old requirement that is not kept, a tombstone, with its old text.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and measurement is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. What each artifact class promises today, measured per repo, and the four gaps.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the policy matrix, the universal rules U1 to U7, the enforcement ladder, the module change table and the affected surfaces per repo.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. Its gates for accept now live in the blocking questions of the proposal.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, rollback and cross-repo order of the release rules, which the design does not repeat.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions.
- [scope-and-references.md](scope-and-references.md): the old `README.md`, moved word for word. Its scope table and cross-references.
- [delivery-log.md](delivery-log.md): the old `delivery.yaml`, as a table, with the ticks found in the repos.
- [policy/](policy/): the old `policy/`, moved word for word. The policy text, one file per class plus an index. It carries verbatim copies of settled rules.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. The artifact-class taxonomy and the policy matrix as compilable CUE. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, two runnable experiments (policy as CUE, a configuration compatibility gate).
- [research/](research/): the old `research/`, the dossier behind the immutable-tag rules.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits: links to renamed documents now point at the new file names (`decision-log.md`, `questions.md`, and the files in the list above), and three links to `INDEX.md`, `GRAPH.md` and `config.yaml` in `scope-and-references.md` are plain text, because those files are not in this folder. The original characters and links are in git at the commit above. The old text uses decision numbers (`D10`), requirement ids and question numbers (`OQ5`); they are history here and appear nowhere in the proposal, design or specs. Some links inside `policy/` point at paths that did not exist in the old entry either (`policy/research/migration-inventory.md`, `policy/experiments/03-d27-compat-gate/`); they were left as they were.
