# enhancements: where do I go?

Router only. Facts and rules are in `AGENTS.md`.

| Task | Read first | Then |
| --- | --- | --- |
| Create, edit, accept, deliver, reject, withdraw or supersede an entry | `.claude/skills/enhancements/` | `AGENTS.md` |
| Add or change an experiment under an entry's `evidence/` | `.claude/skills/enhancement-experiments/` | `.claude/skills/enhancements/` |
| Draw or change a diagram, also one in a `design.md` | `.claude/skills/enhancement-diagrams/` | |
| Find the right `task` for a job, or read what a `task` does | `references/tasks.md` | `Taskfile.yml` |
| Read an entry, list entries, or see how entries relate (`after`, `superseded_by`) | `README.md` | `openspec/changes/` |
| Change a rule of the store, an artifact template or a checker rule | `openspec/config.yaml` | `openspec/schemas/`, `tools/enh/` |
| Change the repo list, the reserved ids or the shape of `config.yaml` | `schema.cue` | `tests/schema/` |
| Change the docs bundle, `docs-kit.cue` or the docs workflow | `docs-kit.cue` | `.github/workflows/` |
| Change a CI workflow | `.github/workflows/` | `AGENTS.md` |
| Deliver a task line in another repo, or cite an entry in code | `references/enhancements.md` at the workspace root | `AGENTS.md` |
| A change touches `core/*.cue` | `core/.claude/skills/core-schema-edit/` | |
| Commit, open a PR or write GitHub text | `references/git-text.md` at the workspace root | |
| Run `cue`, resolve a module or touch a registry | `references/registry.md` at the workspace root | |
