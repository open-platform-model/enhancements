# Design — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Design Goals

- A CLI-deployed release and an operator-deployed release are the same object — a `ModuleInstance` CR — with inventory in `status.inventory`. There is one resource type to list, inspect, and reconcile.
- A CLI render and an operator render of the same release are byte-identical, because both run through the `library` kernel. Render-digest parity is structural, not best-effort.
- `opm instance handoff` transfers a CLI-deployed release to operator management with zero resources changed and zero pruned, verified by a render-digest check before the ownership flip.
- The CLI carries no second copy of render/match logic. 0001's matcher redesign — and every future kernel change — reaches the CLI through the kernel dependency, not a parallel implementation.
- Both actors mutate the cluster via server-side apply with distinct field managers (`opm-cli`, `opm-controller`), so field ownership cleanly identifies who wrote what, including during the handoff transition window.
- Existing Secret-based inventories migrate to CR inventories automatically on the next apply, with no silent orphaning.
- OPM stays usable without cluster-admin. Both a local/embedded Platform and the in-cluster `Platform` CR are first-class render sources; a non-admin who cannot read the cluster-scoped singleton can still `build`, `render`, `apply`, and `diff` against a local Platform. Only `handoff` — an operator-adoption step that already assumes operator context — forces the cluster CR (D17).

## Non-Goals

- **Apply-engine unification.** The CLI keeps its own client-go SSA path; the operator keeps Flux `ResourceManager`. Only render/match is unified. (D10.)
- **Modifying the kernel's match/materialize.** That redesign is enhancement 0001; this enhancement consumes the kernel as-is. 0006 touches no `core/*.cue` and no kernel match code.
- **`Release` / `BundleRelease` handoff.** `ModuleInstance` only.
- **Reverse handoff (`--to cli`).** Handoff is forward-only (CLI → operator); flipping a reconciled CR back to CLI ownership is a separable capability with its own status-cleanup and relinquish-race design, deferred (D16).
- **Rollback / `status.history`** for the CLI. Operator-only, unchanged.
- **Operator lifecycle management** beyond `install` / `uninstall` (no upgrade orchestration, no HA config).

## High-Level Approach

The design is three coupled moves plus a feature that only becomes safe once all three land.

### 1. Inventory moves to the `ModuleInstance` CR

On `opm instance apply`, the CLI creates or updates a `ModuleInstance` named after the release, in the release namespace, with `spec.owner: cli` (D3), and writes its inventory into `status.inventory` via the status subresource (D1). It writes only the strict subset of status that a one-shot actor can meaningfully own — `inventory`, `instanceUUID`, the `lastApplied*` digests, and a single `Ready` condition with reason `AppliedByCLI` (D2). Controller-loop fields (`observedGeneration`, `lastAttempted*`, `failureCounters`, `history`, `nextRetryAt`) are left unset; the operator already tolerates an empty status on a fresh CR, so it tolerates this subset.

`instance delete` resolves inventory from the CR, deletes resources in reverse weight order, then deletes the CR last (mirroring today's "Secret deleted last"). `instance list` lists `ModuleInstance` objects; `instance status` and `instance diff` read `status.inventory`. The CLI field manager for CR writes is `opm-cli`.

`cli/internal/inventory`'s Secret-specific marshaling/CRUD is deleted; its entry-identity/stale-set logic, and `cli/pkg/inventory` (the CLI's own entry-identity/stale-set copy), are kept as the CLI's local implementation — not replaced by an import (D31 reverted the D4/D13 plan to source this from a shared package; see D31 in `03-decisions.md`).

### 2. Render/match moves to the `library` kernel

The CLI deletes its own render/match pipeline (`cli/pkg/render`, the match path in `cli/pkg/loader`) and renders every release through the `library` kernel — the same kernel the operator runs (D9). The CLI becomes a kernel consumer: it loads the module, obtains a materialized platform, calls the kernel's match + render, and receives the rendered resource set plus the render digest. Because the operator uses the same kernel, the digest the CLI writes to `status.lastAppliedRenderDigest` is the digest the operator will compute on its first reconcile — render parity is structural.

