# Operational Concerns: Kubernetes as a First-Class Library Tier

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The main observability gain is that a skipped delete acquires a *reason* that is the same string in both tools. Today the operator logs `"Skipping prune: live resource is not OPM-managed"` with structured keys while the CLI logs nothing at all for the same condition, because it does not check it. After this entry, every `PlannedAction` carries a typed skip reason: safety-excluded, not-OPM-managed, owner-UUID-mismatch, already-absent. The frontends render it in their own idiom.

New typed errors join the library's error vocabulary alongside the existing `MatchError` and `MaterializeError` families: a deletion-plan error naming the entry and the reason, and an ownership-verdict error for the apply-side guard. Both are structured so the operator can map them to conditions and events (`status.PruneFailedReason` already exists) and the CLI to exit codes, without either parsing strings.

What does **not** change: the operator keeps owning conditions, events, and `opmmetrics`; the CLI keeps owning its logger and output formatting. The library emits no output. Principle I is unaffected, and any logging it needs arrives from the caller via `context.Context` as it already does elsewhere.

The conformance test required at graduation is itself an observability artefact: it is the thing that will fail loudly if a frontend drifts, which is the signal 0006's OQ15/OQ16 lacked.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

`opmodel.dev/core`: no impact expected. This entry adds no CUE schema surface of its own; `contracts/contracts.cue` describes the contract both Go implementations satisfy, and where it overlaps `core` (the label vocabulary, the inventory wire shape) it restates what is already there. Label stamping stays in CUE (0012:D6, answering 0012:OQ11), consistent with 0010 keeping the module version label in the schema, so no core change follows from this entry.

`library`: this entry breaks no library source. 0012:OQ3 is answered: the neutral `core.Resource` / `Identity` contract was deleted pre-GA on 2026-09-01 and recorded as a changelog entry. What this entry still adds is the `opm/k8s` tier. `library` gains an `apimachinery` dependency in its one Go module (0012:D3), imported by the `opm/k8s` tier only. That breaks no source. It is an MVS floor for every embedder, including one that never imports the tier, and it belongs in `MIGRATIONS.md` next to the CUE floor. `config.yaml.semver` stays unset until promotion, when the owner sets the magnitude.

`opm-operator` and `cli`: internal-only changes at the Go level. Both delete packages under `pkg/`, so anything importing them breaks; the CLI has no external Go consumers, and the operator's `pkg/` surface has no known external importer. Neither CRD's spec changes shape, and the one CRD change is additive: `ModulePackage` gains a status field holding its instance identity (0012:D8). So no cluster-level compatibility question arises unless OQ5 flips `spec.prune`'s default, which is a behavioural break at the operational level even though the schema is unchanged, and is called out separately in [`05-risks.md`](05-risks.md).

`library`'s `migration-guard` contract applies: every breaking commit needs a `Migration: <slug>` trailer and a matching `MIGRATIONS.md` entry, or CI blocks the PR.

## Deprecation

**What gets removed and when? What replaces it?**

Removed outright, in the same release that lands the replacement (no deprecation window), following the convention 0006 set for the same kind of migration:

| Removed | Replaced by |
| --- | --- |
| `cli/pkg/core/{labels,resource,convert}.go` | `library/opm/k8s/{labels,object}` |
| `opm-operator/pkg/core/{labels,resource,convert,compiled_adapter}.go` | `library/opm/k8s/{labels,object}` |
| `cli/pkg/resourceorder/` (the operator deleted its copy on 2026-09-13) | `library/opm/k8s/object`, the one kind-class order table (0012:D5) |
| `library/opm/helper/objectset` (moved, not removed) | `library/opm/k8s/object`, with the first tier package (0012:D3) |
| `cli/pkg/inventory/`, `cli/internal/inventory/{digest,stale}.go` | `library/opm/k8s/inventory` + `library/opm/k8s/ownership` |
| `opm-operator/internal/inventory/` | `library/opm/k8s/inventory` |
| `opm-operator/internal/apply/prune.go` | `library/opm/k8s/lifecycle` + a local loop performing the actions it names |
| `cli/internal/inventory.ComputeRenderDigest` and its parity comment | `library/opm/k8s/inventory.RenderDigest` |
| `cli/internal/inventory.ApplyComponentRenameSafetyCheck` | nothing: unnecessary by construction, since the stale set is component-blind (0012:D7) |


