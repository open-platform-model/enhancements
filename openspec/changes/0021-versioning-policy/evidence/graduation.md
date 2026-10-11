# Graduation Criteria: OPM Versioning Policy

This document records the entry-specific gates that must hold before this design is frozen. Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs resolve) live in `gates.cue` and `task vet` and are not repeated here.

## draft → accepted

The enhancement is ready to be implemented when:

- Every row of the policy matrix in `02-design.md` has all five cells filled or cited: carrier, surface, bump rules, pre-stable form, enforcement layer. A cell that reads "open" points at a resolved decision or at a question marked `deferred-to-implementation` with the context an implementer needs; no cell points at an open contract-level question.
- The module surface is complete: OQ1 (runtime continuity), OQ2 (ladder or SemVer only), OQ3 (defaults) and OQ4 (pre-stable form) are each resolved by a decision, because together with D2 they are the rule a module author follows and a gate would verify.
- OQ7 (how a contract-level event moves the catalog build number) is resolved, since it is the one rule a catalog release today decides implicitly and the policy would be incomplete for the class that already has a gate.
- OQ14 (one tooling train or three) and OQ15 (how documentation is versioned) are resolved by decisions, because they decide the shape of two classes rather than a cell in one.
- The Go-artifact surfaces (OQ8, OQ9, OQ10) are each either resolved or explicitly left at the convention layer by a decision, so that "convention" is a stated choice and not an omission.
- Every verbatim block in `policy/` still matches its source byte for byte (D3), and every class file has all five cells filled or pointing at a resolved decision or deferred question.
- `contracts/policy.cue` compiles with every `// OQN:` marker resolved or pointing at a deferred question, and its matrix agrees cell for cell with `02-design.md`.
- Every decision carries a valid `**Kind:**` and passes the admission test; every copied rule carries its source line (D3).
- The policy names its publication surface, and `affects` lists every repo whose documentation or gate the accepted rules change.
- `semver` in `config.yaml` is set. The expected value is `none` unless OQ1 or OQ3 resolves in a way that changes what an already-published module version is understood to promise.
