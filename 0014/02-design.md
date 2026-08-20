# Design — Export a Deployed Instance as GitOps Manifests

This document answers the question: "What is the proposed solution and how does it work?" Design Goals and Non-Goals together define the boundary; the High-Level Approach is readable without deep implementation knowledge. Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **One command turns a deployed instance into a committable directory.** `opm instance export <name> -n <ns>` reads the live `ModuleInstance` and writes a directory of YAML documents. No hand-transcription step remains between "it runs" and "it is in git".
- **The exported set is complete for apply.** Applying the directory into an empty cluster, with the operator installed and nothing else, produces the same instance under the same identity with the same deletion behaviour. The namespace, the applier `ServiceAccount`, and its authorization are part of the output, not assumed.
- **Adoption, not recreation.** The exported CR carries the live object's name and namespace, so the first GitOps apply adopts the running instance. Success is 0006 D40's criterion: a reconcile that leaves the entry set unchanged and touches no workload.
- **Nothing is written unless the published module reproduces the deployed render.** The export runs handoff's verification before it writes a file, and refuses rather than emitting a directory that describes something other than what is running.
- **Every field is either copied or reported.** A field the export completes (one the CLI never wrote) is named in the command output. Nothing about the instance's behaviour changes silently between the cluster and the repo.
- **Byte-stable.** Exporting an unchanged instance twice produces identical bytes, so re-running the command against a repo shows an empty diff rather than churn.

## Non-Goals

- **Repo-level Flux wiring.** The `OCIRepository` and the Flux `Kustomization` that pull a bundle are one per repository, not one per instance (`opm-kind-demo/bootstrap/flux/` holds exactly one of each for the whole demo). Emitting them per exported instance would produce N conflicting copies of a singleton. Bootstrapping a GitOps repo is a separate concern and a candidate follow-on.
- **CUE-native emission.** Reconstructing an `instance.cue` plus a `ModulePackage` CR pointing at it is a different GitOps model — the operator fetches a CUE package from a Flux source rather than resolving a published module by coordinate. It is a legitimate second target and it is deferred, not rejected; see `05-risks.md` `## Alternatives`.
- **The import direction.** Nothing here reads a repo and applies it, and nothing continuously compares git against the cluster. Once the directory is committed, Flux is the applier and Flux reports the drift.
- **Secret detection and redaction.** `spec.values` is emitted verbatim (D3). OPM cannot yet tell which values are secret; enhancement [0013](../0013/) is the design that would make it possible, and until it lands the export warns rather than guesses.
- **`ModulePackage` export.** This entry covers `ModuleInstance` only, matching 0006's scope boundary.

## High-Level Approach

Five steps, in order. The first three happen entirely in memory; nothing touches the filesystem until the gates have passed.

**1. Read.** The live `ModuleInstance` CR is the only input (D4). The CLI already has the read path: `inventory.GetRecord` returns a `Record` carrying name, namespace, owner, module path and version, `spec.values`, `spec.prune`, the render-provenance flag, the digest set, and the inventory. The export adds one field to that `Record` — `spec.serviceAccountName` — and needs nothing else.

**2. Gate.** The export reuses handoff's precondition chain, in the same cheapest-first order, minus the ownership gate:

- cluster gates (CRDs present, version skew within ceiling) — shared with every cluster-touching command;
- the CR exists;
- the render-provenance annotation is not `local` — the operator resolves modules from the registry only, so an instance last applied from local bytes has no expressible GitOps form, exactly as it has no expressible handoff (0006 D38);
- `spec.module.path` and `spec.module.version` are both concrete;
- `status.lastAppliedRenderDigest` is recorded;
- the strict-registry verification render of that published module against those values reproduces that digest.

The last gate is the guarantee. It is the same `VerificationDigest` call handoff makes, and its failure message reports the same finding: the cluster is running something the registry no longer describes.

**3. Complete.** The partition that makes this safe:

| Field | Class | Export behaviour |
| --- | --- | --- |
| `spec.module.path`, `spec.module.version` | render-bearing | copied verbatim, verified by the digest gate |
| `spec.values` | render-bearing | copied verbatim, verified by the digest gate |
| `spec.owner` | apply-bearing | set to operator management |
| `spec.serviceAccountName` | apply-bearing | completed when absent (OQ1) |
| `spec.prune` | apply-bearing | completed when absent (OQ1) |
| `Namespace`, `ServiceAccount`, RBAC | apply-bearing | synthesized (OQ2) |
| `status`, `metadata.managedFields`, `uid`, `resourceVersion`, `generation`, `creationTimestamp` | cluster-side | dropped |

Render-bearing fields decide what the operator produces; the digest gate proves they are right, and the export must not touch them. Apply-bearing fields decide who applies the instance and what happens when the CR is deleted; they are absent from a CLI-written CR, they do not enter the render digest, and completing them therefore strengthens the exported document without weakening the guarantee. Every completion is reported in the command output, so the difference between the live CR and the exported one is visible rather than inferred.

