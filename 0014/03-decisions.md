# Design Decisions: Export a Deployed Instance as GitOps Manifests

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now. A reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass: the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: The exported unit is the instance's apply envelope, not the bare CR

**Kind:** contract

**Decision:** `opm instance export` emits a directory containing the `ModuleInstance` plus the `Namespace`, the applier `ServiceAccount`, its RBAC, and a `kustomization.yaml` listing them, one directory per instance. It does not emit repo-level Flux wiring (`OCIRepository`, Flux `Kustomization`), and it does not emit a bare CR.

**Alternatives considered:**

- **Bare `ModuleInstance` only.** Rejected: the CR references a `ServiceAccount` by name for impersonated apply, and neither that account nor its authorization nor the namespace exists as a file anywhere. A repo containing only the CR either fails to reconcile or silently applies under the controller's own identity (`opm-operator/cmd/main.go:101`). It is also barely more than `kubectl get -o yaml`, which is the workaround this enhancement exists to replace.
- **Envelope plus Flux wiring.** Rejected as the default: the `OCIRepository` and Flux `Kustomization` are one per repository, not one per instance. `opm-kind-demo/bootstrap/flux/` holds exactly one of each for the entire demo bundle. Emitting them per instance produces N copies of a singleton that conflict on the first apply. Repo bootstrapping is a separate command's job.
- **CUE-native (`instance.cue` plus `ModulePackage`).** Deferred, not rejected. It keeps CUE typing instead of flattening values to YAML, but it targets a different operator path (fetch a CUE package from a Flux source, rather than resolve a published module by coordinate) and it is not the model the demo or the existing CRs use. Revisit as a second output mode once the YAML mode has landed.

**Rationale:** The exported set must be applicable with nothing else present. The envelope is exactly the boundary at which that becomes true, and exactly the shape the hand-written reference (`opm-kind-demo/jellyfin/moduleinstance.yaml`) already has, so the export produces what an experienced user would have written, rather than a new dialect.

**Source:** User decision 2026-07-29.

### D2: Export refuses to write unless the published module reproduces the deployed render

**Kind:** contract

**Depends:** 0006:D7, 0006:D38

**Decision:** Export runs handoff's precondition chain before writing any file: cluster gates, CR existence, non-local render provenance, concrete `spec.module`, a recorded `status.lastAppliedRenderDigest`, and a strict-registry verification render whose digest equals it. A failure aborts with nothing written. `--force` bypasses the digest comparison only, exactly as it does for handoff; it does not relax the provenance or resolvability gates.

**Alternatives considered:**

- **Best-effort scaffold.** Dump what the cluster holds, warn on anything suspect, let the user review before committing. Rejected: it reproduces the defect of the manual workaround rather than fixing it. The failure mode this enhancement exists to prevent (a committed document that describes something other than what is running) is precisely the one a warning does not prevent, because the file has already been written and the next `git add` is unconditional.
- **Verify after writing, as a separate `opm instance export --check`.** Rejected: a two-step guarantee is one the user can skip, and the expensive part (the registry render) is paid either way.

**Rationale:** Committing the directory changes who applies the instance from then on. Handoff, which changes strictly less (the manager, not the source of truth), already refuses to proceed on an unverified render. Anything weaker here would make the more consequential operation the less careful one. The gate is also nearly free to build: `VerificationDigest` exists and is already exercised on this exact question.

**Source:** User decision 2026-07-29.

### D3: `spec.values` is written verbatim, with a warning

**Kind:** contract

**Decision:** The exported `ModuleInstance` carries the live CR's `spec.values` byte-for-byte. The command prints a warning that the values were written to disk unredacted and that OPM cannot yet identify which of them are secret. There is no redaction mode and no refusal on suspected secrets.

**Alternatives considered:**

- **Refuse unless `--allow-plaintext-values`.** Rejected for now: the CLI has no reliable way to tell which values are secret. Enhancement [0013](../0013/) is the design that introduces attribute-declared secret fields, and building a refusal on top of a detector that does not exist would either gate on 0013 or produce false confidence from heuristics (key-name matching).
- **Redact with placeholders.** Rejected: it breaks D2's guarantee outright. A redacted document no longer renders to the deployed digest, so the export could no longer claim the committed tree reproduces what is running, trading a verified artifact for a partial one that still requires manual completion.

**Rationale:** Honest about the current capability. The user is told exactly what was written and why OPM cannot judge it, which is more useful than a heuristic that is wrong in both directions. When 0013 lands, secret-bearing values will be `#SecretRef`s in the CR rather than literals, and this decision becomes correct by construction rather than by disclaimer.

**Source:** User decision 2026-07-29.

### D4: The live CR is the sole input

**Kind:** contract

**Decision:** Export reads the `ModuleInstance` from the cluster and nothing else. It does not read the local instance file, accept a values file, or merge local state into the output.

**Alternatives considered:**

- **Export from a local instance file (no cluster).** Rejected as the source of truth: the file may have drifted from what is deployed (an apply with `-f` overrides leaves the file describing something else), and the guarantee in D2 is a statement about what is *running*, which only the cluster can answer.
- **Cluster CR with local-file overlay.** Rejected: reintroduces the transcription question the enhancement removes, and creates a document whose provenance is split between two sources.

**Rationale:** The CR is what handoff verified, what the operator reconciles, and what `status.lastAppliedRenderDigest` describes. Any other input would be an unverified second opinion about the same instance.

**Source:** User request 2026-07-29 ("target a module instance in the cluster and output the manifests").

Open Questions live in [`07-questions.md`](07-questions.md), the entry's question register.
