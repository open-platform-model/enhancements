# Risks, Drawbacks, Alternatives — Machine-Readable Artifact Metadata in cue.mod/module.cue

This document records the honest costs of the proposed design. Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **A hand-edited block drifts from the file it sits in.** An author bumps a dependency by hand and leaves `core.version` stale. Blast radius: one publish attempt. **Mitigation:** the gate (D4) refuses at publish and names the field; `opm module vet` reports the same drift earlier; the writer (D5) is what authors are told to run, and a repair path exists for trees that predate the block.
- **`cue mod tidy` normalises the block.** Rewrites drop comments, sort keys and normalise values through Go's `any` (measured in CUE's source: `modfile.Format` re-encodes the parsed struct). Blast radius: cosmetic, unless a value's lexical form mattered. **Mitigation:** the block is plain data with string and struct values only; nothing in it depends on order, comments or number formatting. Experiment 01 confirms the gate passes after `tidy`.
- **CUE starts enforcing its `#Strict` module-file schema.** Its key regex requires `@vN`. Blast radius: none. **Mitigation:** D1 chose `"opmodel.dev@v0"`, which satisfies both schemas.
- **Upstream preserves `custom` by hand-maintained copies, not by design.** Every CUE rewrite path copies the field explicitly, with a `TODO` noting the fragility; the only regression guard is one golden test. Blast radius: a future CUE release could drop the block on `tidy`. **Mitigation:** the workspace pins the CUE toolchain; experiment 01 is the OPM-side tripwire and is cheap to re-run on each bump.
- **The grace window becomes permanent.** If the D8 refusal date slips, readers keep the fallback forever. **Mitigation:** the date is a dated decision in the CLI changelog, and D7's fallback is the only code that depends on it.
- **The 0011 amendment lands late.** D5 extends 0011 D3/D8; if the amendment is not appended, 0011's text says the writer has one target while the CLI has two. Blast radius: documentation only. **Mitigation:** OQ4 blocks acceptance until the wording exists, and `06-operational.md` sequences the append.

## Drawbacks

- **Three statements of the same facts.** `module:`, `identity/identity.cue` and the block all state the path; `deps` and the block both state pins. The gate makes this safe, not free: it is one more definition in `core` and one more gate in publish, forever.
- **One more thing `init` and `version set` write.** Small, surgical, but the writer's contract in 0011 grows a second target.
- **Annotations are invisible to CUE tooling.** `cue mod` commands never show them; only OPM tooling or a raw manifest fetch does.

## Alternatives

- **An OPM OCI artifact specification.** Full control over layers and metadata. **Why not:** it loses CUE's package manager for every consumer, and everything this entry needs fits in the channel CUE already ships.
- **Referrers (OCI subject) for metadata.** Compatible with CUE, which ignores them. **Why not:** a second manifest per artifact, registry-dependent API support, and content that is not addressed by the module's own digest. Kept as the path for a future second blob, not for facts that fit in 226 bytes.
- **Derive everything, store nothing.** Parse `deps` and paths as 0016 does today. **Why not:** kind is not derivable outside OPM's domains, and every reader re-implements the derivation.
