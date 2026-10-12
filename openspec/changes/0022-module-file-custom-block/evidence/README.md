# Evidence for 0022

Proof and source material. Outside the word total. The converted text of the entry is `../proposal.md`, `../design.md` and `../specs/`. The old documents are kept here where they hold detail the design leaves out. The whole old entry stays in git at commit `18705155d2c7312029132c30d2b106ca59e57125` of `enhancements` (path `0022/`), including its `config.yaml` with the old change history and its owner decisions.

- [migration-map.md](migration-map.md): where each of the 28 requirements, 8 decisions and 6 open questions of the old entry went. No requirement is cut, so the entry has no cut list.
- [notes-for-accept.md](notes-for-accept.md): open points of the alignment with the seeds, and the wording that amends archived 0011, for the owner at accept.
- [decision-log.md](decision-log.md): the old `03-decisions.md`, moved word for word. Every alternative, rationale, measurement and source is here.
- [problem.md](problem.md): the old `01-problem.md`, moved word for word. The current state, the pain, the cert_manager example and the user stories.
- [design-notes.md](design-notes.md): the old `02-design.md`, moved word for word. It holds the design goals, the channel diagram, the module file as authored and the before and after of the reader.
- [risks.md](risks.md): the old `05-risks.md`, moved word for word. The design keeps the risks as one line each.
- [operational.md](operational.md): the old `06-operational.md`, moved word for word. It holds the signals, the compatibility statement, the rollback and the cross-repo order. The design repeats only the order.
- [questions.md](questions.md): the old `07-questions.md`, moved word for word. The register of the six open questions.
- [graduation.md](graduation.md): the old `04-graduation.md`, moved word for word. The old accept criteria; the accept checklist of the new layout replaces them.
- [old-readme.md](old-readme.md): the old `README.md`. It holds the old scope lists and the cross-reference table of the files each repo will touch.
- [schemas/](schemas/): the old `schemas/`, moved with its `cue.mod`. Compilable CUE for the block, its gate and the worked examples, and the draft text for the core specification. CI runs `cue vet` here as a warning.
- [contracts/](contracts/): the old `contracts/`, moved with its `cue.mod`. The annotation key set and the reader's fallback ladder.
- [experiments/](experiments/): the old `experiments/`, seven experiments. Five are drafts that have not run (tidy round trip, publish and fetch verbatim, gate error text, annotations round trip, probe cost). Two are concluded (the listing card round trip across the fleet, and the open tail).

There is no delivery log: the old entry had no `delivery.yaml`, and no shipped repo change for it is recorded.

One change to the moved files: every em-dash character is replaced by a hyphen, to follow the workspace writing rule. The other edits are links: the links to renamed documents in `decision-log.md` and `old-readme.md` now point at the new file names, and the links from `old-readme.md` to the repo index, the graph and archived entries are plain text. The original characters and links are in git at the commit above. The old text uses decision numbers (`D4`) and requirement ids; they are history here and appear nowhere in the proposal, design or specs.
