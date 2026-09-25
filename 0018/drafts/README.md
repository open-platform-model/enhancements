# Drafts

Status: draft, not normative.

These files are first drafts of what this entry's decisions ask the `opm` repository to hold: one page template per type, and the docs skill that carries the templates and the writing guide into agent sessions. The writing guide itself is not drafted yet; its voice section starts from [`../research/kcp-voice.md`](../research/kcp-voice.md). They live here only until the implementing change moves them. That change decides their final names, location and wording, as D9 says.

Nothing in `02-design.md` or `03-decisions.md` depends on the wording here. Where a draft and a decision disagree, the decision wins.

| Draft | Destination | Implements |
| --- | --- | --- |
| [templates/](templates/) | `opm`, one template per page type | D7, D9 |
| [skill/SKILL.md](skill/SKILL.md) | The workspace's shared skills, or each repository's (OQ10) | D11, D13 |

The page contract the templates' front matter follows is the compilable contract in [`../contracts/contracts.cue`](../contracts/contracts.cue).
