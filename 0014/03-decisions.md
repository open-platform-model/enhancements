# Design Decisions — Export a Deployed Instance as GitOps Manifests

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: The exported unit is the instance's apply envelope, not the bare CR

**Kind:** contract

**Decision:** `opm instance export` emits a directory containing the `ModuleInstance` plus the `Namespace`, the applier `ServiceAccount`, its RBAC, and a `kustomization.yaml` listing them — one directory per instance. It does not emit repo-level Flux wiring (`OCIRepository`, Flux `Kustomization`), and it does not emit a bare CR.

**Alternatives considered:**

- **Bare `ModuleInstance` only.** Rejected: the CR references a `ServiceAccount` by name for impersonated apply, and neither that account nor its authorization nor the namespace exists as a file anywhere. A repo containing only the CR either fails to reconcile or silently applies under the controller's own identity (`opm-operator/cmd/main.go:101`). It is also barely more than `kubectl get -o yaml`, which is the workaround this enhancement exists to replace.
- **Envelope plus Flux wiring.** Rejected as the default: the `OCIRepository` and Flux `Kustomization` are one per repository, not one per instance — `opm-kind-demo/bootstrap/flux/` holds exactly one of each for the entire demo bundle. Emitting them per instance produces N copies of a singleton that conflict on the first apply. Repo bootstrapping is a separate command's job.
- **CUE-native (`instance.cue` plus `ModulePackage`).** Deferred, not rejected. It keeps CUE typing instead of flattening values to YAML, but it targets a different operator path (fetch a CUE package from a Flux source, rather than resolve a published module by coordinate) and it is not the model the demo or the existing CRs use. Revisit as a second output mode once the YAML mode has landed.

**Rationale:** The exported set must be applicable with nothing else present. The envelope is exactly the boundary at which that becomes true, and exactly the shape the hand-written reference (`opm-kind-demo/jellyfin/moduleinstance.yaml`) already has — so the export produces what an experienced user would have written, rather than a new dialect.

**Source:** User decision 2026-07-29.

### D2: Export refuses to write unless the published module reproduces the deployed render

**Kind:** contract

**Decision:** Export runs handoff's precondition chain before writing any file: cluster gates, CR existence, non-local render provenance, concrete `spec.module`, a recorded `status.lastAppliedRenderDigest`, and a strict-registry verification render whose digest equals it. A failure aborts with nothing written. `--force` bypasses the digest comparison only, exactly as it does for handoff; it does not relax the provenance or resolvability gates.

**Alternatives considered:**

- **Best-effort scaffold.** Dump what the cluster holds, warn on anything suspect, let the user review before committing. Rejected: it reproduces the defect of the manual workaround rather than fixing it. The failure mode this enhancement exists to prevent — a committed document that describes something other than what is running — is precisely the one a warning does not prevent, because the file has already been written and the next `git add` is unconditional.
- **Verify after writing, as a separate `opm instance export --check`.** Rejected: a two-step guarantee is one the user can skip, and the expensive part (the registry render) is paid either way.

**Rationale:** Committing the directory changes who applies the instance from then on. Handoff, which changes strictly less (the manager, not the source of truth), already refuses to proceed on an unverified render. Anything weaker here would make the more consequential operation the less careful one. The gate is also nearly free to build: `VerificationDigest` exists and is already exercised on this exact question.

**Source:** User decision 2026-07-29.

### D3: `spec.values` is written verbatim, with a warning

**Kind:** contract

**Decision:** The exported `ModuleInstance` carries the live CR's `spec.values` byte-for-byte. The command prints a warning that the values were written to disk unredacted and that OPM cannot yet identify which of them are secret. There is no redaction mode and no refusal on suspected secrets.

**Alternatives considered:**

- **Refuse unless `--allow-plaintext-values`.** Rejected for now: the CLI has no reliable way to tell which values are secret. Enhancement [0013](../0013/) is the design that introduces attribute-declared secret fields, and building a refusal on top of a detector that does not exist would either gate on 0013 or produce false confidence from heuristics (key-name matching).
- **Redact with placeholders.** Rejected: it breaks D2's guarantee outright. A redacted document no longer renders to the deployed digest, so the export could no longer claim the committed tree reproduces what is running — trading a verified artifact for a partial one that still requires manual completion.

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

