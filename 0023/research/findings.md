# Research findings — Artifact Provenance, Signatures and Platform Trust Policy

Gathered 2026-08-24 and 2026-08-25. Verified facts are marked **measured**; everything else is a reading of documentation or source and is marked as such. Sources at the bottom.

## 1. What a published OPM artifact is (measured, GHCR, anonymous pull)

`ghcr.io/open-platform-model/opmodel.dev/modules/cert_manager`, tag `v2.0.1`:

- Tags: `v0.0.7 v0.0.8 v0.0.9 v0.1.0 v1.0.0 v1.1.0 v1.1.1 v2.0.1` (one repository holds every major).
- Manifest digest `sha256:c6b0be463c8a32a136c98c102c0115799b7531064e7c185def655b9e646b20b1`, media type `application/vnd.oci.image.manifest.v1+json`.
- Config: media type `application/vnd.cue.module.v1+json`, content `{}` (2 bytes). CUE uses only the media type.
- Layers: `[0]` `application/zip`, 230 268 bytes; `[1]` `application/vnd.cue.modulefile.v1`, 226 bytes (the `cue.mod/module.cue`).
- **No `annotations` on the manifest.**
- Referrers endpoint `GET /v2/<repo>/referrers/<digest>` answered `404 MANIFEST_UNKNOWN`; fallback tag `sha256-<digest>` answered 404. No claims are attached today. Whether GHCR serves the referrers API for artifacts that *have* referrers, or only the fallback tag, is unmeasured (experiment 01).
- Zip contents: `CHANGELOG.md`, `README.md`, `components.cue`, six `crds/*.yaml`, `crds_data.cue` (681 KB), `cue.mod/module.cue`, `identity/identity.cue` (1003 bytes), `module.cue`. The identity package (declared version) is **inside the zip only**.

## 2. CUE's registry client (source reading, cuelang.org/go v0.17.1)

- `GetModuleWithManifest` requires `config.mediaType == application/vnd.cue.module.v1+json` and **exactly two layers**, layer 1 typed as the module file (`mod/modregistry/client.go`). A third layer breaks every CUE consumer; attachments must be referrers or annotations.
- Manifest annotations are decoded into three `org.cuelang.vcs-*` fields; unknown keys are ignored (`mod/modregistry/metadata.go`).
- **The mirror carries referrers**: `Client.Mirror` calls `mirrorReferrers` for the source manifest digest (`client.go`, `mirrorReferrers`). A claim attached as a referrer survives `cue mod mirror`.
- **No digest lock.** The module-file schema (`mod/modfile/schema.cue`) has no sum or digest field; the module cache (`mod/modcache/fetch.go`) verifies nothing beyond fetching blobs by the digests the manifest names. A version pin resolves to whatever manifest the tag points at.
- `cue mod publish` pushes the zip and the module file byte-verbatim (`client.go` `PutModule`); the CLI's publish uses the plain `PutModule` and writes no annotations (`cli/internal/publish/registry.go`, cli commit 2370bd6).

## 3. SLSA and Sigstore fit (documentation reading, unverified against OPM's CI)

- SLSA v1.0 build provenance is an in-toto Statement whose subject is a digest; any OCI manifest digest qualifies, including a CUE module manifest. Levels: L1 provenance exists; L2 hosted, signed provenance; L3 provenance from an isolated builder user steps cannot forge.
- GitHub's artifact attestations (`actions/attest-build-provenance`) produce SLSA v1 provenance, sign it through Sigstore (keyless, OIDC identity of the workflow), record it in the public transparency log, and can push it to a registry as a referrer when given an OCI subject by name and digest. GitHub documents this as Build L2; the reusable `slsa-github-generator` workflows are the documented path to L3 and are written for container images and generic blobs, not CUE manifests: whether the container generator accepts an arbitrary OCI manifest digest is what experiment 02 measures.
- Sigstore `cosign` signs and verifies any OCI artifact by digest, attaching signatures as referrers (or the `sha256-<digest>.sig` tag on registries without the API), and verifies keyless signatures against Fulcio and Rekor. `gh attestation verify` and `slsa-verifier` verify provenance.
- Verification needs: the referrer (or the log entry), the Sigstore trust root, and, for freshness, the transparency log. Offline verification of an embedded bundle is supported by cosign with a reduced guarantee. OQ5.

## 4. Reproducibility (source reading)

- The module zip is produced by `modzip.CreateFromDir` from the author's tree with no generated content (0011 D2). Two builds of the same commit with the same toolchain yield the same zip bytes and therefore the same layer digest; the manifest digest also depends on the config (`{}`) and the module-file blob, both deterministic. Experiment 04 measures whether a rebuild reproduces `sha256:c6b0be46…` for cert_manager v2.0.1.

## 5. Adjacent OPM facts

- 0011 D7: `opm catalog registry check` verifies a published catalog out of band; the natural home of a verification command.
- 0019 D5/D6: a platform subscription imports its catalog and pins an exact version; the operator generates the platform package. The trust policy attaches there (D2).
- 0022: unsigned metadata (kind, identity, pins) in `module.cue`; `org.cuelang.vcs-*` and `dev.opmodel.*` annotations. Hints, not evidence.

## Sources

- GHCR pull of `opmodel.dev/modules/cert_manager` v2.0.1, 2026-08-25 (raw manifest, blobs and referrers responses captured in the session; reproducible with anonymous `curl` against `ghcr.io/v2/`).
- cuelang.org/go v0.17.1: `mod/modregistry/client.go`, `mod/modregistry/metadata.go`, `mod/modfile/schema.cue`, `mod/modcache/fetch.go`.
- SLSA specification v1.0, https://slsa.dev/spec/v1.0/ (levels, provenance predicate).
- GitHub artifact attestations, https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations (Build L2 statement, OCI subjects).
- slsa-framework/slsa-github-generator, https://github.com/slsa-framework/slsa-github-generator (L3 reusable workflows).
- Sigstore cosign, https://docs.sigstore.dev/ (keyless signing, referrers, offline bundles).
- in-toto attestation framework, https://github.com/in-toto/attestation.