This is the strand that depends on 0001: the kernel's match/materialize is what 0001 rewrites, so the CLI cannot land on the 0001 model until 0001's `library` slice ships. The inventory/CR/handoff strand (moves 1, 3, and the feature) does not depend on 0001 and can proceed first (see OQ5).

The kernel's match needs a *materialized platform* (catalog subscriptions resolved against OCI). The operator builds one by reading the cluster-scoped singleton `Platform` CR spec and calling `SynthesizePlatform` → `Materialize` into an in-memory store; the materialized result is never persisted. The CLI uses the *same* kernel calls, differing only in where the platform spec comes from. Resolved by D11/D12: the CLI resolves a platform by precedence (`--platform` flag > cluster `Platform` CR > local/embedded default), reads the CR *spec* and materializes it itself, and forces the cluster CR for `handoff` so render parity with the operator holds. The `Platform` carries no owner marker — the operator always owns the singleton (its store is the sole input to every operator render); in a CLI-solo cluster the CLI writes an un-owned `cluster` Platform write-if-absent, which the operator adopts on install. The precedence is load-bearing for accessibility, not just convenience: a non-admin who cannot read the cluster `Platform` must still render against a local Platform, so every non-`handoff` path stays usable without cluster-admin (D17). The concrete per-command flag surface for selecting the source is OQ14; `diff`'s source is OQ12.

### 3. Apply stays CLI-side, SSA mandatory

The CLI keeps its own apply step — client-go server-side apply, field manager `opm-cli` (D10). Duplicating the operator's apply semantics (staging order, conflict handling) is explicitly accepted; the apply engines are not unified in this enhancement. The single hard requirement is that the CLI apply path uses **server-side apply**, because SSA field-manager semantics are what make the handoff transition window safe: when ownership flips and the operator's `opm-controller` manager applies the same fields, SSA resolves the overlap by manager transfer rather than a destructive replace.

### 4. The feature: `opm instance handoff`

With a shared CR (move 1) and a shared kernel (move 2), handoff is a verified ownership flip (D7). Preconditions checked in order: operator installed and ready; the CR exists with `spec.owner: cli`; `spec.module` is a published, registry-resolvable reference (D6); and the render digest the CLI computes from that reference matches `status.lastAppliedRenderDigest`. The match is now meaningful precisely because both sides render through the same kernel. Then the CLI patches `spec.owner: operator` (single SSA patch) and waits, bounded, for the operator's first reconcile: expected `Ready: True`, inventory revision incremented, zero resources changed, zero pruned. Handoff is **forward-only** (CLI → operator); the reverse flip (`--to cli`) is out of scope (D16).

### Supporting pieces

- **`spec.owner` marker (D3).** A spec-level `owner: cli | operator` field (default `operator`). When `spec.owner: cli`, the operator skips render/apply/prune entirely and sets a single `Ready: Unknown` / `ManagedExternally` condition, never touching CLI-written status. This is an operator-side change, documented here under the cross-repo scope.
- **`opm operator install` (D5, surface reshaped by D32).** Because inventory now lives in a CR, the `ModuleInstance` CRD is a hard prerequisite for every CLI apply (gate lands in C1 — D33). `opm operator install` (full operator) and `opm operator install --crds-only` (just the CRDs, filtered from the same artifact) install via SSA with manager `opm-cli`; the single embedded artifact is the pinned release's `dist/install.yaml`, with a `--version` fetch fallback to the GitHub release asset, and install waits for completion (D35). `opm operator uninstall` never deletes CRDs (deleting a CRD cascades to every `ModuleInstance` in the cluster — removal is a deliberate manual `kubectl delete crd`) and never deletes the Namespace; it refuses while instances carry the operator's cleanup finalizer, overridable with `--remove-finalizers` (D34).
- **Local-path applies (D6).** When applying from a published reference the CLI writes it into `spec.module` verbatim; from a local path it writes best-effort path/version plus a `source: local` annotation, leaving the CR a valid inventory store but not yet reconcilable. D3 makes this safe (the operator does not act on CLI-owned CRs) and D7 refuses to flip ownership until `spec.module` resolves.
- **Secret migration (D8).** On apply against a release that has a Secret but no CR, the CLI reads the Secret, creates the CR, writes the Secret's record into `status.inventory` (preserving revision), applies, then deletes the Secret only after the status write succeeds. `status`/`delete`/`list` fall back to reading Secrets for one minor release with a deprecation warning, then the Secret path is removed.

