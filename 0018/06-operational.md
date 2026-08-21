# Operational Concerns — Documentation Architecture

## Observability

Documentation has no runtime, so the question is how staleness becomes visible rather than how failures are traced.

Three signals are mechanical and belong in CI: `task generate` succeeding on a clean checkout (it does not today), doc-comment coverage in `catalog_opm` staying at 100 percent for blueprints, abstraction resources and traits, and the site building. A fourth is proposed but unresolved (OQ3): a check connecting the kernel's exported error types to the Diagnostics section, so that adding an error type without documenting it is visible.

Two signals are not mechanical and are stated so nobody expects them to be. Whether a Concepts page still describes the mechanism accurately cannot be checked by a linter; it is caught by review when the mechanism changes, or not at all. Whether a page is useful is a review judgement, not a gate.

The verification gate in `04-graduation.md` is deliberately a walk rather than an assertion: someone follows Start here on a clean machine and reaches a rendered module. That is the only end-to-end signal that catches a documentation set which passes every mechanical check and still does not work.

## Semver Impact

`none` for every published artifact. Site content carries no version contract. Doc-comment backfill in `catalog_opm` and `core` changes CUE source, so it ships in ordinary releases of those modules, but comments alter no contract: the compatibility gate compares definitions and a comment is not part of one. Generator changes in `opmodel.dev` ship no module at all.

The one thing worth stating: "documentation-only" does not mean "no artifact changes" in this workspace. A catalog doc-comment backfill is a catalog release, and it should be cut as one rather than smuggled into an unrelated change.

## Deprecation

`opm/docs` is the deprecated surface. Every file there describes the v0 catalog line, and the tree is currently reachable and looks current, which is the failure mode. Its retirement path is OQ4, unresolved because `opm` is not a member of the area vocabulary and therefore cannot own a slice in this entry's plan.

Whatever the resolution, three pieces are worth salvaging as *format* rather than content: the glossary's shape (a short definition plus an optional CUE snippet, plus the CUE-terms and workflow-terms tables), the persona routing at the top of `docs/index.md`, and the raw-versus-blueprint side-by-side in `concepts/resources-traits-blueprints.md`, which is the clearest teaching device in the workspace and survives a path rewrite almost verbatim.

Two smaller deprecations ride along: `cli/docs/STYLE.md` cites commands that no longer exist and links the glossary by a workspace-relative path that its own sibling rule forbids, and `library/docs/getting-started.md` omits the mandatory Materialize step, so following it cannot produce working code.

## Rollback

Every change is content or generator code in version control, so rollback is a revert. There is no data migration, no published artifact whose bytes become unreachable, and no consumer pinned to a documentation version.

The one ordering constraint that matters for rollback is the same one that matters for landing: the generator must not publish before the doc-comment backfill, or the site ships 43 hollow pages. Reverting the generator alone is safe; reverting the backfill while the generator is live is what produces the bad state.

## Cross-Repo Coordination

Ten slices across five repos. A delivery plan carries the structure; this section carries why the order is what it is.

**Three slices are independent and can start immediately.** The doc-comment backfills in `catalog` and `core` need nothing from the site, and the boundaries page (D3) needs nothing from anyone: it enumerates absences, and every absence is already a fact. The library embedder guide is likewise self-contained.

**The generator repair gates everything generated.** `task generate:cli` fails on a clean tree, and the index generator scrapes text rather than evaluating CUE. Until both are fixed, no generated reference can be published, and the fix is what turns 70 populated `metadata.description` fields into 70 populated entries at no authoring cost.

**Concepts comes before the authoring and operating tracks**, because both link into it rather than restating it. A guide that explains the matching model inline instead of linking to it is how the model ends up documented in three places and correct in one.

**The authoring track waits on two things**, the catalog backfill and the generator, because it is the section whose pages interleave authored guidance with generated member entries most heavily. Publishing it against hollow entries would be the failure mode the risks section names.

**Retirement comes last.** The stale tree stays reachable until its replacements exist, because a reader who finds nothing is worse off than one who finds something outdated and clearly marked. Marking it is the interim step: a banner on the stale tree pointing at the site, applied as soon as the site has anything to point at.

**One coordination point sits outside this entry.** Enhancement 0013 owns the secrets documentation (D5), and its `docs-secrets-authoring` slice was amended on 2026-08-18 to reflect that it authors rather than rewrites. When 0013 lands, the secrets placeholder in this entry's output is replaced by that slice's work, not by this entry's.
