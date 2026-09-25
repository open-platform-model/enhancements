# Risks, Drawbacks, Alternatives: Documentation Architecture

## Risks and Mitigations

**The documentation drifts again.** This is the risk the entry exists to address, and restating the structure does not by itself prevent a repeat. The measured cause of the current state is that renames invalidated prose that nothing checked: 121 references to a renamed artifact survived four months because no gate looked.

*Mitigation:* D1 moves every mechanically derivable fact to generation, so a rename propagates. What remains hand-written is guidance that explains relationships rather than restating values, which does not decay on a rename. The residual exposure is real and is accepted: a concept page can still describe a mechanism that changed.

**Generated pages look authoritative and say nothing.** Generating against today's doc-comment coverage produces empty descriptions for every blueprint and most traits. *Mitigation:* the backfill slices land before the generator's output is published, and the CI gate keeps coverage from regressing. Sequenced the other way, the site would publish 43 hollow pages.

**Diagnostics goes stale silently.** Its content is keyed to error types in `library` that change with the kernel. *Mitigation:* D8 puts the kernel's diagnostics entries in `library` beside the error types, so a change and its page can land in one pull request. OQ3 still has to pick the check that makes a missing entry fail. Until it does, this is the section most likely to rot first.

**Several repositories, several house styles.** Distributed writing makes types blur into each other more easily, not less, because each repository writes about its own part. *Mitigation:* the declared type (D7) and the fixed parts per type (D9) give reviewers in every repository the same checklist, and the writing guide in `opm` carries one template per type. Voice is the part neither fixes; that is OQ7.

**The inventory becomes a checklist.** The initial page inventory is a sizing aid. Treated as a plan to fill in, it produces the placeholder pages D8 forbids. *Mitigation:* a page is written when a reader needs it, and once pages exist the live list is the generated section index.

**The doc-comment CI gate becomes a rubber stamp.** A gate that only checks presence invites a one-word comment that satisfies the check and helps nobody. *Mitigation:* the gate checks presence; review checks usefulness. Stating that split honestly is better than pretending a linter can judge prose.

**Backfilling doc comments changes published catalog bytes.** Comments are part of the CUE source, so a backfill is a catalog release. *Mitigation:* comments are additive and change no contract, so the compatibility gate passes trivially. The release is ordinary. Worth stating because "documentation-only" is not the same as "no artifact changes" in this workspace.

## Drawbacks

**Eight top-level sections is more than most projects need**, and the audience-first split duplicates some navigation: a module author and a platform engineer both need parts of Concepts. The alternative, a genre-first split, forces every audience to filter every section instead. The cost is accepted because OPM's audiences are close to disjoint in practice.

**The enforcement badge is a maintenance obligation.** Every normative statement acquires a field that can be wrong, and a badge that says `cue` when the check is actually conventional is worse than no badge. This is a real cost, taken because the four-layer gap is where users are hurt, and because `SPEC.md` demonstrates what happens without it by being wrong in both directions at once.

**Deferring secrets leaves a visible hole.** A reader looking for secrets guidance finds a pointer to an unimplemented enhancement. That is honest and unsatisfying. The alternative was a page with a known expiry date.

**This entry documents a system with nine draft subsystems.** Much of what a reader might reasonably want (lifecycle, workflows, provider classes, export) is absent, and D3 makes the absence prominent. The documentation will read as thinner than the design corpus suggests, because it is.

## Alternatives

**Copy KCP's site model.** KCP publishes one documentation site per repository under one domain, each with its own navigation and version list. Rejected by D8: it shows readers the repository layout instead of the product. What this entry takes from KCP is how its pages are written, not how its site is put together.

**Do nothing structural and update `opm/docs` in place.** Rejected in `01-problem.md`: the vocabulary drift is total rather than partial, so what survives is the argument structure of three or four documents, not their content. Updating in place also preserves the property that made the current state possible, which is prose that nothing checks.

**Site-only scope, with no source changes.** Attractive because it touches one repo. Rejected because the highest-leverage fix is in the source: switching the generator to read evaluated CUE yields 70 descriptions at no authoring cost, and the doc-comment backfill is what makes generated reference worth publishing. A site-only effort would hand-write what generation should own, reproducing the decay.

**Adopt Diátaxis wholesale as the top-level structure.** Genre-first navigation (tutorials, how-to, reference, explanation) is proven and well understood. Rejected as the *top* level for the disjointness reason above, but retained below it: every page is one of the four types (D7) and follows that type's shape (D9).

**Treat `SPEC.md` as the reference and write only tutorials publicly.** Rejected by D2. It would publish a contributor document to users, including its unshipped-state content and its unresolvable citations.

**Defer until the draft systems land.** Rejected: five enhancements are implemented and the shipped system is coherent enough to document. Waiting means the next reader meets the same v0 prose, and the draft systems have no dates.
