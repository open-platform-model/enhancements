# Notes for the owner at accept

These points come from the conversion and its review. The old entry did not hold them as open questions, so they are not in the proposal. The owner decides each at accept.

- **The premise may be partly met already (old 0004, whole entry).** The release cascade now ships a workflow, `deps-cascade.yml`, that does much of what this entry proposes. The owner decides at accept what 0004 still adds beyond the cascade.
- **Repos outside the closed repo list (old 0004 text).** The tasks name `daggerverse` and the workspace Taskfile as repos that change. Neither is a member of the closed repo list of the schema (`#EntryRepo`), so the vet rule V23 warns for both task lines. The conversion keeps the old text. The owner decides at accept whether the two join the list or the tasks move under another heading.