**4. Compose.** One directory per instance, one document per file, plus a kustomize resource list:

```
<out-dir>/<namespace>/<name>/
  namespace.yaml
  serviceaccount.yaml
  rbac.yaml
  moduleinstance.yaml
  kustomization.yaml
```

The demo packs all four objects into a single `moduleinstance.yaml`; the export splits them because a generated tree is read as diffs, and a one-line RBAC change should not appear as a change to the file that also holds the values block.

**5. Write and report.** The command prints what it verified, what it completed, and the warning that `spec.values` was written verbatim to disk. Exporting several instances is the same operation repeated — `--all` walks every operator-manageable instance in the namespace (or the cluster) and writes one directory each under the same out-dir, with no shared or merged output between them.

## Schema / API Surface

The full surface is in [`contracts/contracts.cue`](contracts/contracts.cue), which compiles. Headline shapes:

- `#ExportRequest` — the command's inputs: instance identity, out-dir, and the flags.
- `#Gate` and `#GateChain` — the ordered precondition chain, each gate carrying the class of failure it reports. The chain is a value, not prose, so the design's claim that export and handoff share a chain is checkable.
- `#FieldClass` — the render-bearing / apply-bearing / cluster-side partition above, as an enum applied field by field. This is the schema-level statement of why completion is safe.
- `#ExportedSet` — the five documents, their fixed filenames, and the rule that `kustomization.yaml` lists exactly the other four.
- `#ExportReport` — what the command tells the user: gate outcomes, per-field completions, warnings.
- `#AdoptionProperty` — the conformance statement: for an instance whose gates passed, applying `#ExportedSet` yields an inventory-stable reconcile in 0006 D40's sense.

Unresolved fields carry `// OQN:` markers pointing at the corresponding Open Question in `03-decisions.md`.

## Integration Points

All in `cli/`. No `core/`, `library/`, or `opm-operator/` change is required — the export reads an existing CR through an existing read path and writes files.

**`cli/internal/cmd/instance/export.go`** (new) — the Cobra command. Thin, per the repo's command/orchestration split: flag parsing and delegation.

**`cli/internal/workflow/export/`** (new package) — the orchestration: gate chain, completion, composition, write. Sits alongside `internal/workflow/handoff/` and `internal/workflow/apply/`.

**`cli/internal/workflow/handoff/verify.go`** — `VerificationDigest` is the verification primitive both handoff and export need. It is exported today and importable as-is, but it is a property of an instance, not of a handoff; the honest move is to lift it to a shared location (`internal/workflow/verify/`) and have both callers use it. Either way there is exactly one implementation.

**`cli/internal/inventory/record.go` and `cr.go`** — `Record` gains `ServiceAccountName` (read-only, matching the existing `Prune` field's role). No write path changes: `ApplySpec` is untouched, and export writes files rather than the cluster.

**`cli/internal/inventory/discover.go`** — the instance-listing path `--all` walks. Already exists for `opm instance list`.

**`cli/internal/output/`** — the report and the values warning.

**`cli/internal/cmd/instance/instance.go`** — command registration.

**Tests** — unit coverage for completion and composition (no cluster required, table-driven over `Record` fixtures); an e2e case in `cli/tests/e2e/` that applies with the CLI, hands off, exports, applies the exported directory, and asserts the inventory entry set is unchanged — the executable form of `#AdoptionProperty`.

**Docs** — `cli/README.md` command groups; the generated CLI reference on `opmodel.dev` follows mechanically from the Cobra definitions.

## Before / After

The platform team from `01-problem.md`, at the point where the path stops today.

**Before** — five instances, five `kubectl get -o yaml` dumps, and for each one: delete `status` and six metadata fields, decide `prune`, decide `serviceAccountName`, write a `Namespace`, a `ServiceAccount`, a `ClusterRoleBinding`, a `kustomization.yaml`, and hand-copy a twenty-line values block. Checked by applying it and watching a StatefulSet.

**After:**

```
$ opm instance export postgres -n prod --out-dir ./gitops
[x] published module reproduces the deployed state
    opmodel.dev/modules/postgres@v2 v2.1.0
[x] spec.module and spec.values copied verbatim from the live instance
 !  completed spec.serviceAccountName (absent on the live instance)
 !  completed spec.prune (absent on the live instance — the operator
    currently orphans this instance's resources on delete)
 !  spec.values written verbatim to disk; review before committing —
    OPM cannot yet tell which values are secret
-> wrote ./gitops/prod/postgres/ (5 files)
```

and, for the whole cluster:

```
$ opm instance export --all --out-dir ./gitops
```

The resulting `moduleinstance.yaml` has the same shape as the hand-written `opm-kind-demo/jellyfin/moduleinstance.yaml`, with `spec.module` and `spec.values` taken from the object handoff verified rather than retyped. Committing the tree and pointing a Flux `Kustomization` at it adopts the running instances: the operator is already their manager, the names and namespaces match, and the first reconcile changes no workload.
