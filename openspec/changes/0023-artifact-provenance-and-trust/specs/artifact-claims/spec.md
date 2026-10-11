## Purpose

How a signed claim about a published catalog or module, such as its build provenance or a signature, is attached to the artifact so that it names one exact artifact, leaves it unchanged and survives a moved tag.

## ADDED Requirements

### Requirement: A claim names a manifest digest

Every signed claim about a published catalog or module SHALL be a separate OCI artifact whose subject is the manifest digest that the artifact's tag resolves to. A claim SHALL NOT name a tag as its subject.

#### Scenario: A release attaches provenance

- **WHEN** a release attaches build provenance to a module published under a version tag
- **THEN** the provenance names the manifest digest that the tag resolved to at publication, and no tag

### Requirement: Attaching a claim leaves the artifact unchanged

Attaching a claim SHALL leave the CUE module manifest, its config blob and its layers unchanged, so the artifact's digest and the behaviour of CUE's client are unaffected.

#### Scenario: A signature is attached

- **WHEN** a signature is attached to a published module
- **THEN** the module's manifest digest is the same as before
- **AND** CUE's client resolves and fetches the module as it did before

### Requirement: A claim follows the digest, not the tag

A claim attached to a digest SHALL be discoverable from that digest alone, and SHALL stay attached to that digest when the tag is re-pointed.

#### Scenario: A tag is re-pointed

- **WHEN** a version tag is moved to a different manifest
- **THEN** the claims of the earlier digest are still found from that digest
- **AND** the new manifest carries none of them

### Requirement: A claim declares its kind

A claim SHALL declare its kind, so that a verifier can tell provenance from a signature.

#### Scenario: An artifact has both claims

- **WHEN** a verifier lists the claims of an artifact that has provenance and a signature
- **THEN** it identifies which claim is the provenance and which is the signature
