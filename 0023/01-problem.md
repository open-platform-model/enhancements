# Problem Statement — Artifact Provenance, Signatures and Platform Trust Policy

## Current State

A published OPM artifact, as fetched from GHCR on 2026-08-25 (`opmodel.dev/modules/cert_manager` v2.0.1; full dump in `research/findings.md`), is:

- one OCI manifest (`sha256:c6b0be46…`), with a config blob of `{}` typed `application/vnd.cue.module.v1+json`, a zip layer (230 268 bytes) and a module-file layer (226 bytes);
- **no annotations** on the manifest;
- **no referrers**: the OCI 1.1 referrers endpoint answers 404, and the fallback `sha256-<digest>` tag does not exist.

So nothing signed travels with the artifact. Who published it, from which commit, on which builder, is unrecorded; and no consumer asks. The CLI's publish pipeline calls the plain `PutModule` (0011, `cli/internal/publish/registry.go`) and stops. The kernel's acquire path resolves a tag to a manifest and trusts what it gets. The operator materializes a platform's subscriptions the same way.

CUE's package manager adds no protection of its own here: `cue.mod/module.cue` records versions, not digests (no sum field exists in the module-file schema, and the module cache verifies nothing beyond OCI content addressing). A pin names whatever manifest the tag points at when fetched. Immutability is a registry promise (0011 D10), not something a consumer can check.

What CUE does do is useful: its registry client mirrors **referrers** along with a module (`modregistry` `mirrorReferrers`), so claims attached beside a manifest survive a `cue mod mirror`, and it ignores referrers otherwise. The attachment channel exists and is empty.

## Gap / Pain

1. **No provenance.** A malformed or malicious artifact cannot be traced to a build. A consumer cannot tell a release-CI build from something pushed with a stolen token.
2. **No authenticity.** Nothing distinguishes a first-party catalog from a look-alike on another registry except the path the consumer typed.
3. **No policy surface.** Even if signatures existed, a platform has no way to say "I accept artifacts signed by these identities, built by these workflows". The platform pins exact versions (0019 D5) but not who may have produced them.
4. **No verification point.** Neither the kernel nor the operator has a step between "resolved a manifest" and "trusted its blobs".

The two optional gaps this entry may also take on (OQ1, OQ2): a platform operator cannot learn what cluster-level power a module demands without rendering it, and there is no signed way to withdraw or flag a published version.

## Concrete Example

A platform subscribes to `opmodel.dev/catalogs/opm@v2` at `2.0.0-alpha.5` and materializes `opmodel.dev/modules/cert_manager` v2.0.1. Today:

```text
resolve tag        -> manifest sha256:c6b0be46…      (trust: the registry said so)
fetch blobs        -> zip, module.cue                (trust: OCI content addressing)
render, apply      -> 10 ClusterRoles, 6 CRDs, webhooks, a namespace
```

With this entry, between the first and second line:

```text
list referrers     -> provenance (SLSA, subject sha256:c6b0be46…), signature
verify             -> signer is the expected release identity; builder is the expected workflow;
                      source is github.com/open-platform-model/modules at commit X
compare to policy  -> platform accepts this signer and builder for opmodel.dev/modules/*
```

and a failure at any step refuses the materialization with a message naming what was expected and what was found.

## User Stories

- As a **platform operator**, I want the platform to declare whom it trusts and have every materialized artifact checked against that, so that a compromised token or a look-alike registry cannot put unreviewed CUE into my clusters. Today: no policy exists and nothing verifies.
- As a **release engineer**, I want provenance and signatures produced by the release workflow itself, so that the claim is about the build and not about whoever ran a command. Today: publish pushes and stops.
- As a **module or catalog consumer**, I want one command that tells me whether a given artifact is authentic and where it came from. Today: I read a changelog.

## Why Existing Workarounds Fail

- **Trust the registry's immutability.** Protects against tag re-pointing only if the registry enforces it and only against accidents, not against a push with a valid token.
- **Sign the git tag.** Attests the source, not the artifact; nothing links the manifest digest to the tag, and nothing on the consumer side checks git.
- **Put the commit in an annotation** (0022 D6). A useful pointer, unsigned; anyone who can push can write it.
- **Verify by rebuilding.** Possible thanks to the deterministic zip (0011 D2) and worth doing (experiment 04), but it needs the source and a toolchain at verification time; it complements provenance rather than replacing it.