## Schema / API Surface

The new and changed shapes live in [`schemas/target.cue`](schemas/target.cue) (CR + status-subset shapes expressed as CUE for review) — these mirror Go types in `opm-operator/api/v1alpha1`, the source of truth. Headlines:

- `ModuleInstance.spec.owner: "cli" | "operator"` (default `"operator"`) — the new ownership marker (D3).
- The **CLI status subset** (D2): the CLI writes only `inventory`, `instanceUUID`, `lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`, and one `Ready` condition (reason `AppliedByCLI`). Everything else in `ModuleInstanceStatus` stays operator-owned and unset by the CLI.
- **Inventory logic stays local to each actor (D31, reverses D13's shared-package clause and D26).** The operator keeps its existing `internal/inventory` (entry type, `NewEntryFromResource`, `IdentityEqual`/`K8sIdentityEqual`, `ComputeStaleSet`, `ComputeDigest`); the CLI keeps its existing `cli/pkg/inventory` equivalent, ported onto the CR-backed flow. Only the `InventoryEntry` *wire shape* persisted to `status.inventory.entries[]` must agree across actors — that's the operator's `api/v1alpha1.InventoryEntry` CRD serialization shape, which is already the single source of truth for the field set. See D31 for why a shared `library` package for the algorithm turned out not to be load-bearing: the one cross-actor-critical moment (the operator's first post-handoff stale-set read of CLI-written entries) is already gated by D7.4's render-digest check.

## Integration Points

### opm-operator

