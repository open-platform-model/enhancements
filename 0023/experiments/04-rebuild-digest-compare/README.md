# 04-rebuild-digest-compare — Artifact Provenance, Signatures and Platform Trust Policy

Status: Draft

## Hypothesis

Rebuilding `opmodel.dev/modules/cert_manager` v2.0.1 from its release commit with the pinned `opm` and CUE toolchain reproduces the published manifest digest `sha256:c6b0be46…` exactly. Settles OQ8 (rebuild as a service-free verification).

## Setup

Check out the `modules` repo at the commit that produced v2.0.1 (from the release tag), build `opm` at the version that published it (the CLI's release), run `opm module publish --dry-run` into a local registry, and compare the manifest and both layer digests with the values in `research/findings.md`. Record the toolchain versions and any nondeterminism found (zip timestamps, ordering).

## Run

Exact commands to reproduce the result:

```bash
git -C modules checkout <release-commit-of-cert_manager-v2.0.1>
task registry:start
CUE_REGISTRY='opmodel.dev=localhost:5000+insecure' opm module publish ./modules/cert_manager   # local only, explicit
curl -s localhost:5000/v2/opmodel.dev/modules/cert_manager/manifests/v2.0.1 -H 'Accept: application/vnd.oci.image.manifest.v1+json' | sha256sum
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` or `07-questions.md` next to what it settles.
