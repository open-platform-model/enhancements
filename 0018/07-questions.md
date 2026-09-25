# Open Questions: Documentation Architecture

## Open Questions

- **OQ1: What does the generator read, and in what precedence?** Status: open. Blocking: acceptance.

  `metadata.description` is populated on all 70 catalog members and is the obvious primary source for a summary line. Doc comments carry the longer explanation that a one-liner cannot (why `exactName` and `immutable` conflict, why `podMetadata` exists at all) but are present on only a minority of the members that matter.

  A generated entry plausibly wants both: the description as the summary, the doc comment as body prose. Unresolved: the precedence when the two disagree, whether a member carrying a doc comment but no description is valid, and whether the same rule governs `core` definitions, whose descriptions exist only in doc comments and have no `metadata.description` equivalent at all.

- **OQ2: Does the enforcement badge appear on generated reference entries, or only on authored pages?** Status: open. Blocking: acceptance.

  An authored Concepts page states its badge by hand. A generated member entry cannot, unless the enforcement layer is itself derivable from the source. Some of it is: a required field is `cue`-enforced by construction. Some is not: whether the kernel refuses an unhandled trait depends on posture resolution at render, which the member's own definition does not determine.

  Three candidates: badge only authored statements and leave generated entries unbadged; badge generated entries with a conservative default; or teach the generator the small set of derivable cases and leave the remainder unbadged. The third is the most useful and the most work, and it risks a badge that says `cue` where the real answer is `convention`, which is worse than no badge.

- **OQ3: Who keeps Diagnostics current as the kernel's error types change?** Status: partially resolved. Blocking: acceptance (the mechanism is still unchosen).

  The Diagnostics section maps kernel errors to causes and fixes. Those types live in `library/opm/errors` and change with the kernel; nothing connects a change there to a documentation update, and this is the section most likely to rot first.

  Candidate mechanisms: a test in `library` asserting that every exported error type appears in the site's diagnostics index, a checklist item in the library's own change protocol, or explicit acceptance that the section drifts and is audited periodically. The first is the only one that fails loudly, and it couples two repos that are otherwise independent.

  Partially resolved 2026-09-24 by D8: the kernel's diagnostics entries live in `library`, next to the error types, so the test no longer couples two repositories. Still open: whether the check is that test, a checklist item, or a periodic audit.

- **OQ4: How is `opm/docs` retired, given that `opm` is not an area?** Status: partially resolved. Blocking: acceptance (the rewrite rule still needs a decision).

  Resolved 2026-09-20: `opm` joined the repo vocabulary, so the meta repo can appear in `affects` and own a slice. The tree is not retired; it is rewritten in place as the home of the authored prose that has no code owner: Start here, cross-repo guides and the boundaries page. Still open: the rule that nothing describing the v0 line survives the rewrite, and whether that rule is a gate or a review judgement. Worth salvaging as format rather than content: the glossary's shape, the persona routing at the top of `docs/index.md`, and the raw-versus-blueprint side-by-side in `concepts/resources-traits-blueprints.md`.

- **OQ5: What happens to the two catalog members that render nothing?** Status: open. Blocking: acceptance.

  `#SizingTrait` and `#EncryptionConfigTrait` appear in no transformer's required or optional maps, and both declare `optional: bool | *true`, so attaching either warns at most and renders nothing. `#VerticalScalingSchema` is an empty struct labelled a placeholder for future VPA support.

  Documenting them as-is advertises capability that does not exist. They need to be wired, marked explicitly unimplemented in their own metadata so the generator can render them as such, or removed. The decision belongs to the catalog rather than to this entry, but the documentation cannot ship a member page either way until it is made.

- **OQ6: Does the site need a versioned-documentation story?** Status: open. Blocking: acceptance.

  `core` maintains a v1 line on a protected branch alongside v2 on main, and the module fleet is mid-migration. Whether the public site documents only the current line or carries a version switcher changes both the generator's contract and the site's information architecture.

  Deferring is viable while the v1 line has only internal consumers, which is true today. The question becomes forcing the moment an external consumer pins v1.

  Amended 2026-09-20: the answer is yes, the site is versioned. Which version it conforms to is a versioning-policy question and is held in 0021 (OQ14, whether the CLI and operator share a version, and OQ15, how the site is versioned against it). This question waits on those two and adds nothing of its own beyond the generator consequence: the reference for a given site version is evaluated from the published core and catalog the CLI pins at that tag.

- **OQ7: How is the author's voice captured so prose written in five repos reads as one?** Status: open. Blocking: deferrable.

  Authored prose lands in whichever repo owns the behaviour it describes, so five repos write it, and the plain-English requirement for first-contact pages is the hardest one to hold that way. A shared style rule inherited from the workspace is necessary and not sufficient: it constrains shape, not voice.

  Candidate: a skill that learns the author's voice by eliciting writing samples on set prompts, distils them into a voice document, and ships that document to every repo so any writer, human or agent, can be checked against it. This is research to do later, not now; nothing in this entry's design depends on how it is built, only on a voice document existing before the authoring track publishes. The stand-in is written down in [research/kcp-voice.md](research/kcp-voice.md). When the voice document exists, it refines that capture rather than replacing it, and may add rules to the writing guide under D13.

- **OQ8: Where does the vocabulary live, `opm` or `core`?** Status: answered. Withdrawn 2026-09-25 with D12: there is no separate vocabulary to place. The glossary is a page like any other, placed by D8.

- **OQ9: How does the linter pick the rules for a page's type?** Status: answered. Withdrawn 2026-09-25: the rules that bind only some page types are review rules under D13, so the linter applies one rule set to every page.

- **OQ10: How does the shared rule set reach every repository and every agent session, and how is it versioned?** Status: open. Blocking: implementation.

  D13 requires one shared rule set, checked in each repository's pull requests. Candidates for the checks: a reusable CI step published by the site engine, or a lint package each repository downloads from an `opm` release. Candidates for agents: the docs skill drafted in [`drafts/skill/`](drafts/skill/), placed in the workspace's shared skills or copied per repository. Versioning is the harder part. A floating rule set can start failing pull requests in six repositories at once; a pinned one needs a bump in each, the way `task deps:update` moves CUE pins today.

- **OQ11: Is Vale the prose linter?** Status: open. Blocking: implementation.

  Write the Docs points at Vale, and it is the linter this entry assumes, but nothing has been run against OPM pages yet. Alternatives include textlint and proselint. markdownlint checks Markdown mechanics only and does not replace a prose linter. What would settle it: linting the first five pages with it, and checking that it runs in CI without a network fetch on every job.

- **OQ12: What is the sentence-length ceiling, and does it vary by section?** Status: open. Blocking: deferrable.

  Measured on KCP's Concepts pages, the median sentence is 16 words and 12% of sentences run past 30. Candidate: a tighter ceiling on Start here and Concepts, where first-time readers land, and a looser one on reference, where tables and rule statements dominate.

- **OQ13: When does a warning-level rule become an error, and who decides?** Status: open. Blocking: deferrable.

  D13 starts every new machine-checked rule as a warning. It does not say what triggers the promotion. Candidates: when every existing page passes the rule; after a fixed period with no false positives; or by explicit decision in the writing guide's own change history.

- **OQ14: How does the first-use check handle plurals and other inflected forms?** Status: answered. Withdrawn 2026-09-25: first-use linking is the site's job under D11, not a check on the writer. How the site matches a plural is a detail for the implementing change.
