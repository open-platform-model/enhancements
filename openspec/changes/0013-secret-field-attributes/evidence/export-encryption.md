# Why an encrypted export works with Flux

Condensed from D26 of `0013/03-decisions.md`. Mockup note.

- Discovery already yields exactly the paths to encrypt.
- Flux's decryptor keys on the SOPS metadata in the file, not on the kind of object. So an encrypted `ModuleInstance` is decrypted before it reaches the API server.
- Source: read from the kustomize-controller source during the 2026-09-30 feasibility review.
