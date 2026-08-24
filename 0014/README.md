# Enhancement 0014 — Export a Deployed Instance as GitOps Manifests

See [`config.yaml`](config.yaml) for metadata. This README is the index of the seven split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

Enhancement [0006](../0006/) shipped `opm instance handoff`, which transfers a CLI-deployed instance to the operator without touching a workload. It moves the manager; it does not move the definition. After a handoff the only complete record of an instance is a live object in etcd, and a user who now wants git as the source of truth has to hand-assemble four YAML documents per instance from a `kubectl get -o yaml` dump.

This entry adds `opm instance export`: read the live `ModuleInstance`, verify the published module still reproduces the deployed render, and write a committable directory — the CR plus the `Namespace`, applier `ServiceAccount`, RBAC, and `kustomization.yaml` that make it applicable on its own.

The design turns on two findings. First, a `kubectl` dump is not merely untidy, it is **wrong**: `ApplySpec` (`cli/internal/inventory/store.go:119`) writes only `spec.module`, `spec.owner`, and `spec.values`, so every CLI-written CR is missing `spec.serviceAccountName` and `spec.prune` — and a document without them applies under the controller's own identity and orphans its workloads on delete. Second, the conversion to GitOps changes who applies the instance from then on, which is a larger commitment than the ownership flip that preceded it; so export inherits handoff's verification gate rather than settling for a warning (**D2**). What makes both possible without conflict is the partition in `02-design.md`: `spec.module` and `spec.values` are render-bearing and are copied verbatim under the digest gate, while apply identity and deletion policy are apply-bearing, absent from the render digest, and can therefore be completed — as long as every completion is reported.

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log — run `task delivery ID=NNNN`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

1. [01-problem.md](01-problem.md) — Handoff moves the manager, not the definition; why a CR dump is incomplete in ways that change apply identity and deletion behaviour
2. [02-design.md](02-design.md) — Read the live CR, run handoff's gate chain, complete the apply-bearing fields, compose a per-instance directory
3. [03-decisions.md](03-decisions.md) — Decision log (D1–D4)
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, Alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination
7. [07-questions.md](07-questions.md) — Open Questions register

Pure-CUE definitions live in [`contracts/contracts.cue`](contracts/contracts.cue) — the request shapes, the ordered gate chain, the render-bearing / apply-bearing / cluster-side field partition (enforced by the schema, so a policy that copied a cluster-side field fails `cue vet`), the exported document set, the report, and the adoption property.

## Scope

### In scope

- `opm instance export <name> -n <ns>` — reads the live `ModuleInstance` CR and writes a per-instance directory of YAML documents (D1). `--all` repeats the same unit across a namespace or the cluster; nothing is merged between directories.
- The exported set is the CR plus its apply envelope: `Namespace`, `ServiceAccount`, RBAC, and a `kustomization.yaml` listing them (D1) — the shape `opm-kind-demo/jellyfin/moduleinstance.yaml` has today, generated instead of typed.
- A verification gate that refuses to write anything unless the published module reproduces `status.lastAppliedRenderDigest` (D2), reusing handoff's precondition chain and its `VerificationDigest` primitive. `--force` bypasses the digest comparison only.
- Field completion for the apply-bearing fields the CLI never writes (`spec.serviceAccountName`, `spec.prune`), with every completion named in the command output — policy pending OQ1.
- `spec.values` copied verbatim with an unconditional warning that OPM cannot yet identify which values are secret (D3).
- The live CR as the sole input (D4) — no local instance file, no values overlay.
- One read-only field on `cli`'s internal `inventory.Record` (`ServiceAccountName`), and lifting `VerificationDigest` into a package both handoff and export call.

### Out of scope

