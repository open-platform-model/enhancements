# 01-ghcr-referrers-push — Artifact Provenance, Signatures and Platform Trust Policy

Status: Draft

## Hypothesis

A referrer manifest (subject = a CUE module manifest digest) pushed to GHCR is listed by the OCI 1.1 referrers API, or, failing that, by the `sha256-<digest>` fallback tag; and the same holds on the local registry `task registry:start` runs. Backs D1 and decides whether the attachment contract may name the API.

## Setup

Push a throwaway fixture module under `testing.opmodel.dev/modules/e0023@v0` (GHCR, via the fixtures path CI uses, or the local registry as a rule 3 override; say which) and attach an empty in-toto statement to its manifest digest with `oras attach --artifact-type application/vnd.in-toto+json`. Then query `GET /v2/<repo>/referrers/<digest>` and the fallback tag, with `oras discover` and raw `curl`. Record status codes and bodies for both registries. Nothing under `opmodel.dev/*` is written.

## Run

Exact commands to reproduce the result:

```bash
oras attach --artifact-type application/vnd.in-toto+json ghcr.io/open-platform-model/testing.opmodel.dev/modules/e0023@sha256:<digest> statement.json
oras discover ghcr.io/open-platform-model/testing.opmodel.dev/modules/e0023@sha256:<digest>
curl -s -H "Authorization: Bearer $TOKEN" https://ghcr.io/v2/open-platform-model/testing.opmodel.dev/modules/e0023/referrers/sha256:<digest>
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` or `07-questions.md` next to what it settles.
