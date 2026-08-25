# 02-attest-cue-manifest — Artifact Provenance, Signatures and Platform Trust Policy

Status: Draft

## Hypothesis

SLSA provenance for a CUE module manifest digest can be produced in a GitHub Actions workflow both by `actions/attest-build-provenance` (subject by name and digest, pushed to the registry) and by a `slsa-github-generator` reusable workflow, and each is verified by `gh attestation verify` / `slsa-verifier` naming the level it certifies. Settles OQ4.

## Setup

A workflow in a throwaway branch of the `modules` repo (or a scratch repo in the organization) that publishes the fixture from experiment 01, captures the manifest digest, and runs both attestation paths. Record: the provenance predicate (builder id, source, materials), where each lands (referrer, log), and the verifier output. Note whether the container generator accepts a non-image OCI subject or refuses it.

## Run

Exact commands to reproduce the result:

```bash
gh workflow run e0023-attest.yml
gh attestation verify oci://ghcr.io/open-platform-model/testing.opmodel.dev/modules/e0023@sha256:<digest> --owner open-platform-model
slsa-verifier verify-image ghcr.io/open-platform-model/testing.opmodel.dev/modules/e0023@sha256:<digest> --source-uri github.com/open-platform-model/<repo>
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` or `07-questions.md` next to what it settles.