The alias-then-delete pattern is explicitly not used. A compatibility alias in `cli/pkg/inventory` pointing at the tier would leave two import paths for one type and reproduce, in miniature, the ambiguity this entry exists to remove.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Code rollback is clean at the Go level and awkward at the coordination level. Each repo's change is a revert, but the frontends pin a published `library` version, so rolling back the tier means either yanking a release or pinning both frontends back: the cost 0006:D31 named, now paid deliberately.

The important asymmetry is that **little here changes persisted state**. The `InventoryEntry` wire shape written to `status.inventory.entries[]` is unchanged, the labels OPM stamps on live resources are unchanged, and the finalizer string is unchanged. The `ModuleInstance` CRD is unchanged, and the `ModulePackage` CRD only gains an additive status field (0012:D8). A cluster reconciled by the new code is readable by the old code and vice versa. That holds for every part of this entry except the two stored digests and the adopt annotation, below, and two open questions that are open precisely because they are the parts that do not roll back:

- **OQ4**, if it stamps `ownerReferences`. Those persist on live objects; reverting the code does not remove them, and the objects stay garbage-collectable by their owner. A rollback would need a sweep to strip them.
- **OQ5**, if it flips `spec.prune`'s default. Anything already deleted under the new default is gone.

Two stored digests change, both harmlessly for the objects:

- **The render digest.** The operator records `lastAppliedRenderDigest` and `lastAttemptedRenderDigest` in status, and 0012:D6's digest excludes the managed-by label value where today's digest includes it, so the recorded digest changes once on upgrade with no change to the objects, and again on rollback. 0006:D7's handoff check compares a stored digest, so a handoff across that boundary sees a digest change with no object change behind it.
- **The inventory digest.** 0012:D7 hashes a canonical field-by-field encoding of the entries instead of their JSON form, so each frontend's stored inventory digest changes once, in the release that first records the new value, and again on rollback. That release carries a migration note naming the change, so a user comparing digests across the upgrade is not surprised by a change with no inventory change behind it. The operator's no-op check compares the stored inventory digest, so the change also misses that check once: every ModuleInstance and ModulePackage is re-applied once on upgrade, and every claim judged against it is re-judged once, and the same happens again on rollback. The migration note says so.

The ModulePackage instance identity (0012:D8) is additive: old code ignores the status field, and new code fills it on the first reconcile of a package created before it existed. The adopt annotation (0012:D8) is set by users on live objects. Old code ignores it, so a rollback keeps the objects and loses only the override: an object adopted but not yet recorded in an inventory is treated by old code as it was before adoption: the CLI refuses it only on an instance's first apply and force-applies it on later applies, and the operator, whose old apply path has no guard, force-applies it.

OQ6's resolution, if it adds a hold to CLI-owned CRs, persists as a finalizer string on those CRs (recoverable), but a rollback leaves CRs holding a finalizer no running code releases, which is the wedge `opm operator uninstall` already guards against elsewhere. Any resolution should carry a release path.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

```
   library  ──published tag──▶  opm-operator
        │                              
        └────published tag────▶  cli
```

`library` first, always: the tier's fence and library ADR-011 land before any tier package (0012:D3), then each tier package plus its conformance test ships and is published before either frontend can adopt it. The two frontends are then independent of each other and may land in either order. That property is worth protecting: it is what lets the riskier operator migration proceed without blocking the CLI's CRD-exclusion fix, the most urgent single item in this entry.

Within `library`, slice so that no published version contains an unimported package: 0006:D31's "actively misleading" critique applies to intermediate states too. Each tier package and the test that enforces it belong in the same release. A frontend that adopts a package deletes its own copy in that same release and adds a check refusing it back (0012:D3).

Sequencing against other entries:

- **0010** is upstream on identity. This entry consumes whatever `instanceUUID` and FQN shape 0010 lands; it does not need 0010 to finish first, because the ownership guard compares whatever the label holds rather than parsing it. If 0010's identity migration and this entry's frontend migrations overlap, the identity migration should go first: it relabels live resources, and doing that while the delete guard is mid-migration is avoidable risk.
- **0008** is entangled through OQ9 and should be resolved jointly before either entry is promoted, not after.
- **0009** was entangled through OQ10, now deferred to 0009 (2026-10-03). The deletion protocol is this entry's (0012:D4); whether 0009's k8s get/apply `#Op` vocabulary is expressed as this entry's action set waits in 0009:OQ7 until hooks are wanted, and no answer changes what this entry delivers.

No CUE module publish is required: 0012:OQ11 is answered by 0012:D6, which keeps label stamping in CUE where it already is.
