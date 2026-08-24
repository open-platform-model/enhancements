# Open Questions — Initialize a Module Instance Package from a Published Module

## Open Questions

Track unresolved questions surfaced during design. Each entry carries a
`Status:` line; close it with `resolved-by-D##`, `deferred-to-NNNN`, or
`answered` when the question resolves.

All six questions were walked and resolved on 2026-08-24; the answers live in the decisions they point at.

- **OQ1: Name and shape of the new `#Module` field.** Status: resolved-by-D4. Settled as `initValues?: _`, open and optional, no schema-side `#config` assertion, non-concrete content allowed.
- **OQ2: Command surface and reference syntax.** Status: resolved-by-D5. Settled as a mirror of `opm module init`: major-free module path, `--version` for major float or exact pin, omitted version floats to the highest core-compatible major.
- **OQ3: Behavior when the module has neither `initValues` nor usable `debugValues`.** Status: resolved-by-D6. Settled as `values: {}` plus a warning; concrete non-struct sources render verbatim.
- **OQ4: Where the package renderer lives.** Status: resolved-by-D7. Settled as CLI-side; `library` left `affects`.
- **OQ5: Validation at init time.** Status: resolved-by-D8. Settled as no init-time vet; the report names the vet command. Publish-time conformance of `initValues` is 0011's call.
- **OQ6: Version pinning and dep hygiene in the generated `cue.mod/module.cue`.** Status: resolved-by-D9. Settled as exact module pin, core at the module's major, complete closure, placeholder `module:` path overridable with `--module-path`.
