# Operational Concerns: OPM Versioning Policy

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The policy itself introduces none. If OQ5/OQ6 land the module compatibility gate, `opm module publish` gains a refusal class of the same shape as the catalog gate's: it names the artifact, the predecessor version compared against, the field or constraint that changed, the change class, and the level the authored version would have needed. A refusal is a publish-time error to the author, never a runtime signal. The check command's module mode, if adopted under 0010 D35's aid posture, reports the same comparison without refusing. Where the comparison is emitted today for catalogs is evidence of the shape, not an instruction: the catalog gate's refusals are the `Refusal` findings the check report reuses.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

No schema, command or artifact format changes. `opmodel.dev/core` is untouched (`core_schema: false`). The policy reclassifies what an already-published module version *promises*, which has no effect on any published bytes. It does mean that a module whose history contains a `#config` break inside a major is, under the policy, carrying a promise it has already broken. The policy says what such a module does at its next release (OQ12). A publish gate, when it lands, is additive to the CLI's surface: new refusals, no changed semantics for a publish that would have succeeded under the policy anyway. `config.yaml.semver` is expected to be `none`; the graduation gate records the condition under which it is not.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The versioning paragraphs in `core/CLAUDE.md`, `catalog_opm/CLAUDE.md` and `modules/CLAUDE.md` become pointers at the published policy for the rules the policy owns, and keep the repo-local mechanics (which task writes the version, which branch takes which release). The core repo's commit-type table stays as the claim layer for that class; the policy is what defines the surface the table's "breaking" row refers to.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The policy page and the `CLAUDE.md` pointers revert as documentation. A module gate, if landed, is removed from the publish path without affecting any published artifact; a version refused by the gate was never published, and a version that was published stays published. There is no data-plane state. Modules that bumped a major under the policy keep their new module path; a major cannot be un-cut, and that is U5's ordinary cost rather than a rollback hazard.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- The published policy must exist before any repo's `CLAUDE.md` points at it, because a pointer at nothing is worse than the paragraph it replaces.
- OQ1..OQ4 must be resolved before a module gate is built, because the gate compares against the surface those questions complete, and a gate built against D2 alone would enforce half the rule.
- The generalized comparison in `library` must exist before `cli` can refuse on it, in the same producer-consumer order the catalog gate followed.
- OQ7's answer changes how `catalog_opm` releases are cut and must be published before the next catalog release that ships a new contract level or a tombstone, or that release decides the rule by precedent.
- The operator's CRD policy (OQ9) constrains any future second CRD version and nothing that exists; it has no ordering dependency on the other repos.
