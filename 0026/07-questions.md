# Open Questions: Module-Dictated Catalog Versions and the Generated Platform

**This file is the single canonical location for Open Questions.** An `## Open Questions` block anywhere else in the entry fails `task vet`. This is the entry's working question register: track unresolved questions surfaced during design. The validator requires this file for every entry; the `## Open Questions` block below (with or without entries) is required starting at `status: accepted`.

`OQ` numbers are permanent, never reused, never renumbered, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/`/`contracts/` CUE, and delivery-log entries in `delivery.yaml` (`resolves: [OQ9]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves.

Each **unresolved** entry also carries a `Blocking:` field saying whether the question gates acceptance:

| Value | Meaning |
| --- | --- |
| `acceptance` | `task promote` refuses while this question is open. Give the reason inline (`Blocking: acceptance: determines config.yaml.semver`). |
| `deferrable` | May stay open at `accepted`. |
| `implementation` | Handed to delivery; the change that settles it claims it via `resolves: [OQ9]` in `delivery.yaml`. |

This is where per-question blocking rules live. They used to be prose in a separate gate document, one cross-reference away from the question they governed. On the question itself, they are visible to whoever answers it, and `task questions:open` and `task promote` can both read them.

`deferred-to-implementation` is the deferral register: an implementation-level question the design deliberately hands to whoever delivers it. Attach the context a future implementer needs (what is unclear, what evidence exists, what would settle it), but never name the inheritor. The change that picks it up claims it in this entry's `delivery.yaml` log entry (`resolves: [OQ9]`), and `task delivery:deferred` reports deferred questions no logged change has claimed. Contract-level questions cannot be deferred this way: they must be resolved before `accepted`.

While a question is open, its bullet is a working surface: edit the wording, sharpen the framing, add or drop alternatives freely. Numbers stay fixed (`schemas/target.cue` marks gated fields with `// OQN:` and decisions cite `resolves OQN`), but the prose is yours to change.

Once resolved, the bullet collapses to its question and its status. The answer now lives in the decision it points at (in `03-decisions.md`); restating it here is how this register grows into a second decision log. Collapsing happens at the `draft → accepted` compaction pass, not by hand mid-design.

## Open Questions

- **OQ1: Where does a render record the catalog versions it held, and does the exported instance carry them?** Status: open. Blocking: acceptance: it is the observability contract that makes every refusal and every "why did this render change" attributable. D1 says the record exists and is part of the render's identity. Unclear: whether it lives on the instance's status as readable `path` to version pairs, in the render digest only, or both; and whether enhancement 0014's GitOps export reproduces it. What would settle it: naming the field a platform operator reads to answer "which catalog release rendered this instance".

- **OQ2: Does the platform spec hold a pin or a floor for `core`?** Status: open. Blocking: acceptance: it decides D7's acceptance-time comparison target and whether a module's core pin is module-dictated like a catalog's. D1 promotes `core` from the module's tidied closure, so the build's core version follows the module. The kernel is compiled against one core major and can build nothing else, which is a structural ceiling. Candidates: no spec field, the module's core pin binds and the major mismatch is the only refusal; a required core floor beside the catalog floors; an exact core pin, keeping 0019 D13's rule for `core` alone. What would settle it: whether any provider or catalog requirement on `core` needs an acceptance-time target that is not a module's pin.

- **OQ3: Which reference version does each path use for the module-less readiness build and 0015 D1's inventory?** Status: open. Blocking: acceptance: it changes what 0015's readiness answer means once no single version exists. D2 and D4 make the static floor the reference for static catalogs. For a provider catalog the candidates are the registration's `version` or the effective ceiling. A module above the floor may demand a contract the inventory at the floor does not list, so the readiness answer is exact only at the reference versions. What would settle it: a decision that the readiness answer is "at the floors and the registration versions" and says so in its diagnostic.

- **OQ4: Which refusals happen at spec generation and which at render, given that version ordering lives in the kernel and not in CUE?** Status: open. Blocking: deferrable. `floor <= ceiling`, an entry's major matching its path, and D6's excluded-`version` refusal are spec-level facts checkable before any render. Pin-in-range and D7's shared-path check need a module. Unclear: whether a spec that fails its own checks is refused wholesale or per entry, and how the offline CLI reports a spec-level failure with no cluster to write a condition to.

- **OQ5: What is the blast radius and caching identity of per-resolution platform generation on a real fleet?** Status: open. Blocking: implementation. D3 keys generation by the resolved catalog set, the spec's generation and the accepted registrations. Unmeasured: how many distinct resolutions a fleet produces, how a spec change or a registration change invalidates them, and what the cold and warm generation costs are against 0019 D6's once-per-CR baseline. What would settle it: a measurement over the workspace module fleet's committed pins.

- **OQ6: Is the `registry` override on a spec entry needed, and how does it compose with the trust policy of enhancement 0023?** Status: open. Blocking: deferrable. The workspace routes every OPM path through one registry mapping, and identity is the path (0010 D1), so an entry naming an OCI repository is an override of where a path resolves, never a second identity. Unclear: whether any platform needs a per-path override that the process-level mapping cannot express, and whether 0023's trusted-signer statement should be the place that binds a path to a repository instead.
