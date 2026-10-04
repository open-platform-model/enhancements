# Open Questions: The Operator Ships as an OPM Module

**This file is the single canonical location for Open Questions.** An `## Open Questions` block anywhere else in the entry fails `task vet`. This is the entry's working question register: track unresolved questions surfaced during design. The validator requires this file for every entry; the `## Open Questions` block below (with or without entries) is required starting at `status: accepted`.

`OQ` numbers are permanent, never reused, never renumbered, like `DN` and `DN:Rn`, because decisions (`**Resolves:** OQ4`), `// OQN:` markers in `schemas/`/`contracts/` CUE, and delivery-log entries in `delivery.yaml` (`resolves: [OQ9]`) cite them. A vacated number keeps a one-line tombstone.

Each entry carries a `Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, `deferred-to-implementation`, or `answered` when the question resolves.

Each **unresolved** entry also carries a `Blocking:` field saying whether the question gates acceptance:

| Value | Meaning |
| --- | --- |
| `acceptance` | `task promote` refuses while this question is open. Give the reason inline (`Blocking: acceptance: determines config.yaml.semver`). |
| `deferrable` | May stay open at `accepted`. |
| `implementation` | Handed to delivery; the change that settles it claims it via `resolves: [OQ9]` in `delivery.yaml`. |

Once resolved, the bullet collapses to its question and its status. The answer lives in the decision it points at (in `03-decisions.md`).

## Open Questions

### Questions the experiments answered

- **OQ1: Can the module render the operator's whole install shape, names included?** Status: resolved-by-D2.
- **OQ2: Does the two-step install work on a cluster with no OPM objects?** Status: resolved-by-D3.

### Contract questions

- **OQ3: Who sets the adopt annotation when install migrates a manifest-installed operator?** Status: resolved-by-D8. Resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.
- **OQ4: Does install refuse an operator version newer than the CLI?** Status: resolved-by-D10. Resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.
- **OQ5: Which platform does install render the operator module against?** Status: resolved-by-D11. Resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.
- **OQ6: What does a downgrade do?** Status: resolved-by-D10. Resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.
- **OQ7: Is the module's signing D1:R4's own rule or entry 0023's?** Status: open. Blocking: deferrable. D1:R4 asks each module release to be signed and attested like the operator image. Entry 0023 designs provenance and signatures for OPM artifacts as OCI referrers. If 0023 is accepted first, D1:R4 should depend on its decisions instead of stating a rule of its own; if not, the image's existing signing path is the interim answer. Related: signing alone anchors nothing until install verifies it. D1:R17 anchors the CLI's default version and its dependencies by content digest, and the module anchors its image by digest (D1:R10); whether install also verifies signatures, so that a version other than the default and its dependencies (D1:R18) are anchored too, belongs with this question.
- **OQ8: Does the module offer an opt-in applier identity?** Status: open. Blocking: deferrable. The operator applies instances as its own service account unless a default service account is set (D5), and its own role grants no workload rights, so a fresh install reconciles nothing until a platform team grants an applier. The module could offer an opt-in service account bound to a named role. That is a cluster-wide grant decision that belongs with whichever design governs applier identities; until it is decided the module renders no applier. Experiment 02 worked around the gap the way the CLI's development cluster does: it applied a workload grant to the operator's own account outside the module before its fixture could reconcile without a per-instance applier.
- **OQ9: What is this entry's semver impact?** Status: answered (2026-10-04): major. Install and the CRDs-only form need a module registry, selecting another version takes a module version, uninstall deletes from the cluster's record, and the migration recreates the operator's Deployment and renames its bindings; on the beta line these ship as a declared break with a migration note (0021:D7). Resolved 2026-10-04 by the supervisor under the owner's delegation; owner may overrule at PR review.
- **OQ12: When may the operator module render its controller through the catalog's workload and role resources?** Status: resolved-by-D2. Answered by the owner on 2026-10-04: from the start, with the catalog prerequisites of D12.
- **OQ13: How does the module class's bump rule combine with the version the operator shares with the CLI?** Status: resolved-by-D1. Answered by the owner on 2026-10-04: the module has its own version train, so its `#config` moves only its own number.

### Implementation questions

- **OQ10: How does install take values from the user?** Status: open. Blocking: implementation. D5 makes the operator's tuning a set of instance values. Whether install takes a values file, typed options for the common fields, or both, is the CLI's to decide; the contract is D5:R1 to R3.
- **OQ11: How does the module's release produce its version and its tags?** Status: open. Blocking: implementation. The module is a release unit of its own in the operator's repository (D1:R9), released by the same release tooling as the operator, which alone creates tags. The first-party catalog and the module fleet advance their identity file in the release pull request with the CLI's version command and forbid a second writer to that file; the operator repository has no such step and releases one unit today. The implementing change decides how the repository carries two release units with tags that cannot be confused (D1:R9), how an operator release triggers the module release that moves the image reference, and proves that a re-run of a partly failed release does not republish a version. Two constraints the repository's release configuration imposes today (`opm-operator/release-please-config.json`, read 2026-10-04): it turns off both pre-major bump settings at the top level, so a module package that inherits them would cut `1.0.0` on its first breaking commit, against D1:R13, and a minor for a `feat` commit, against D1:R16; the module's package needs both turned on, or an equivalent, so that before `1.0.0` a break raises the minor and everything else the patch. Its tags carry no component today, so the module's tag prefix also names its release branches under 0021:D10 ("Release branches", `release/<tag-prefix>vX.Y`), which must not collide with the operator's `release/vX.Y`.
