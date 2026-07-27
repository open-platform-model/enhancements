# Operational Concerns — Kubernetes as a First-Class Kernel Platform

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The main observability gain is that a skipped delete acquires a *reason* that is the same string in both tools. Today the operator logs `"Skipping prune: live resource is not OPM-managed"` with structured keys while the CLI logs nothing at all for the same condition, because it does not check it. After this entry, every `PlannedAction` carries a typed skip reason — safety-excluded, not-OPM-managed, owner-UUID-mismatch, already-absent — and the frontends render it in their own idiom.

New typed errors join `opm/errors/` alongside the existing `MatchError` and `MaterializeError` families: a deletion-plan error naming the entry and the reason, and an ownership-verdict error for the apply-side guard. Both are structured so the operator can map them to conditions and events (`status.PruneFailedReason` already exists) and the CLI to exit codes, without either parsing strings.

What does **not** change: the operator keeps owning conditions, events, and `opmmetrics`; the CLI keeps owning its logger and output formatting. The kernel emits no output — Principle I is unaffected, and any logging it needs arrives from the caller via `context.Context` as it already does elsewhere.

The conformance test required at graduation is itself an observability artefact: it is the thing that will fail loudly if a frontend drifts, which is the signal 0006's OQ15/OQ16 lacked.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

`opmodel.dev/core` — no impact expected. This entry adds no CUE schema surface of its own; `schemas/target.cue` describes the contract both Go implementations satisfy, and where it overlaps `core` (the label vocabulary, the inventory wire shape) it restates what is already there. OQ11 could change this if label stamping moves; that would be coordinated with 0010, which is already moving one label from schema to kernel.

`library` — **breaking**, magnitude set by OQ3. Deleting the neutral `core.Resource` / `Identity` contract is a major bump; retaining it and adding `opm/k8s/` alongside is a minor one that still breaks nothing. Either way `library` gains an `apimachinery` dependency, which is not a source break but is an MVS floor for every embedder and belongs in `MIGRATIONS.md` next to the CUE floor. `config.yaml.semver` stays unset until OQ3 resolves, which is why OQ3 is a promotion blocker.

`opm-operator` and `cli` — internal-only changes at the Go level. Both delete packages under `pkg/`, so anything importing them breaks; the CLI has no external Go consumers, and the operator's `pkg/` surface has no known external importer. Neither CRD changes shape, so no cluster-level compatibility question arises unless OQ5 flips `spec.prune`'s default — which is a behavioural break at the operational level even though the schema is unchanged, and is called out separately in [`05-risks.md`](05-risks.md).

`library`'s `migration-guard` contract applies: every breaking commit needs a `Migration: <slug>` trailer and a matching `MIGRATIONS.md` entry, or CI blocks the PR.

## Deprecation

**What gets removed and when? What replaces it?**

Removed outright, in the same release that lands the replacement — no deprecation window, following the convention 0006 set for the same kind of migration:

| Removed | Replaced by |
| --- | --- |
| `cli/pkg/core/{labels,resource,convert}.go` | `library/opm/k8s/{labels,object}` |
| `opm-operator/pkg/core/{labels,resource,convert,compiled_adapter}.go` | `library/opm/k8s/{labels,object}` |
| `cli/pkg/resourceorder/`, `opm-operator/pkg/resourceorder/` | `library/opm/k8s/object` |
| `cli/pkg/inventory/`, `cli/internal/inventory/{digest,stale}.go` | `library/opm/k8s/inventory` + `library/opm/k8s/ownership` |
| `opm-operator/internal/inventory/` | `library/opm/k8s/inventory` |
| `opm-operator/internal/apply/prune.go` | `library/opm/k8s/lifecycle` + `library/opm/helper/k8s/executor` |
| `cli/internal/inventory.ComputeRenderDigest` and its parity comment | `library/opm/k8s/inventory.RenderDigest` |
| `cli/internal/inventory.ApplyComponentRenameSafetyCheck` | nothing — unnecessary by construction if OQ7 lands component-blind |

`library/opm/core/{resource,compiled}.go` is on this list only if OQ3 resolves toward deletion.

The alias-then-delete pattern is explicitly not used. A compatibility alias in `cli/pkg/inventory` pointing at the kernel would leave two import paths for one type and reproduce, in miniature, the ambiguity this entry exists to remove.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Code rollback is clean at the Go level and awkward at the coordination level. Each repo's change is a revert, but the frontends pin a published `library` version, so rolling back the kernel means either yanking a release or pinning both frontends back — the cost D31 named, now paid deliberately rather than avoided.

The important asymmetry is that **nothing here changes persisted state**. The `InventoryEntry` wire shape written to `status.inventory.entries[]` is unchanged, the labels on live resources are unchanged, the finalizer string is unchanged, and the CRDs are unchanged. A cluster reconciled by the new code is readable by the old code and vice versa. That holds for every part of this entry *except* two, both of which are open questions precisely because they are the parts that do not roll back:

- **OQ4**, if it stamps `ownerReferences`. Those persist on live objects; reverting the code does not remove them, and the objects stay garbage-collectable by their owner. A rollback would need a sweep to strip them.
- **OQ5**, if it flips `spec.prune`'s default. Anything already deleted under the new default is gone.

OQ6's resolution, if it adds a hold to CLI-owned CRs, persists as a finalizer string on those CRs — recoverable, but a rollback leaves CRs holding a finalizer no running code releases, which is the wedge `opm operator uninstall` already guards against elsewhere. Any resolution should carry a release path.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

```
   library  ──published tag──▶  opm-operator
        │                              
        └────published tag────▶  cli
```

`library` first, always: the kernel package plus its conformance test ship and are published before either frontend can adopt. The two frontends are then independent of each other and may land in either order — a property worth protecting, since it is what lets the riskier operator migration proceed without blocking the CLI's CRD-exclusion fix, which is the most urgent single item in this entry.

Within `library`, slice so that no published version contains an unimported package — D31's "actively misleading" critique applies to intermediate states too. The kernel package and the test that enforces it belong in the same release.

Sequencing against other entries:

- **0010** is upstream on identity. This entry consumes whatever `instanceUUID` and FQN shape 0010 lands; it does not need 0010 to finish first, because the ownership guard compares whatever the label holds rather than parsing it. If 0010's identity migration and this entry's frontend migrations overlap, the identity migration should go first — it relabels live resources, and doing that while the delete guard is mid-migration is avoidable risk.
- **0008** is entangled through OQ9 and should be resolved jointly before either entry is promoted, not after.
- **0009** is entangled through OQ10. Both entries introduce a kernel planner with a caller-supplied execution seam; agreeing one convention costs almost nothing now and a rewrite later.

No CUE module publish is required unless OQ11 moves label stamping, in which case `core` publishes first and the ordering becomes `core → library → {operator, cli}`.
