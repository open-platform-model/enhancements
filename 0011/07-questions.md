# Open Questions — Module and Catalog Publishing

## Open Questions

- **OQ1: When `--version` fills an open identity field, does publish write the working tree or a copy?** Status: resolved-by-D12.

- **OQ2: What is the credential story for publishing?** Status: resolved-by-D11.

- **OQ3: What are the republish and tag-immutability semantics?** Status: resolved-by-D10.

- **OQ4: What decides that an artifact should be published at all, and at what version?** Status: resolved-by-D15.

- **OQ5: Does publish enforce the author's `cue.mod`, or generate it?** Status: resolved-by-D16.

- **OQ6: How does the published fleet move to the owner-scoped namespace?** Status: resolved-by-D17.

- **OQ7: Who owns a catalog name?** Status: resolved-by-D13.

- **OQ8: Does `--version` mean one thing?** Status: resolved-by-D12.

- **OQ9: What reserved segments do Platform and instance artifacts get?** Status: resolved-by-D14.

- **OQ10: What refuses the removal of a beta or GA member?** Nothing does. The compatibility gate (D9/D23) makes a beta+ `name@apiVersion` key a permanent claim on its own history, but the claim binds only when the key is *re-published*: the walk visits the published build's members, so a build that simply drops a member ships clean, and every module matching on that key discovers the removal downstream. The remove-then-readd half is closed — D23's scan refuses an incompatible re-introduction against the older build — but the removal itself is refused by nothing, which is laundering-adjacent evidence that the gap is real: the hermetic remove-then-readd test's *removing* build passes the full gate set on its way to seeding the case. Status: open (logged by the cli-catalog-gates landing, 2026-08-16).
