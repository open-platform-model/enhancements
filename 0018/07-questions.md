# Open Questions: Documentation Architecture

## Open Questions

- **OQ1: What does the generator read, and in what precedence?** Status: open. Blocking: acceptance.

  `metadata.description` is populated on all 70 catalog members and is the obvious primary source for a summary line. Doc comments carry the longer explanation that a one-liner cannot (why `exactName` and `immutable` conflict, why `podMetadata` exists at all) but are present on only a minority of the members that matter.

  A generated entry plausibly wants both: the description as the summary, the doc comment as body prose. Unresolved: the precedence when the two disagree, whether a member carrying a doc comment but no description is valid, and whether the same rule governs `core` definitions, whose descriptions exist only in doc comments and have no `metadata.description` equivalent at all.

- **OQ2: Does the enforcement badge appear on generated reference entries, or only on authored pages?** Status: open. Blocking: acceptance.

  An authored Concepts page states its badge by hand. A generated member entry cannot, unless the enforcement layer is itself derivable from the source. Some of it is: a required field is `cue`-enforced by construction. Some is not: whether the kernel refuses an unhandled trait depends on posture resolution at render, which the member's own definition does not determine.

  Three candidates: badge only authored statements and leave generated entries unbadged; badge generated entries with a conservative default; or teach the generator the small set of derivable cases and leave the remainder unbadged. The third is the most useful and the most work, and it risks a badge that says `cue` where the real answer is `convention`, which is worse than no badge.

- **OQ3: Who keeps Diagnostics current as the kernel's error types change?** Status: open. Blocking: acceptance.

  The Diagnostics section maps kernel errors to causes and fixes. Those types live in `library/opm/errors` and change with the kernel; nothing connects a change there to a documentation update, and this is the section most likely to rot first.

  Candidate mechanisms: a test in `library` asserting that every exported error type appears in the site's diagnostics index, a checklist item in the library's own change protocol, or explicit acceptance that the section drifts and is audited periodically. The first is the only one that fails loudly, and it couples two repos that are otherwise independent.

- **OQ4: How is `opm/docs` retired, given that `opm` is not an area?** Status: open. Blocking: acceptance (decides whether the area vocabulary changes).

  `enhancements/schema.cue`'s `#Area` enumeration has no `opm` entry, so the meta repo cannot appear in `affects` and cannot own a slice in this entry's plan. That tree holds the stale prose this enhancement replaces, and it remains reachable and looks current, which is the failure mode.

  Options: add `opm` to the area vocabulary, which is a schema change to the enhancements repo itself; retire the tree as uncoordinated cleanup outside the plan; or move the salvageable formats into `opmodel.dev` and leave the deletion to whoever owns the meta repo. Worth salvaging as format rather than content: the glossary's shape, the persona routing at the top of `docs/index.md`, and the raw-versus-blueprint side-by-side in `concepts/resources-traits-blueprints.md`.

- **OQ5: What happens to the two catalog members that render nothing?** Status: open. Blocking: acceptance.

  `#SizingTrait` and `#EncryptionConfigTrait` appear in no transformer's required or optional maps, and both declare `optional: bool | *true`, so attaching either warns at most and renders nothing. `#VerticalScalingSchema` is an empty struct labelled a placeholder for future VPA support.

  Documenting them as-is advertises capability that does not exist. They need to be wired, marked explicitly unimplemented in their own metadata so the generator can render them as such, or removed. The decision belongs to the catalog rather than to this entry, but the documentation cannot ship a member page either way until it is made.

- **OQ6: Does the site need a versioned-documentation story?** Status: open. Blocking: acceptance.

  `core` maintains a v1 line on a protected branch alongside v2 on main, and the module fleet is mid-migration. Whether the public site documents only the current line or carries a version switcher changes both the generator's contract and the site's information architecture.

  Deferring is viable while the v1 line has only internal consumers, which is true today. The question becomes forcing the moment an external consumer pins v1.
