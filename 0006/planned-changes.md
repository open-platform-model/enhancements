# Planned OpenSpec Changes — Enhancement 0006

High-level slice plan: the OpenSpec changes to create across the affected repos (`library`, `opm-operator`, `cli`), their dependency relationships, and the order to apply them. This is a routing map, not a design — each change is drafted later using this list together with the enhancement docs (`01-problem.md` … `06-operational.md`, `03-decisions.md`) and the current codebase in the target repo.

Conventions:

- Each change lands in the named repo's own `openspec/` workspace (use that repo's `openspec-new-change` skill).
- Names below are working slugs; the date prefix (`YYYY-MM-DD-…`) is assigned at creation time per the repo's OpenSpec convention.
- Every change's proposal references this enhancement id (`0006`) and the decisions it implements.
- "Depends on" = the listed change(s) must be applied (and ideally archived) first. "Gate" = a cross-enhancement dependency outside 0006.

## Changes

| ID | Repo | Change name | Depends on | Implements | Status |
| -- | ---- | ----------- | ---------- | ---------- | ------ |
| A1 | opm-operator | `operator-bump-k8s-stable` | — | Problem 3 (k8s line) | planned |
| A2 | cli | `cli-rename-module` | — | D15 | planned |
| A3 | library | `library-inventory-pkg` | — | D13 | ❌ reverted (D31, 2026-07-01) |
| A4 | opm-operator | `operator-moduleinstance-owner-marker` | — | D3 | ✅ implemented (2026-06-30) |
| B1 | opm-operator | ~~`operator-adopt-library-inventory`~~ | ~~A3~~ | ~~D13~~ | ❌ cancelled (D31) — premise removed |
| B2 | cli | `cli-operator-install-command` | A2, A4 | D5 | planned (A4 ready; awaits A2) |
| C1 | cli | `cli-cr-inventory-backend` | A2, A4, B2 | D1, D2, D3 (consume), D8, D14 | planned |
| C2 | cli | `cli-kernel-adoption` | C1, **gate: 0001 library slice** | D9, D11, D12, D17, D14 | planned |
| C3 | cli | `cli-instance-handoff` | C1 (wave 1) or C2 (wave 2) — see OQ5 | D6, D7, D16 | planned |

## Change descriptions

### A1 — opm-operator `operator-bump-k8s-stable`

Bump `k8s.io/*` and `sigs.k8s.io/controller-runtime` to the CLI's latest-stable k8s line and align the `go` directive, so the two repos stay on one k8s line once they share `library`. No dependency; pure prep. (Problem 3, `research/findings.md`.)

### A2 — cli `cli-rename-module`

Mechanical rename of the CLI Go module `github.com/opmodel/cli` → `github.com/open-platform-model/cli`: the `go.mod` `module` line, every internal `github.com/opmodel/cli/...` import path, and doc/CI references. No behaviour change. Must land before any CLI change that adds the `library` edge, so kernel/inventory imports are written under the final name. (D15.)

### A3 — library `library-inventory-pkg`

New `library/opm/inventory` package: build inventory entries from kernel-rendered resources, identity equality (`IdentityEqual` / `K8sIdentityEqual`), `ComputeStaleSet`, `ComputeDigest`, over a runtime-neutral entry type — no controller-runtime, no Flux, no k8s-typed dependency beyond apimachinery identity primitives. This is the shared implementation both CLI and operator consume so handoff prune-set parity is structural. No dependency. (D13.)

