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

  Candidate: a skill that learns the author's voice by eliciting writing samples on set prompts, distils them into a voice document, and ships that document to every repo so any writer, human or agent, can be checked against it. This is research to do later, not now; nothing in this entry's design depends on how it is built, only on a voice document existing before the authoring track publishes.
