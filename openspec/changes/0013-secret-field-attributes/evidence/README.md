# Evidence for 0013

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0013/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 100 requirements, 36 decisions and 9 open questions of the old entry went.
- [cut-requirements.md](cut-requirements.md): the 75 old requirements that are not kept as requirements of their own (60 cut, 15 for a repo), each with its old text and, where a new requirement states the claim, which one. The owner samples 8 before the cut binds.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative and rationale is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The file and line evidence for the pain.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the affected surfaces per repo and the before and after example. It was written before the named-source decisions, and the decision log is current.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps five risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the rollout, rollback, deprecation and cross-repo order the design does not repeat.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions and their resolutions.
- [delivery-log.md](delivery-log.md): the old `delivery.yaml`, as a table.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the secret contract, the worked examples and the specification delta. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, four runnable experiments behind the resolve-in-place decisions.
- [research/](research/): the old `research/`, the six feasibility probes of 2026-09-30.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edit: three links to the renamed `03-decisions.md` and `07-questions.md` now point at `decision-log.md` and `questions.md` (in `design-notes.md`, `decision-log.md` and `schemas/spec.md`). The original characters are in git at the commit above. The old text uses decision numbers (`D10`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