**Status: ❌ reverted (D31, 2026-07-01).** Shipped 2026-06-30 as the library OpenSpec change `library-inventory-pkg` (archived `library/openspec/changes/archive/2026-06-30-library-inventory-pkg/`), commit `4558ed9` on branch `feat/library-inventory-pkg` — see the original implementation note below, kept for record. An explore-mode design session investigating B1 traced which of the package's functions are actually cross-actor-critical and found only the `InventoryEntry` shape + `NewEntryFromResource` qualify; that surface is already anchored by the CRD schema and kernel-render-parity (D9), not by package-sharing, so a separate cross-repo dependency wasn't earning its coordination cost (see D31 in `03-decisions.md` for the full trace). **The code revert landed** via the library OpenSpec change `revert-library-inventory-pkg` (archived `library/openspec/changes/archive/2026-07-01-revert-library-inventory-pkg/`), commit `738a694` (PR #36, merged 2026-07-01) — `opm/inventory` is deleted in full, `go.mod`/`go.sum` cleanly reverted (dropped `k8s.io/apimachinery` + its transitive closure), `MIGRATIONS.md` carries the BREAKING entry. Unblocks nothing further — B1 is cancelled below and C1 no longer depends on this slice.
>
> Original implementation note (2026-06-30, superseded by D31): "New `library/opm/inventory` package shipped: runtime-neutral `InventoryEntry`, identity relations, `ComputeDigest`, `ComputeStaleSet` on a canonical `K8sIdentityEqual` base (reconciled the prior CLI/operator stale-set drift), plus pure prune-safety (`ApplyComponentRenameSafetyCheck` + a pure pre-apply collision predicate, D26). No controller-runtime/Flux (import-graph guard test); adds `k8s.io/apimachinery`. New main spec `library/openspec/specs/inventory/spec.md` (6 requirements)."

### A4 — opm-operator `operator-moduleinstance-owner-marker`

Add `spec.owner: "cli" | "operator"` (default `"operator"`) to `ModuleInstance`; add the reconciler skip path for `spec.owner: cli` with a single `Ready: Unknown` / `ManagedExternally` condition that never touches CLI-written status; regenerate the CRD (`config/crd/bases/`). Additive, backward-compatible. No dependency. Produces the CRD the CLI later embeds (B2) and reads/writes (C1). (D3.)

**Status: ✅ implemented (2026-06-30).** Shipped as the opm-operator OpenSpec change `operator-moduleinstance-owner-marker` (archived `opm-operator/openspec/changes/archive/2026-06-30-operator-moduleinstance-owner-marker/`), branch `feat/moduleinstance-owner-marker`. The marker is a typed `OwnerType` enum (`OwnerCLI` / `OwnerOperator`), `+optional` + `omitempty`, with **no `+kubebuilder:default`** — the reconciler carries the operator-managed default semantics (absent / empty / `operator` all reconcile normally; only an explicit `owner: cli` skips), per D1. The owner-skip gate sits at the top of `ReconcileModuleInstance` **before** finalizer registration (D2), so a CLI-owned instance never receives the `opmodel.dev/cleanup` finalizer and the operator runs no render/apply/prune/deletion-cleanup; it records one idempotent `Ready: Unknown / ManagedExternally` acknowledgement (new `status.ManagedExternallyReason` + `MarkManagedExternally` helper) and writes no `observedGeneration` and no CLI-owned status (`inventory`, `lastApplied*`, `instanceUUID`) — guaranteed by snapshotting the serial patcher before the condition mutation (D3). Deleting a CLI-owned instance is a no-op; flipping `owner` to `operator` falls through to a normal reconcile that adds the finalizer and overwrites the condition (handoff fall-through). Regenerated CRD + DeepCopy + `dist/install.yaml`; new main spec `opm-operator/openspec/specs/module-instance-ownership/spec.md` (4 requirements). `task dev:test`/`dev:lint` clean. Unblocks B2 (embeds this CRD) and C1 (writes/reads `spec.owner: cli`).

### B1 — opm-operator ~~`operator-adopt-library-inventory`~~ (cancelled)

**Status: ❌ cancelled (D31, 2026-07-01).** This slice's entire premise — migrating the operator's `internal/inventory` to consume `library/opm/inventory` — no longer applies now that the shared package is reverted (D31). The operator's existing `internal/inventory` package is already correct local policy and needs no adoption step. There is nothing to slice here.

D31 does surface a genuinely separate, real finding from the same investigation: the operator's apply path has no equivalent of the CLI's `PreApplyExistenceCheck` (foreign/terminating-object collision guard before a first-time claim), despite both actors' apply paths forcing SSA field-ownership unconditionally. Whether and how to build that is **OQ16** (open, `03-decisions.md`) — it is not scoped as a slice here because it hasn't been decided yet, and if built it would be a new, operator-local, independently-designed capability, not an "adopt the shared package" step. A future slice may pick this up once OQ16 resolves.

Original description (superseded by D31, kept for record): "Migrate the operator's `internal/inventory` pure logic to consume `library/opm/inventory` (A3), replacing the in-repo copy; `api/v1alpha1.InventoryEntry` stays as the CRD serialization shape and maps to/from the `library` type. No external behaviour change — this is what guarantees the operator and CLI compute identical entry identity/digests. Depends on A3. (D13. Optionally OQ6 — whether the CLI-only prune-safety checks also move into the shared package — is decided here.)"

### B2 — cli `cli-operator-install-command`

New `opm install crds | operator` and `opm uninstall operator`: SSA install (manager `opm-cli`) of the embedded (`go:embed`) CRD manifests and `dist/install.yaml`, with `--version` fetch fallback; `uninstall` never deletes CRDs; missing-CRD on apply fails with a clear hint. Depends on A4 (the regenerated CRD/`dist` it embeds) and A2 (the rename). Makes the CRD a hard prerequisite for every CLI apply. (D5; OQ7/OQ8 decided here.)

### C1 — cli `cli-cr-inventory-backend`

Replace the Secret inventory with the `ModuleInstance` CR (handled as `unstructured`): write the CLI status subset (D2) and `spec.owner: cli` (D3); rewire `apply/delete/status/list/diff` to read/write the CR; one-shot apply/prune that ports the operator's reconcile concepts (phase order, ownership guard, never-prune Namespaces/CRDs) and computes the stale set with the CLI's own existing local inventory logic. Delete only the Secret-specific CRUD/marshaling (`cli/internal/inventory/secret.go`, `crud.go`, `discover.go`, `list.go`) — the entry-identity/stale-set/digest/rename-safety/collision-check logic (`cli/pkg/inventory`, `cli/internal/inventory/stale.go`) stays and is ported onto the CR-backed flow as-is; D31 reverted the `library/opm/inventory` import this slice was originally scoped to consume instead (see D13/D31). One-time Secret→CR migration with no deprecation window (D8/D14). Render still uses the CLI's current pipeline at this point. Depends on A2, A4, B2 (A3 and B1 dropped per D31). (D1, D2, D8, D14; OQ3/OQ9 decided here.)

### C2 — cli `cli-kernel-adoption`

Delete `cli/pkg/render` and the match path in `cli/pkg/loader`; render every release through the `library` kernel (D9) so the CLI's render digest equals the operator's by construction. Add platform resolution by precedence — `--platform` flag > cluster `Platform` CR > local/embedded default — materialized via the same kernel calls the operator uses, with write-if-absent of the solo-cluster singleton `Platform` (D11/D12); both Platform sources first-class, no cluster-admin required on non-`handoff` paths (D17). Migrate the CLI's CUE usage to v0.17.0-alpha.1 (D14). Depends on C1 **and the cross-enhancement gate: enhancement 0001's `library` kernel match/materialize slice must have shipped.** This is the one edge that cannot start until 0001 lands. (D9, D11, D12, D14, D17; OQ10/OQ12/OQ13/OQ14 decided here.)

**Carryover from enhancement [0002](../0002/) (CLI `Release` → `Instance` rename) — retire the last `#ModuleInstance`.** Beyond the render/match deletion above, C2 MUST also reconcile the module-package *synthesis* path in `cli/pkg/loader/synth.go` (`loadSynthWrapper`), which still imports `opmodel.dev/core/v1alpha1/moduleinstance@v1` and applies `#ModuleInstance` (not `#ModuleInstance`). This is a deliberately-deferred catalog-pin from 0002 slice X1 — its `FLAG (0002, out of X1 scope)` breadcrumb marks the site, and after the 0002 CLI sweep it is the **sole remaining production-code reference to the old `#ModuleInstance` definition** in `cli/` (every example, fixture, and the operator already moved to `#ModuleInstance`). Whatever replaces synthesis under kernel adoption MUST apply `#ModuleInstance` so `opm module build` / `opm instance build <dir>` emit `kind: "ModuleInstance"`, and MUST resolve the `…/moduleinstance@v1` import-path drift against the catalog the kernel resolves. 0002's X1 description already names 0006 kernel adoption as the resolving effort; closing it here makes the bidirectional link complete.

### C3 — cli `cli-instance-handoff`

New `opm instance handoff <release>`, forward-only (CLI → operator), no reverse mode (D16): verify operator ready → CR is `owner: cli` → `spec.module` resolvable (D6) → render digest matches `status.lastAppliedRenderDigest`, then patch `spec.owner: operator` and wait for a bounded no-op reconcile (0 changed, 0 pruned). Depends on C1. Its digest check is only *structurally* meaningful once C2 has landed (shared kernel); whether handoff ships before then is OQ5. (D6, D7, D16; OQ11 decided here.)

## Ordering and waves

```
Wave 0 (parallel, no inter-deps):  A1   A2   A3 ❌(reverted)   A4 ✅
Then:                              B2 (after A2, A4)
Then:                              C1 (after A2,A4,B2)
Then:                              C2 (after C1 AND 0001 library slice)   ← cross-enhancement gate
Then:                              C3 (after C1; structural parity after C2)
```

- **A1–A4 are independent** and can be drafted/applied in parallel. B2 joins its prerequisites. B1 is cancelled (D31) — no operator slice joins A3, because A3 itself is reverted.
- **C1 is the convergence point** for the inventory/CR/install strand (D1–D8, D14–D15).
- **C2 carries the only cross-enhancement gate** — it consumes 0001's kernel materialize/match. Track 0001's status; C2 cannot begin until that slice is in `library`.
- **OQ5 (one wave or two) decides where C3 sits.** Wave 1 = ship CR inventory + install + handoff (C1, B2, C3) against the CLI's current render pipeline, with best-effort digest parity. Wave 2 = kernel adoption (C2) makes that parity structural. If 0006 ships as a single wave, C3 follows C2 and parity is structural from the start. Resolve OQ5 before drafting C3.
