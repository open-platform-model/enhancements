# 05-capability-extract — Artifact Provenance, Signatures and Platform Trust Policy

Status: Draft

## Hypothesis

From one `opm instance build` of a module (cert_manager with `debugValues`), the set of cluster-scoped kinds, RBAC verbs, CRDs, webhook configurations and privileged pod settings can be extracted deterministically and is small enough to attach as a claim. Informs OQ1 (whether a capability manifest belongs here).

## Setup

Render cert_manager and metallb through an `opm` built from cli HEAD against a platform that implements their contracts (`cli/hack/platform.cue`), and post-process the rendered YAML with a script that classifies objects (cluster-scoped kinds, ClusterRole rules, CRDs, webhooks, hostNetwork/privileged). Record the extracted manifest for both modules and its size; note whether it changes between two renders.

## Run

Exact commands to reproduce the result:

```bash
opm instance build ./pkg/instance.cue --platform ../../../../cli/hack/platform.cue > rendered.yaml
python3 extract.py rendered.yaml > capability.json && wc -c capability.json
```

## Outcome

Not yet run. Update `Status:` to `Running` once the experiment is live; `Concluded` once the outcome is recorded, then link the result back into `03-decisions.md` or `07-questions.md` next to what it settles.
