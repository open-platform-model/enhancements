<!-- GENERATED from policy/module.cue by `cue eval -e render --out text`. Edit the CUE, regenerate. -->
# Versioning policy: module

Repo: `modules`

| Cell | Value |
| --- | --- |
| Carrier | cue-module-semver |
| Surface | the #config schema, compared by subsumption over accepted values |
| Bump | breaking → major, additive → minor, fix → patch, invisible → none |
| Pre-stable | open |

## Universal rules

- U1: SemVer 2.0 everywhere; major in the path for CUE modules.
- U2: One named surface per class; a release's bump is the maximum change class across it.
- U3: Pre-stable means the promise is off, and the line says so.
- U4: A version is declared by an author or a release tool, never predicted by publish.
- U5: A major is an import rewrite; each class names what survives it.
- U6: Publish-side gates where the surface is comparable, convention where it is not; a check command is an aid.
- U7: No consumer window; producer-side seasoning where retirement exists.

## Rules

### MUST

- **R1** (convention; enforced by `n/a`): A release that stops accepting values the previous release accepted MUST bump the major. Source: 0021 D2. Unenforced because: the module compatibility gate is 0021 OQ5/OQ6 and not yet built
- **R2** (claim; enforced by `n/a`): A release that adds only optional fields or fields with defaults MUST bump at least the minor. Source: 0021 D2.
- **R3** (gate; enforced by `opm module publish`): A version already present in the registry MUST be refused, never skipped. Source: 0011 D15.

### SHOULD

- **R4** (gate; enforced by `modules release workflow, cross-train major separation guard`): A module promoted from an older train SHOULD bump its path major past that train's line, and CI refuses two trains sharing a major. Source: modules/CLAUDE.md major separation rule.

### MAY

- **R5** (convention; enforced by `n/a`): A field that stays accepted but is no longer read MAY not be detected by any gate and is still a breaking change. Source: 0021 05-risks.md.

