# Risks, Drawbacks, Alternatives: Documentation Architecture

## Risks and Mitigations

**The documentation drifts again.** This is the risk the entry exists to address, and restating the structure does not by itself prevent a repeat. The measured cause of the current state is that renames invalidated prose that nothing checked: 121 references to a renamed artifact survived four months because no gate looked.

*Mitigation:* D1 moves every mechanically derivable fact to generation, so a rename propagates. What remains hand-written is guidance that explains relationships rather than restating values, which does not decay on a rename. The residual exposure is real and is accepted: a concept page can still describe a mechanism that changed.

**Generated pages look authoritative and say nothing.** Generating against today's doc-comment coverage produces empty descriptions for every blueprint and most traits. *Mitigation:* the backfill slices land before the generator's output is published, and the CI gate keeps coverage from regressing. Sequenced the other way, the site would publish 43 hollow pages.

**Diagnostics goes stale silently.** Its content is keyed to error types in `library` that change with the kernel, and nothing connects the two repos. *Mitigation:* OQ3 exists to pick a mechanism. Until it is resolved, this is an open exposure rather than a mitigated one, and it is the most likely section to rot first.

**The doc-comment CI gate becomes a rubber stamp.** A gate that only checks presence invites a one-word comment that satisfies the check and helps nobody. *Mitigation:* the gate checks presence; review checks usefulness. Stating that split honestly is better than pretending a linter can judge prose.

**The site cannot render.** The Hugo theme is disabled for an i18n incompatibility, and no section renders to HTML. Content written against a site that does not build is unverifiable. *Mitigation:* the theme question is explicitly a non-goal of this entry, but it blocks the verification gate. If it is not resolved independently, this entry cannot reach `implemented`.

**Backfilling doc comments changes published catalog bytes.** Comments are part of the CUE source, so a backfill is a catalog release. *Mitigation:* comments are additive and change no contract, so the compatibility gate passes trivially. The release is ordinary. Worth stating because "documentation-only" is not the same as "no artifact changes" in this workspace.

## Drawbacks

**Eight top-level sections is more than most projects need**, and the audience-first split duplicates some navigation: a module author and a platform engineer both need parts of Concepts. The alternative, a genre-first split, forces every audience to filter every section instead. The cost is accepted because OPM's audiences are close to disjoint in practice.

**The enforcement badge is a maintenance obligation.** Every normative statement acquires a field that can be wrong, and a badge that says `cue` when the check is actually conventional is worse than no badge. This is a real cost, taken because the four-layer gap is where users are hurt, and because `SPEC.md` demonstrates what happens without it by being wrong in both directions at once.

**Deferring secrets leaves a visible hole.** A reader looking for secrets guidance finds a pointer to an unimplemented enhancement. That is honest and unsatisfying. The alternative was a page with a known expiry date.

**This entry documents a system with nine draft subsystems.** Much of what a reader might reasonably want (lifecycle, workflows, provider classes, export) is absent, and D3 makes the absence prominent. The documentation will read as thinner than the design corpus suggests, because it is.

## Alternatives

**Do nothing structural and update `opm/docs` in place.** Rejected in `01-problem.md`: the vocabulary drift is total rather than partial, so what survives is the argument structure of three or four documents, not their content. Updating in place also preserves the property that made the current state possible, which is prose that nothing checks.

**Site-only scope, with no source changes.** Attractive because it touches one repo. Rejected because the highest-leverage fix is in the source: switching the generator to read evaluated CUE yields 70 descriptions at no authoring cost, and the doc-comment backfill is what makes generated reference worth publishing. A site-only effort would hand-write what generation should own, reproducing the decay.

**Adopt Diátaxis wholesale as the top-level structure.** Genre-first navigation (tutorials, how-to, reference, explanation) is proven and well understood. Rejected as the *top* level for the disjointness reason above, but retained below it: genre still governs how an individual page is written.

**Treat `SPEC.md` as the reference and write only tutorials publicly.** Rejected by D2. It would publish a contributor document to users, including its unshipped-state content and its unresolvable citations.

**Defer until the draft systems land.** Rejected: five enhancements are implemented and the shipped system is coherent enough to document. Waiting means the next reader meets the same v0 prose, and the draft systems have no dates.
