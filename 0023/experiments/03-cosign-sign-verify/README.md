# 03-cosign-sign-verify — Artifact Provenance, Signatures and Platform Trust Policy

Status: Draft

## Hypothesis

A CUE module manifest signed keyless with `cosign sign` verifies with `cosign verify` against the workflow's identity, the signature is listed as a referrer (or fallback tag), and `cue mod mirror` to a second registry carries the signature along. Backs D1; settles the offline half of OQ5 by also verifying with `--offline` against the bundle.

## Setup

Sign the fixture from experiment 01 in CI (keyless, OIDC) and locally with a throwaway key for the offline arm. Mirror the module with `cue mod mirror` to the local registry and list referrers there. Record each verify command's output and the exact identity strings, which become the vocabulary OQ3 needs.

## Run

Exact commands to reproduce the result:

```bash
cosign sign ghcr.io/open-platform-model/testing.opmodel.dev/modules/e0023@sha256:<digest>
cosign verify --certificate-identity-regexp '^https://github.com/open-platform-model/' --certificate-oidc-issuer https://token.actions.githubusercontent.com ghcr.io/...@sha256:<digest>
cue mod mirror --from ghcr.io/open-platform-model --to localhost:5000 testing.opmodel.dev/modules/e0023@v0.0.1
cosign verify --offline --bundle bundle.json ...
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` or `07-questions.md` next to what it settles.
