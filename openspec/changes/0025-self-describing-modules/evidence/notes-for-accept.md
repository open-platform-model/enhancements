# Notes for the owner at accept

These two notes come from the old `04-graduation.md` (see `graduation.md`). The old entry did not hold them as open questions, so they are not in the proposal. The old text lists them as gates before `draft` becomes `accepted`, and the old text shows both unmet. Check them at accept.

- **The unhandled-demand case is run, not only asserted.** The old gate says the contract inventory is what separates an aspect from an annotation with a schema, and that nothing in the delta currently runs it. The fixtures in `schemas/examples.cue` run a module transformer end to end, but hold no platform over two catalogs. The gate asks for a fixture that pins what the inventory reports for a required module trait that no enabled module transformer handles, and for an optional one.
- **Prior art is compared, not cited.** The old gate asks that OAM's application scopes and KubeVela's application-level policies are compared against the module aspect and the module transformer, with the specific divergences named, in `risks.md` or a `research/` dossier. Both attach a fact to a group of components. What differs is who decides membership and what renders the result. The old risks text only links to KubeVela in the cross-references; it holds no comparison.

The other two gates are met or covered. The aspect pass and its refusals are exercised in `schemas/examples.cue`. Declaration-only fulfilment is the blocking question OQ13 of the proposal.
