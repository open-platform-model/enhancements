# Operational Concerns — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- A CLI-deployed release becomes visible as a `ModuleInstance` CR (`kubectl get moduleinstances`) instead of an opaque Secret — a net observability gain; CLI and operator releases now show in one list.
- New CR condition: `Ready` with reason `AppliedByCLI` (CLI-written, D2) and `Ready: Unknown` / `ManagedExternally` (operator-written for CLI-owned CRs, D3).
- `opm instance handoff` reports a structured outcome: preconditions checked, digest-comparison result (match / mismatch with diff under `--force`), and the post-flip reconcile result (resources changed, resources pruned — both expected zero).
- New error surfaces: missing-CRD hint on apply (`ModuleInstance CRD not found — run 'opm operator install --crds-only'`, D5/D32; lands with the CR-inventory slice, D33); `opm operator uninstall`'s refuse-while-finalizers-armed warning naming the affected instances (D34); handoff precondition failures (operator not ready, `spec.module` not resolvable, digest mismatch — each actionable, D7); missing `status` RBAC error (OQ3).
- Render diagnostics now come from the `library` kernel (D9), so CLI render errors gain whatever structured diagnostics 0001's kernel emits (e.g. `MissingFQN`, `UnifyError`) — replacing the CLI's own pipeline errors.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

- `opmodel.dev/core`: **no change.** This enhancement touches no `core/*.cue`. Expected `config.yaml.semver: none` for core.
- `opm-operator` `ModuleInstance` CRD: additive `spec.owner` field within `v1alpha1` (default `operator`), backward compatible with existing CRs (D3).
- CLI users: **breaking operationally** — CRDs become a prerequisite (D5) and the inventory store changes (D1). Because the CLI has a single user and owes no backwards-compat (D14), the Secret → CR migration (D8) is a single best-effort one-time conversion on next apply; there is no deprecation window.
- The CLI render pipeline change (D9) is internal — no user-facing schema change — but render diagnostics and pipeline behaviour shift to the kernel's. The CLI also moves to `cuelang.org/go` v0.17.1 — in C1, ahead of the `library` import (D36); accepted under D14.
- The CLI Go module path changes `github.com/opmodel/cli` → `github.com/open-platform-model/cli` (D15) — a breaking import-path change for any Go importer, but the CLI has no library consumers and a single user (D14), so no compatibility shim is owed; it lands as a mechanical prep slice.
- `opm-operator`: alongside the additive `spec.owner`, this enhancement bumps the operator's `k8s.io/*` + `controller-runtime` to the CLI's latest-stable k8s line (Problem 3) — backward-compatible at the CRD level. The inventory pure-logic migration to `library` (originally D13) is reverted by D31; `opm-operator/internal/inventory` is unaffected by this enhancement.

## Deprecation

**What gets removed and when? What replaces it?**

- `cli/internal/inventory`'s Secret CRUD/marshaling — removed by the CR-inventory slice; replaced by the CR (D1). Its entry-identity/stale-set logic, and `cli/pkg/inventory` (CLI's entry-identity copy), are **not** removed — D31 reverted the D13 plan to replace them with a shared `library/opm/inventory` import; they stay as the CLI's local implementation, ported onto the CR-backed flow. No deprecation window (D14).
- `cli/pkg/render` and the `cli/pkg/loader` match path — removed by the kernel-adoption slice; replaced by `library` kernel calls (D9).
- The Secret inventory format (`opm.<releaseName>.<releaseID>`) — read-fallback for one minor release with a deprecation warning, then removed (D8).
- `opm-operator/internal/inventory` — **stays in place**, unchanged (D31; supersedes D13's plan to migrate it to `library`, which itself had superseded D4's original "promote to operator `pkg/`" — neither move happens).

## Rollback

**If this lands and proves bad, what's the rollback story?**

- The `ModuleInstance` CRs written by the CLI are valid operator CRs; a CLI rollback does not strip them. Reverting the CLI binary to a Secret-era version would leave the CRs in place (harmless; the operator ignores `spec.owner: cli` ones) but that CLI version would not find them — so rollback realistically means re-applying with the old CLI, which recreates Secrets. Because resources carry stable labels/UUIDs and both eras use SSA, re-applying does not churn live objects.
- `spec.owner` is additive; rolling back the operator to a version that ignores it means it would reconcile CLI-owned CRs — so the operator slice must roll back *after* the CLI stops creating CLI-owned CRs, or the operator version that understands `spec.owner` stays deployed. Sequence rollbacks in reverse of install order.
- No data-plane state beyond the CRs/Secrets survives a code rollback; applied workloads are untouched by either inventory representation.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Landing order follows the slice dependency chain:

0. **opm-operator — `bump-k8s-latest-stable`** (`k8s.io/*` + `controller-runtime` to the CLI's latest-stable line; `go` directive). No dependency. Keeps the two repos on one k8s line (Problem 3).
0a. **cli — `module-rename`** (`github.com/opmodel/cli` → `github.com/open-platform-model/cli`: `go.mod` module line + every internal import path + doc/CI references). No dependency. Mechanical prep; MUST land before the `library` edge (slice 4) so kernel imports are written under the final module name (D15).
1. ~~**library — `inventory-pkg`**~~ — **cancelled (D31).** Originally: new `library/opm/inventory`, consumed by both CLI and operator. Reverted — see D31 in `03-decisions.md`. Both actors keep their own local inventory implementation; nothing lands here.
2. **opm-operator — `cli-ownership-marker`** (`spec.owner` field, skip path, `ManagedExternally`, CRD regen). No dependency. Produces: the CRD the CLI embeds, including `spec.owner`.
2a. **opm-operator — `platform-status-operator-version`** (`Platform.status.operatorVersion` self-publish — D24's operator half; slice A6, added 2026-07-02). No dependency. Produces: the field slice 4's version-skew ceiling reads.
3. **cli — `operator-install-command`** (`opm operator install [--crds-only]` / `opm operator uninstall`, embedded `dist/install.yaml` — D32–D35). Consumes: slice 2's regenerated CRD/`dist/install.yaml`. Install/uninstall only; no apply-path change (D33).
4. **cli — `cr-inventory-backend`** (CR replaces Secret; status subset; Secret migration; delete Secret-specific CLI inventory code, keep the entry-identity/stale-set code in place; missing-CRD hint + D24 skew gates land here — D33). Consumes: slices 2, 2a, 3 (no longer slice 1 — reverted).
5. **cli — `kernel-adoption`** (delete `pkg/render`; render via `library` kernel; implement the D11/D12 platform source — flag > cluster `Platform` CR > local default, write-if-absent solo Platform). Consumes: **enhancement 0001's `library` slice** (the gating cross-enhancement dependency) plus slice 4.
6. **cli — `instance-handoff`** (`opm instance handoff`, forward-only CLI → operator; no reverse mode — D16). Consumes: slice 4 (and, for structural digest parity, slice 5 — see OQ5 on whether handoff ships in wave 1 or waits for wave 2).

Slice 0a and slice 2 run in parallel (0a is independent and lands ahead of slice 5). The cross-enhancement edge (slice 5 → 0001) is the one to watch: it cannot start until 0001's kernel materialize/match has shipped to `library`.