---

## Open Questions

- **OQ1: What does export write for `spec.serviceAccountName` and `spec.prune`, which the live CR does not carry?** Status: open. `ApplySpec` (`cli/internal/inventory/store.go:119`) never writes either field, so a CLI-applied, handed-off instance has neither. Both are apply-bearing rather than render-bearing — they do not enter the render digest — so completing them cannot break D2's guarantee, but it does make the exported document differ from the live object. Three candidates: (a) mirror the live CR exactly, producing a document that applies as the controller and orphans on delete, and say so loudly; (b) complete them to the demo's shape (a namespace-local `opm-applier` account, `prune: true`) and report each completion; (c) require explicit flags (`--service-account`, `--prune`) and refuse when the live CR is silent. The design currently assumes (b) plus reporting. Resolving this needs a view on whether an export may improve on what it exports, or must only transcribe it. Note that (b) also changes deletion behaviour from orphan to prune, which is a real behaviour change even though it is the safer default.
- **OQ2: What does the RBAC document contain?** Status: open. The demo binds `cluster-admin` and its own comment flags that as a demo-only shortcut — emitting it from a tool would propagate the shortcut into every user's repo. Candidates: (a) a `ClusterRoleBinding` to `cluster-admin` with a prominent comment, matching the demo; (b) an empty `Role`/`RoleBinding` skeleton with a comment telling the user to fill it in, which produces a tree that does not work until edited; (c) derive a least-privilege `Role` from `status.inventory` — the entry list holds the exact GVK, namespace, and name of every resource the instance owns, which is precisely the authorization surface the applier needs. Option (c) is attractive and is only correct for the current render: a module upgrade that adds a resource kind would fail until the Role is regenerated. Resolving this needs a decision on whether generated RBAC is a starting point or a maintained artifact.
- **OQ3: Can a CLI-owned instance be exported?** Status: open. If export emits an operator-managed CR for an instance whose live `spec.owner` is still `cli`, then committing and applying that tree performs a handoff — without handoff's post-flip verdict, its stale-snapshot guard (0006 LD4a), or its bounded wait. Candidates: (a) refuse, directing the user to run `opm instance handoff` first, keeping the two operations sequential and each verified; (b) allow with a warning that applying the tree constitutes the handoff; (c) allow and preserve `spec.owner: cli`, producing a document that keeps the CLI as the applier, which is coherent but is not GitOps in any useful sense. (a) is the conservative reading of D2.
- **OQ4: How does the exported CR interact with the field managers already owning its fields?** Status: open. The live CR's spec fields are owned by the `opm-cli` field manager (`ApplySpec`) and, post-handoff, partly by the operator. Flux's kustomize-controller applies with its own manager, so the first GitOps apply is a server-side-apply conflict on exactly the fields the export copied. This needs to be established empirically rather than reasoned about: whether Flux's default force-apply resolves it cleanly, whether the resulting ownership transfer is stable, and whether Flux's `Kustomization.spec.prune` interacts badly with the operator's own finalizer and `spec.prune` on the same object. An experiment under `experiments/` is the right instrument. This is the highest-risk unknown in the entry, because it decides whether the adoption is as quiet as D2's guarantee implies.
- **OQ5: Do the CR's own OPM labels belong in the exported document?** Status: open. `crLabels` (`cli/internal/inventory/store.go:311`) stamps `app.kubernetes.io/managed-by` plus the instance name and namespace labels onto the CR itself. Keeping them in the export hands their ownership to Flux; dropping them means the first GitOps apply removes labels the CLI put there, which is a (harmless-looking) change to a live object during what is meant to be a no-op adoption. Related to OQ4 and probably answered by the same experiment.
- **OQ6: Should the CLI know that an instance is now git-managed?** Status: open. After the tree is committed, `opm instance apply` against the same instance writes a spec that Flux will revert on its next reconcile — the CLI becomes a drift source, silently. Candidates: (a) nothing, documentation only; (b) export stamps an annotation (`module-instance.opmodel.dev/source: gitops` or similar) that the apply path reads and warns on; (c) the apply path detects a Flux field manager on the object and warns generically, which needs no new annotation and also covers instances that reached git some other way. (c) is cheap and does not add a field to the CR; whether it belongs in this entry or in a follow-on is part of the question.
