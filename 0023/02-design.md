# Design — Artifact Provenance, Signatures and Platform Trust Policy

This design is intentionally thin. D1 and D2 fix the attachment channel and the policy owner, which are settled; everything below the diagram is a sketch to be confirmed or replaced by the research and experiments listed in `07-questions.md`.

## Design Goals

- A consumer can establish, for any first-party catalog or module, who built it, from what, and who vouches for it, using only the registry.
- A platform states whom it trusts, once, and every materialization checks against it.
- Verification runs before an artifact's content is used, in the kernel, so the CLI and the operator behave identically.
- CUE's package manager needs no change: everything attaches beside the manifest, never inside it.
- The reachable assurance level is stated honestly per artifact, not assumed.

## Non-Goals

- **Operating keys.** Identity-based (keyless) signing against a public transparency service; OPM holds no signing keys.
- **Content correctness.** Provenance says who built it from what; the publish gates and vet say whether it is right.
- **Protecting the source repository.** Branch protection and commit signing are repository policy.
- **A digest lock.** 0022's block may grow one; verification here assumes the digest the platform resolved and checks claims about it.

## High-Level Approach

```text
   release workflow (CI)                         registry (GHCR)
   ┌──────────────────────────┐                 ┌──────────────────────────────────┐
   │ opm … publish            │── manifest ───► │ tag v2.0.1 -> manifest sha256:c6…│
   │ attest (SLSA provenance) │── referrer ───► │   referrer: in-toto provenance   │
   │ sign (keyless identity)  │── referrer ───► │   referrer: signature bundle     │
   └──────────────────────────┘                 └──────────────────────────────────┘
                                                                 │
   platform (trust policy, D2)                                   │ resolve + list referrers
   ┌──────────────────────────┐        kernel                    ▼
   │ registry:                │   ┌────────────────────────────────────────────┐
   │   catalogs/opm@v2:       │──►│ verify(manifest digest, referrers, policy) │──► refuse | warn | proceed
   │     version, trust {…}   │   │   signer identity ∈ policy.signers         │
   │ trust (platform-wide)    │   │   builder id ∈ policy.builders             │
   └──────────────────────────┘   │   subject == resolved digest               │
                                  └────────────────────────────────────────────┘
                                        ▲                       ▲
                                   opm (CLI)               opm-operator
```

**Attachment (D1).** Provenance and signatures are OCI referrers whose `subject` is the artifact's manifest digest. CUE's client ignores them and its mirror carries them. The registry's referrers support (API or fallback tag) is measured in experiment 01.

**Production.** In the release workflow, after `opm … publish` yields the manifest digest: generate SLSA provenance and sign, both with the workflow's own identity through a public transparency service. Whether provenance is produced by a reusable, isolated workflow (SLSA L3) or by the artifact repo's own workflow (L2) is OQ4 and experiment 02.

**Policy (D2).** The platform declares trust: which signer identities and which builders it accepts, platform-wide and overridable per subscription. The shape, and whether policy is part of `#Platform` in core or a platform-package sibling, is OQ3; `schemas/target.cue` sketches one option.

**Verification.** One kernel function: given a resolved manifest digest, the artifact's referrers and a policy, produce a verdict. It runs in `materialize` before a subscription's content is trusted and in the CLI's acquire path. Whether it must consult the transparency log online, or may verify an embedded bundle offline, is OQ5.

**Enforcement.** The operator refuses to reconcile a platform whose subscriptions fail policy; the CLI reports and, under a flag, refuses. A verification command exists for one artifact on demand.

## Schema / API Surface

Sketch only; every field is OQ-marked in [`schemas/target.cue`](schemas/target.cue) and [`contracts/contracts.cue`](contracts/contracts.cue).

- **Core (OQ3):** a trust-policy surface on `#Platform`: accepted signer identities (issuer plus subject pattern), accepted builder identities, a required assurance level, and a mode (`refuse | warn`). Per-subscription override of the platform default.
- **Kernel:** `Verify(digest, referrers, policy) -> Verdict`, called from materialize and acquire.
- **CLI:** attestation and signing in publish's release path (CI-only, as publishing is); `opm registry verify <path@version> [--platform]`; verdict reporting in `instance build`/`apply`.
- **Operator:** policy enforcement in Platform reconciliation; a condition naming the failing subscription and reason.

## Integration Points

- `cli/internal/publish/` (0011): the release path gains attest and sign; `registry check` gains verification.
- `library/opm/materialize/` and `kernel.AcquireModuleFromRegistry`: the verification hook.
- `core/src/platform.cue` (through 0019's reshape): the policy surface.
- `opm-operator`: enforcement and status conditions.
- `catalog_opm`, `modules`, `core`, cli templates: release workflows produce attestations.

## Before / After

**Before:** `resolve tag -> fetch -> render`. Trust is the registry's word.

**After:** `resolve tag -> list referrers -> verify against the platform's policy -> fetch -> render`, with the verdict in the CLI's report and the operator's status, and a one-command check for any artifact.
