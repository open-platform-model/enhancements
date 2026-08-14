# Risks, Drawbacks, Alternatives — Initialize a Module Instance Package from a Published Module

This document records the honest costs of the proposed design. Risks
describe what could go wrong; Drawbacks describe what definitely costs
something; Alternatives describe the high-level paths not taken (per-
decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **Debug content shipped to production.** The D2 fallback templates `debugValues` — a field whose contract is testing — into a file users will edit *from*, and some will deploy *as-is*: throwaway hostnames, permissive settings, dummy credentials land in a real namespace. Blast radius: per-instance misconfiguration, worst case a security-relevant default left in place. **Mitigation:** the report line names the source (`Values template: debugValues`) plus an explicit review warning in `#InstanceInitReport.warnings`; D3's dedicated field is the structural fix, letting authors curate what init emits; OQ5 may additionally gate init on `#config` conformance so at least invalid debug content never scaffolds silently.
- **Two example-values fields drift apart.** Once `initValues` exists, authors maintain two values-shaped fields; the one they forget to update on a `#config` change goes stale, and init happily scaffolds stale content. Blast radius: broken first `opm instance build` for new users of that module — the exact failure init exists to remove. **Mitigation:** OQ1/OQ5 can make conformance to `#config` checked (schema-side or at init/publish time via 0011's gates), converting silent staleness into a visible error at the author's desk rather than the user's.
- **Generated pins go stale by design.** Init pins the resolved version at scaffold time; the package keeps deploying that version forever unless the user bumps it. A user who expected "latest" semantics ships an old module indefinitely. Blast radius: per-instance, low severity, discovered at upgrade time. **Mitigation:** pinning is the correct GitOps default and is stated in the command output; version-bump ergonomics are an explicit non-goal here and belong to the existing dep-update tooling story.
- **The scaffold shape and the loader drift.** If OQ4 resolves to a CLI-side renderer, the instance-file shape exists twice (CLI init, library synth) and a future `#ModuleInstance` change can break one silently. Blast radius: init emits packages `LoadInstancePackage` rejects — a hard, visible break, but in the wrong repo's release. **Mitigation:** the accepted→implemented gate requires an end-to-end test that loads and builds a generated package through the real loader; OQ4's shared-renderer option removes the duplication outright.

## Drawbacks

- **New core surface that must be maintained forever.** One more optional field on `#Module`, one more SPEC.md section, one more thing `module.Module`'s Go decode surface exposes. Small, additive, but permanent.
- **Author-side burden grows.** Conscientious authors now curate `initValues` in addition to `debugValues`. For modules where the two are identical, the field is pure duplication (authors can mitigate in CUE by writing `initValues: debugValues` — at the cost of making the fallback explicit rather than implicit).
- **The CLI grows a second scaffolding subsystem.** `opm module init` renders embedded static templates; `opm instance init` renders from an acquired artifact. Two generators with different mechanics under one verb, which documentation must keep distinct.

## Alternatives

- **No core change — `debugValues` is the permanent template source.** One-field simplicity. **Why not:** permanently rewrites `debugValues`' contract into a public onboarding surface, forcing authors to sanitize their debug fixtures or accept leaking them (D3's alternatives).
- **Interactive wizard instead of a field.** Prompt the user per `#config` field, build `values.cue` from answers. **Why not:** requires evaluating and walking arbitrary constraint schemas interactively — far more machinery for a worse GitOps story (non-reproducible, non-scriptable); could layer on later without conflicting with this design.
- **Server-side/registry-side templates.** Ship a rendered instance-package example as a separate artifact beside the module. **Why not:** a second distribution channel with its own packaging, versioning, and validation rules; the values content belongs inside the schema-validated module artifact it describes (D3's alternatives).
