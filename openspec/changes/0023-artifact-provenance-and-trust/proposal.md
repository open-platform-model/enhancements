# 0023: Artifact Provenance, Signatures and Platform Trust Policy

Every OPM release carries a signed record of who built it from what, and a signature. A platform says whose signatures it trusts, and OPM checks every artifact against that before it uses it.

## Why

A published OPM artifact is an OCI manifest with two blobs and nothing else. It has no signature and no record of who built it. A consumer that resolves a version tag trusts the registry's word, and CUE keeps no digest lock. This was measured on a shipped module on 2026-08-25. Nothing in OPM can tell a release build from a push with a stolen token.

## What Changes

- Every first-party catalog and module release carries build provenance and a signature, both produced by the release workflow.
- The claims attach beside the artifact, never inside it. CUE's tooling needs no change.
- A platform declares whom it trusts: the signer identities and builders it accepts, for the whole platform or per subscription.
- Every artifact the platform materializes is checked against that policy before its content is used.
- The CLI and the operator reach the same verdict. The operator enforces it and the CLI reports it.

## What this is not

- Not key infrastructure. OPM holds no signing keys.
- Not content validation. The publish gates own that.
- Not a dependency digest lock. That belongs to enhancement 0022.
- Not image-level SBOM or VEX documents, and not source-repository policy such as branch protection.
- Not the signing of third-party artifacts. The platform policy decides whether to accept them.

## Example

```text
list claims   -> provenance and signature for the resolved digest
verify        -> signer and builder are in the platform's policy
              -> the claim names the digest that was resolved
fetch, render -> only after the check passes
```

## Capabilities

- **New:** `artifact-claims`, `platform-trust-policy`

## Impact

- **Release engineers** gain an attest and sign step in each release workflow. Publishing is already CI-only, so no author flow changes.
- **Platform teams** write one trust policy and read the verdict of any artifact on demand.
- **Six repos** change: core, library, catalog_opm, modules, cli and opm-operator. The change is not breaking: attachments are invisible to every current consumer.

## Open questions

- Blocking: Does the capability manifest, a render-derived statement of what a module needs (cluster-scoped kinds, RBAC, custom resource definitions, webhooks), belong in this entry? Options: keep it here, split it into its own entry that rests on the attachment and policy stances, or drop it. It decides the scope of the entry.
- Blocking: Do advisories belong here? An advisory is a signed, artifact-attached statement that a version is withdrawn or vulnerable, surfaced when the artifact is resolved. It differs in who issues it (the author, after release) and when it is checked (every resolve). Options as for the capability manifest.
- Blocking: What is the shape of the trust policy and where does it live? Settle whether it is a field of the core platform or a sibling in the platform package the operator generates, whether it is keyed per registry entry, per prefix, or platform-wide with overrides, and the vocabulary for identities.
- Blocking: Which SLSA level do the release workflows reach, per artifact family? A level published as a promise needs measured evidence. The artifact repo's own workflow gives level 2 at best. Level 3 needs provenance from an isolated, reusable builder.
- Blocking: Is verification online or offline, and what is the default mode? Settle whether the kernel requires the transparency log, accepts an embedded bundle or is configurable per platform, and whether a platform with no policy verifies nothing, warns or refuses.
- Not blocking: Does verification walk dependencies (the catalogs and core that a verified module pins), and what policy applies to each level?
- Not blocking: How do attestation and signing work on the local registry and in the laptop demo, which has no external services? Options: run unverified, use a local trust root, or warn.
- Not blocking: Does verification by rebuild complement signing? The module zip is deterministic. If a rebuild from the attested commit reproduces the manifest digest, a second check needs no signing service.
