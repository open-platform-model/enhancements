# Evidence for 0023

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0023/`), including its `config.yaml` with the old change history.

- [migration-map.md](migration-map.md): where each of the 8 requirements, 2 decisions and 8 open questions of the old entry went.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative and rationale is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The measured state of a published artifact, the pain, the worked example and the workarounds that fail.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the diagram of release, registry and kernel, the surfaces per repo and the before and after.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The nine criteria that gated `draft` to `accepted`. The accept checklist of the new layout replaces it, and the open questions in the proposal carry its content gates.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each and the drawbacks in its last risk.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the observability, rollout, rollback and cross-repo order the design does not repeat.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the eight open questions.
- [old-readme.md](old-readme.md): the old `README.md`, moved word for word. Its scope list, its flow diagram and its cross-reference table of code paths. Its links to other entries and to the old file names are plain text now.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. A sketch of the trust policy (`target.cue`), its examples and the specification delta text. Compilable CUE, every field marked by its open question. CI runs `cue vet` here as a warning.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. The claim kinds, the attachment contract and the verification verdict. CI runs `cue vet` here as a warning.
- [experiments/](experiments/): the old `experiments/`, five experiments that are drafts and have not run: referrers on GHCR, attesting a CUE manifest, signing and verifying, a rebuild against the attested digest, and capability extraction.
- [research/](research/): the old `research/`, `findings.md`, the measured state of a published artifact and of CUE's registry client.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The only other edit: links to the old file names and to other entries' folders in `old-readme.md` and `decision-log.md` now point at the renamed file or are plain text. The original characters are in git at the commit above. The old text uses decision numbers (`D1`), requirement ids and question ids (`OQ3`); they are history here and appear nowhere in the proposal, design or specs.

The old entry had no `delivery.yaml`: no repo change of 0023 has shipped, so `tasks.md` has no ticked line and there is no delivery log.
