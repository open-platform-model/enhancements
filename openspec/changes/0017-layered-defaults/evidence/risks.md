# Risks, Drawbacks, Alternatives: Layered Defaults

Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken.

## Risks and Mitigations

**Behavior-change risks.**

- **The core projection change breaks consumers relying on forced presence.** D5 makes optional-trait fields absent-by-default. Any consumer reading `#component.spec.<field>` unguarded (expecting the old always-present shape) starts hitting `_|_`. Blast radius: catalog transformers (already guarded, their `!= _|_` guards were written for exactly this world and merely go live) and any third-party transformer written against the accidental behavior. **Mitigation:** `feat!` on the alpha line with the behavior change named in the changelog; the catalog's own transformer fixtures gain blueprint-path components so the guards are exercised, not just present.
- **The kernel's default-as-commitment change surfaces latent conflicts in existing modules.** Any fleet module whose config default violates a downstream constraint currently ships a silently substituted value; after D4 it errors at render. **Mitigation:** this is the design working as intended (the silent substitution was indistinguishable from a bug), but the rollout gate is a full-fleet render pass before/after the library change, so every surfaced conflict is triaged as a found bug, not a regression report from a user.
- **Kernel finalize mishandles an edge and drops absence.** If finalization materializes unset optional config fields (or mangles `#Secret` values), D5's absence signal dies at the source and blueprint/transformer defaults stop firing. **Mitigation:** OQ3's experiment gates promotion; absence preservation is an explicit accepted→implemented test.
- **Blueprint narrowing rejects values the fleet already uses.** Kind-invalid values that previously vetted clean (and failed at apply) become vet errors: correct, but a hard break for any module carrying one. **Mitigation:** fleet-wide vet against the narrowed catalog before release; each hit is a latent apply-time failure being surfaced early.

**Toolchain and compatibility risks.**

- **The CUE closedness regression interacts with new blueprint conjunctions.** The workspace pins a `cue` line with a known guard-closedness bug (hoisted-guard workaround documented in catalog_opm). New narrowing structs under conditional schemas (`rollingUpdate` under `if type == …`) may trip it. **Mitigation:** the param-level narrowing is explicitly marked untested in D3; the catalog slice validates against the pinned toolchain and falls back to type-level-only narrowing if the bug fires.
- **A fleet module quietly comes to depend on kernel-only resolution.** A module using the collision pattern renders fine via `opm` but fails any downstream plain-CUE `export` consumer; nothing in `cue vet` flags it (C1 passes). **Mitigation:** the D8 matrix keeps the divergence visible in CI; OQ5 considers a warning gate; the SHOULD in D8 gives reviewers a citable rule.

## Drawbacks

- **Two observable output shifts if OQ4 lands catalog-first.** Blueprint defaults make `strategy:` blocks appear in rendered output; a later silent-posture decision (OQ1) would remove them again. Landing order and posture decisions trade rollout simplicity against output stability.
- **The kernel gains semantics.** "Config is finalized before composition" is one more thing a kernel contributor must know that pure-CUE reasoning about the module files will not reveal. Codified in SPEC §6 L5, but it is genuine hidden machinery.
- **The layer contract is discipline, not physics, until the gates exist.** Between this design landing and the cli gate slices, L1–L4 hold by review only: same enforcement gap core's §5 publish gates already live with.
- **Blueprint authors take on per-kind API fidelity.** Narrowing tables must track upstream Kubernetes (new strategy types, new rollingUpdate params). The trait union stays loose, so upstream additions require touching each affected blueprint.

## Alternatives

- **In-language layered defaults (`SetLayer`).** Per-file default priority inside the evaluator. **Why not:** prototype-status internal API with a documented soundness bug; detail in D4.
- **Defaults-everywhere (concretize every schema).** Give every trait schema a default so everything renders. **Why not:** wrong layer (kind-blind), spends every field's single default slot, cannot rescue undefaultable or object-emitting traits; detail in D2.
- **Documentation-only (keep the mechanics, teach the workarounds).** Ship §6 as author guidance and leave projections, kernel, and blueprints as they are. **Why not:** the measured baseline (a non-rendering template, 11 force-set traits, fleet boilerplate) is the outcome of exactly this alternative.
