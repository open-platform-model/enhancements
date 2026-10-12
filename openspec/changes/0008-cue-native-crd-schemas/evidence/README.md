# Evidence for 0008

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0008/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 9 requirements, 8 decisions and 5 open questions of the old entry went.
- [notes-for-accept.md](notes-for-accept.md): one point for the owner at accept: the singleton rule that a seed states too.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale and source is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The file evidence for the pain and the worked `values` example.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the design goals, the affected surfaces per repo and the before and after workflow.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The seven gates before `draft` became `accepted`, among them the spike that proves the encoder output is accepted by an API server. The checker's accept rules replace most of them; the spike and the question gates are not replaced.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps five risks as one line each, and the alternatives as the list of rejected options.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the rollout, rollback, deprecation and cross-repo order the design shortens.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of open questions.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word, links re-pointed. It holds the in-scope and out-of-scope lists and the cross-reference table of repo files the implementation touches.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the CRD envelope, the worked `ModuleInstance` and `Platform` instances, and the specification delta. CI runs `cue vet` here as a warning.
- [research/](research/): the old `research/`, the dated dossier of 2026-06-25 on what the CUE toolchain can and cannot do.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edits are links: the pointers to the renamed documents now name the new file names (in `decision-log.md`, `old-readme.md` and `research/findings.md`), and the links to the archived entry 0006 and to `INDEX.md` and `GRAPH.md` are plain words. The original characters and links are in git at the commit above. The old text uses decision numbers (`D1`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.

0008 had no `delivery.yaml` and no experiments folder, so there is no delivery log and no `experiments/`.