- `api/v1alpha1/moduleinstance_types.go` — add `spec.owner: cli|operator` field with defaulting; regenerate CRD (`config/crd/bases/`).
- Reconciler — add the `spec.owner: cli` skip path and the `ManagedExternally` condition (D3).
- `internal/inventory/` (pure logic) → **stays in place, unchanged** (D31 reverted D13's plan to migrate it to `library`; D4's original "promote to operator `pkg/`" is also not pursued). `api/v1alpha1.InventoryEntry` stays the CRD serialization shape. OQ6's question (whether CLI-only prune-safety checks move into a shared package) is resolved-no by D31; the successor question — whether the operator should gain its own, independently-designed apply-time collision guard — is OQ16 (open).
- `go.mod` — bump `k8s.io/*` and `controller-runtime` to the CLI's latest-stable k8s line, and the `go` directive to match (Problem 3, `research/findings.md`). A small prep slice, independent of the rest.
- `dist/install.yaml` — the one artifact the CLI embeds for `opm operator install` (D35; CRDs derived by filtering, so `config/crd/bases/*.yaml` is not separately embedded); no change beyond the CRD regen.
- `api/v1alpha1/platform_types.go` + `PlatformReconciler` — add `status.operatorVersion` self-publish (D24's operator half; slice A6).

### library

- No inventory package (D31 reverted `library/opm/inventory`, shipped as slice A3 then walked back — the code revert itself is a separate, not-yet-done session). `library`'s role in this enhancement is the kernel only (D9) — render/match, consumed by the CLI the same way the operator already consumes it.

### cli

- `internal/inventory/` — its Secret-specific marshaling/CRUD is **deleted** (D1); its entry-identity/stale-set/rename-safety/collision-check logic (`stale.go`) **stays**, ported onto the CR-backed flow (D31 reverses D13's plan to delete it in favor of a `library` import).
- `pkg/inventory/` (CLI's entry-identity/stale-set copy) — **stays** (D31 reverses D13's plan to delete it in favor of the `library/opm/inventory` import).
- `pkg/render/`, match path in `pkg/loader/` — **deleted**, replaced by `library` kernel calls (D9).
- `internal/workflow/apply/apply.go` — rewired as a one-shot reconcile (D13/D31): render via kernel, compute stale set via the CLI's own `pkg/inventory`/`internal/inventory` logic (unchanged in place, not an import), SSA apply via the CLI engine (D10), prune with the ownership guard, write the CR status subset (D2) as `unstructured`, Secret migration (D8/D14). Borrows the operator's phase order; runs no controller-runtime loop.
- `internal/kubernetes/` — the SSA apply/delete path that stays CLI-owned; ensure it uses server-side apply with manager `opm-cli` (D10).
- `internal/cmd/instance/{apply,delete,status,list,diff}.go` — read/write the CR instead of the Secret.
- New `internal/cmd/operator/` (or equivalent) — `opm operator install [--crds-only] [--rbac]`, `opm operator uninstall [--remove-finalizers]`, embedded `dist/install.yaml`, `--version`, readiness wait (D5, D32–D35).
- New `internal/cmd/instance/handoff.go` — `opm instance handoff` with D7 verification; **forward-only** (CLI → operator), no reverse mode (D16).
- **Module rename (D15)** — `cli/go.mod` `module` line and every internal `github.com/opmodel/cli/...` import path renamed to `github.com/open-platform-model/cli`; a mechanical prep slice landed before the `library` edge is added, so the kernel/inventory imports are written against the final name.
- `go.mod` — add `github.com/open-platform-model/library` **only** (kernel — D31 removed inventory from this import's scope). Do **not** add `opm-operator` (D13 — it drags controller-runtime + Flux). The `ModuleInstance` CR is read/written as `unstructured` via the CLI's existing client-go. The CUE bump — retargeted to v0.17.1 and relocated into C1 (D36) — precedes this import, so MVS is already satisfied when the `library` edge is added.
- New platform-resolution code (D11/D12/D17): resolve the platform spec by precedence (`--platform` flag > cluster `Platform` CR > local/embedded default), call `SynthesizePlatform` → `Materialize`, and on a solo cluster write the singleton `cluster` Platform CR write-if-absent (SSA, manager `opm-cli`). `handoff` forces the cluster-CR source; every other path stays usable against a local Platform with no cluster-admin (D17). Concrete flag surface across commands is OQ14; `diff`'s source is OQ12; write-if-absent atomicity is OQ13.

## Before / After

### Inventory store

```diff
- Secret opm.jellyfin.<uuid>  (type opmodel.dev/release, key "inventory")
-   data.inventory = JSON ReleaseInventoryRecord{ CreatedBy, …, Inventory{…} }
+ ModuleInstance jellyfin (namespace media)
+   spec.owner: cli
+   spec.module: { path: example.com/modules/jellyfin, version: 1.2.0 }
+   status.inventory: { revision, digest, count, entries[] }
+   status.lastAppliedRenderDigest: <digest computed by the library kernel>
+   status.conditions: [ { type: Ready, reason: AppliedByCLI } ]
```

### Render path

```diff
  opm instance apply
-   cli/pkg/render  +  cli/pkg/loader (match)      # CLI's own pipeline
+   library kernel: match + render                  # same kernel the operator runs
    cli/internal/kubernetes SSA apply (opm-cli)     # CLI keeps its own apply
```

### Handoff (the new capability)

```diff
- (impossible) hand-write a ModuleInstance, kubectl apply, delete the Secret, hope the
-   operator's first reconcile is a no-op
+ opm instance handoff jellyfin
+   verify operator ready → CR is owner:cli → spec.module resolvable →
+   render digest == status.lastAppliedRenderDigest  (parity guaranteed by shared kernel)
+   patch spec.owner: operator → operator reconcile: Ready:True, 0 changed, 0 pruned
```
