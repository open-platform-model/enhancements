# Operational Concerns: Artifact Provenance, Signatures and Platform Trust Policy

This document is the OPM Production Readiness Review (PRR-lite). Answers are provisional while the entry is open.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

A verification verdict per artifact (`contracts/contracts.cue` `#Verdict`): the resolved digest, the claims found, the identities checked, the policy applied and the outcome. Surfaced in the CLI's build and apply reports, in `opm registry verify`, and as an operator status condition on the Platform naming the failing subscription and reason. Release workflows gain an attest and sign step whose failure fails the release.

## Semver Impact

**Is this a breaking change for any consumer?**

Not by itself. Attachments are invisible to CUE and to every current consumer. A platform with no policy verifies nothing (or warns, per OQ5's default). The core surface for the policy (OQ3) is additive. Enhancement-level `semver`: to be set once OQ3 decides whether core changes (`minor` expected).

## Deprecation

**What gets removed and when?**

Nothing. Unverified materialization remains available under a `warn` mode; whether a future default flips to `refuse` is a dated policy decision made when first-party artifacts are fully attested.

## Rollback

**If this lands and proves bad?**

Attachments are inert; stop writing them. The kernel's verification step is disabled by policy absence. Nothing already published changes. The one irreversible part is any claim already in a transparency log, which is a public record by design.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Provisional ordering:

1. Release workflows (`catalog_opm`, `modules`, `core`, cli templates) attest and sign on publish. No consumer depends on this yet.
2. `core` gains the policy surface, if OQ3 lands it there, after 0019's platform reshape.
3. `library` adds verification in materialize and acquire.
4. `cli` (verify command, reporting, publish-side helpers) and `opm-operator` (enforcement) land together.

This entry lands after 0019 (the subscription shape the policy attaches to) and alongside or after 0022 (whose `catalogs` map is the recursive verification list, OQ6). Landings are logged in `delivery.yaml` as they happen.