- **Repo-level Flux wiring.** `OCIRepository` and the Flux `Kustomization` are one per repository, not one per instance; emitting them per export would produce N conflicting copies of a singleton. GitOps repo bootstrapping is a candidate follow-on.
- **CUE-native export.** Reconstructing an `instance.cue` plus a `ModulePackage` CR targets a different operator path (fetch a CUE package from a Flux source) and is deferred as a possible second output mode, not rejected.
- **The import direction.** Nothing reads a repo and applies it; nothing continuously compares git against the cluster. After the commit, Flux is the applier and Flux reports drift.
- **Secret detection, redaction, or SOPS / External Secrets integration.** Depends on enhancement [0013](../0013/); until it lands, D3's warning is the honest surface.
- **`ModulePackage` export.** `ModuleInstance` only, matching 0006's boundary.
- **Any change to `core/`, `library/`, or `opm-operator/`.** The export reads an existing CR through an existing read path and writes files.

## Relationship to 0006

0014 is the third step of the path 0006 built. 0006 moved the inventory into the `ModuleInstance` CR (D1) and then moved the *manager* to the operator (D7, D40); 0014 moves the *definition* out of the cluster and into a repository. It reuses 0006's machinery rather than restating it: the same precondition chain, the same `VerificationDigest`, the same local-provenance refusal (D38), and the same success criterion — D40's inventory-stable reconcile, restated in `#AdoptionProperty` for a GitOps applier rather than for the operator's first post-handoff reconcile.

The open risk lives at the seam 0006 never had to cross. Handoff's actors were the CLI and the operator, both of whose field-manager behaviour 0006 verified live. A GitOps apply introduces a third manager (Flux's kustomize-controller) onto fields the first two own, which is why OQ4 is answered by an experiment rather than by argument.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + the area vocabulary `area` / `affects` validate against. |
| `cli/CLAUDE.md`, `cli/CONSTITUTION.md` | CLI repo principles governing every slice of this entry; the command/orchestration split the new command follows. |
| `cli/internal/cmd/instance/instance.go` | The `instance` command group the new `export` subcommand registers on. |
| `cli/internal/cmd/instance/handoff.go` | The closest existing command surface — flag shape and argument handling to mirror. |
| `cli/internal/workflow/handoff/handoff.go` | `runPreconditions` — the gate chain export reuses, minus the ownership arm (OQ3). |
| `cli/internal/workflow/handoff/verify.go` | `VerificationDigest` — the strict-registry verification render; to be lifted into a package both callers use. |
| `cli/internal/inventory/record.go` | `Record` — the read-side view of the CR; gains `ServiceAccountName`. Its `Prune` comment documents the orphan-on-delete behaviour `01-problem.md` cites. |
| `cli/internal/inventory/cr.go` | The unstructured read path that populates `Record`. |
| `cli/internal/inventory/store.go` | `ApplySpec` (line 119) — the CLI's single spec writer, and the reason `spec.serviceAccountName` / `spec.prune` are absent; `crLabels` (line 311) is OQ5's subject. Not modified by this entry. |
| `cli/internal/inventory/discover.go` | Instance listing — what `--all` walks. |
| `cli/internal/output/` | Report rendering and the values warning. |
| `cli/tests/e2e/` | Home of the apply → handoff → export → apply-exported e2e case that asserts `#AdoptionProperty`. |
| `opm-operator/api/v1alpha1/moduleinstance_types.go` | `ModuleInstanceSpec` — the contract the exported CR must satisfy; the four fields the CLI never writes are declared here. |
| `opm-operator/cmd/main.go` | `--default-service-account` — what an empty `spec.serviceAccountName` falls back to, and why the envelope matters. |
| `opm-kind-demo/jellyfin/moduleinstance.yaml` | The hand-written reference the export generates the equivalent of, including the `cluster-admin` binding OQ2 must decide about. |
| `opm-kind-demo/bootstrap/flux/` | The repo-level Flux wiring that is deliberately out of scope — one `OCIRepository` and one `Kustomization` for the whole bundle. |
| `enhancements/0006/` | Handoff, CR inventory, D38 provenance refusal, D40 inventory-stable criterion. |
| `enhancements/0013/` | Attribute-declared secret fields — what would make D3's warning unnecessary. |

## Deviations from Design

None at this stage. Update when implementation lands.
