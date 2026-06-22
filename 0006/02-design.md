# Design — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Design Goals

- A CLI-deployed release and an operator-deployed release are the same object — a `ModuleRelease` CR — with inventory in `status.inventory`. There is one resource type to list, inspect, and reconcile.
- A CLI render and an operator render of the same release are byte-identical, because both run through the `library` kernel. Render-digest parity is structural, not best-effort.
- `opm release handoff` transfers a CLI-deployed release to operator management with zero resources changed and zero pruned, verified by a render-digest check before the ownership flip.
- The CLI carries no second copy of render/match logic. 0001's matcher redesign — and every future kernel change — reaches the CLI through the kernel dependency, not a parallel implementation.
- Both actors mutate the cluster via server-side apply with distinct field managers (`opm-cli`, `opm-controller`), so field ownership cleanly identifies who wrote what, including during the handoff transition window.
- Existing Secret-based inventories migrate to CR inventories automatically on the next apply, with no silent orphaning.
- OPM stays usable without cluster-admin. Both a local/embedded Platform and the in-cluster `Platform` CR are first-class render sources; a non-admin who cannot read the cluster-scoped singleton can still `build`, `render`, `apply`, and `diff` against a local Platform. Only `handoff` — an operator-adoption step that already assumes operator context — forces the cluster CR (D17).

## Non-Goals

- **Apply-engine unification.** The CLI keeps its own client-go SSA path; the operator keeps Flux `ResourceManager`. Only render/match is unified. (D10.)
- **Modifying the kernel's match/materialize.** That redesign is enhancement 0001; this enhancement consumes the kernel as-is. 0006 touches no `core/*.cue` and no kernel match code.
- **`Release` / `BundleRelease` handoff.** `ModuleRelease` only.
- **Reverse handoff (`--to cli`).** Handoff is forward-only (CLI → operator); flipping a reconciled CR back to CLI ownership is a separable capability with its own status-cleanup and relinquish-race design, deferred (D16).
- **Rollback / `status.history`** for the CLI. Operator-only, unchanged.
- **Operator lifecycle management** beyond `install` / `uninstall` (no upgrade orchestration, no HA config).

## High-Level Approach

The design is three coupled moves plus a feature that only becomes safe once all three land.

### 1. Inventory moves to the `ModuleRelease` CR

On `opm release apply`, the CLI creates or updates a `ModuleRelease` named after the release, in the release namespace, with `spec.owner: cli` (D3), and writes its inventory into `status.inventory` via the status subresource (D1). It writes only the strict subset of status that a one-shot actor can meaningfully own — `inventory`, `releaseUUID`, the `lastApplied*` digests, and a single `Ready` condition with reason `AppliedByCLI` (D2). Controller-loop fields (`observedGeneration`, `lastAttempted*`, `failureCounters`, `history`, `nextRetryAt`) are left unset; the operator already tolerates an empty status on a fresh CR, so it tolerates this subset.

`release delete` resolves inventory from the CR, deletes resources in reverse weight order, then deletes the CR last (mirroring today's "Secret deleted last"). `release list` lists `ModuleRelease` objects; `release status` and `release diff` read `status.inventory`. The CLI field manager for CR writes is `opm-cli`.

`cli/internal/inventory` (Secret marshaling, CRUD) and `cli/pkg/inventory` (the CLI's own entry-identity/stale-set copy) are deleted, replaced by imports from the operator's promoted `pkg/inventory` (D4).

### 2. Render/match moves to the `library` kernel

The CLI deletes its own render/match pipeline (`cli/pkg/render`, the match path in `cli/pkg/loader`) and renders every release through the `library` kernel — the same kernel the operator runs (D9). The CLI becomes a kernel consumer: it loads the module, obtains a materialized platform, calls the kernel's match + render, and receives the rendered resource set plus the render digest. Because the operator uses the same kernel, the digest the CLI writes to `status.lastAppliedRenderDigest` is the digest the operator will compute on its first reconcile — render parity is structural.

This is the strand that depends on 0001: the kernel's match/materialize is what 0001 rewrites, so the CLI cannot land on the 0001 model until 0001's `library` slice ships. The inventory/CR/handoff strand (moves 1, 3, and the feature) does not depend on 0001 and can proceed first (see OQ5).

The kernel's match needs a *materialized platform* (catalog subscriptions resolved against OCI). The operator builds one by reading the cluster-scoped singleton `Platform` CR spec and calling `SynthesizePlatform` → `Materialize` into an in-memory store; the materialized result is never persisted. The CLI uses the *same* kernel calls, differing only in where the platform spec comes from. Resolved by D11/D12: the CLI resolves a platform by precedence (`--platform` flag > cluster `Platform` CR > local/embedded default), reads the CR *spec* and materializes it itself, and forces the cluster CR for `handoff` so render parity with the operator holds. The `Platform` carries no owner marker — the operator always owns the singleton (its store is the sole input to every operator render); in a CLI-solo cluster the CLI writes an un-owned `cluster` Platform write-if-absent, which the operator adopts on install. The precedence is load-bearing for accessibility, not just convenience: a non-admin who cannot read the cluster `Platform` must still render against a local Platform, so every non-`handoff` path stays usable without cluster-admin (D17). The concrete per-command flag surface for selecting the source is OQ14; `diff`'s source is OQ12.

### 3. Apply stays CLI-side, SSA mandatory

The CLI keeps its own apply step — client-go server-side apply, field manager `opm-cli` (D10). Duplicating the operator's apply semantics (staging order, conflict handling) is explicitly accepted; the apply engines are not unified in this enhancement. The single hard requirement is that the CLI apply path uses **server-side apply**, because SSA field-manager semantics are what make the handoff transition window safe: when ownership flips and the operator's `opm-controller` manager applies the same fields, SSA resolves the overlap by manager transfer rather than a destructive replace.

### 4. The feature: `opm release handoff`

With a shared CR (move 1) and a shared kernel (move 2), handoff is a verified ownership flip (D7). Preconditions checked in order: operator installed and ready; the CR exists with `spec.owner: cli`; `spec.module` is a published, registry-resolvable reference (D6); and the render digest the CLI computes from that reference matches `status.lastAppliedRenderDigest`. The match is now meaningful precisely because both sides render through the same kernel. Then the CLI patches `spec.owner: operator` (single SSA patch) and waits, bounded, for the operator's first reconcile: expected `Ready: True`, inventory revision incremented, zero resources changed, zero pruned. Handoff is **forward-only** (CLI → operator); the reverse flip (`--to cli`) is out of scope (D16).

### Supporting pieces

- **`spec.owner` marker (D3).** A spec-level `owner: cli | operator` field (default `operator`). When `spec.owner: cli`, the operator skips render/apply/prune entirely and sets a single `Ready: Unknown` / `ManagedExternally` condition, never touching CLI-written status. This is an operator-side change, documented here under the cross-repo scope.
- **`opm install` (D5).** Because inventory now lives in a CR, the `ModuleRelease` CRD is a hard prerequisite for every CLI apply. `opm install crds` (CRDs only) and `opm install operator` (full operator from `dist/install.yaml`) install via SSA with manager `opm-cli`; manifests are embedded at build time with a `--version` fetch fallback. `opm uninstall operator` never deletes CRDs (deleting a CRD cascades to every `ModuleRelease` in the cluster); CRD removal is a deliberate manual `kubectl delete crd`.
- **Local-path applies (D6).** When applying from a published reference the CLI writes it into `spec.module` verbatim; from a local path it writes best-effort path/version plus a `source: local` annotation, leaving the CR a valid inventory store but not yet reconcilable. D3 makes this safe (the operator does not act on CLI-owned CRs) and D7 refuses to flip ownership until `spec.module` resolves.
- **Secret migration (D8).** On apply against a release that has a Secret but no CR, the CLI reads the Secret, creates the CR, writes the Secret's record into `status.inventory` (preserving revision), applies, then deletes the Secret only after the status write succeeds. `status`/`delete`/`list` fall back to reading Secrets for one minor release with a deprecation warning, then the Secret path is removed.

## Schema / API Surface

The new and changed shapes live in [`schemas/target.cue`](schemas/target.cue) (CR + status-subset shapes expressed as CUE for review) — these mirror Go types in `opm-operator/api/v1alpha1`, the source of truth. Headlines:

- `ModuleRelease.spec.owner: "cli" | "operator"` (default `"operator"`) — the new ownership marker (D3).
- The **CLI status subset** (D2): the CLI writes only `inventory`, `releaseUUID`, `lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`, and one `Ready` condition (reason `AppliedByCLI`). Everything else in `ModuleReleaseStatus` stays operator-owned and unset by the CLI.
- The **shared inventory surface** (D13) in the new `library/opm/inventory` package — runtime-neutral entry type, `NewEntryFromResource` (from kernel-rendered resources), `IdentityEqual` / `K8sIdentityEqual`, `ComputeStaleSet`, `ComputeDigest` — consumed by both CLI and operator. The operator's `api/v1alpha1.InventoryEntry` remains the CRD serialization shape and maps to/from the `library` type.

## Integration Points

### opm-operator

- `api/v1alpha1/modulerelease_types.go` — add `spec.owner: cli|operator` field with defaulting; regenerate CRD (`config/crd/bases/`).
- Reconciler — add the `spec.owner: cli` skip path and the `ManagedExternally` condition (D3).
- `internal/inventory/` (pure logic) → migrates to `library` (D13, supersedes D4's "promote to operator `pkg/`"); the operator then consumes the `library` package. `api/v1alpha1.InventoryEntry` stays as the CRD serialization shape and maps to/from the `library` type. Decide via OQ6 whether CLI-only prune-safety checks (component-rename detection, pre-apply existence check) move into the shared `library` package.
- `go.mod` — bump `k8s.io/*` and `controller-runtime` to the CLI's latest-stable k8s line, and the `go` directive to match (Problem 3, `research/findings.md`). A small prep slice, independent of the rest.
- `dist/install.yaml`, `config/crd/bases/*.yaml` — consumed (embedded) by the CLI's `opm install`; no change beyond the CRD regen.

### library

- New `library/opm/inventory/` package (D13) — the shared, runtime-neutral inventory logic: build entries from kernel-rendered resources, `IdentityEqual` / `K8sIdentityEqual`, `ComputeStaleSet`, `ComputeDigest`. Consumed by both the CLI and the operator so handoff prune-set parity is structural. No k8s-typed dependency beyond `apimachinery` identity primitives; no controller-runtime, no Flux.

### cli

- `internal/inventory/` (Secret marshaling, CRUD) — **deleted** (D1).
- `pkg/inventory/` (CLI's entry-identity/stale-set copy) — **deleted**, replaced by the `library/opm/inventory` import (D13).
- `pkg/render/`, match path in `pkg/loader/` — **deleted**, replaced by `library` kernel calls (D9).
- `internal/workflow/apply/apply.go` — rewired as a one-shot reconcile (D13): render via kernel, compute stale set via `library/opm/inventory`, SSA apply via the CLI engine (D10), prune with the ownership guard, write the CR status subset (D2) as `unstructured`, Secret migration (D8/D14). Borrows the operator's phase order; runs no controller-runtime loop.
- `internal/kubernetes/` — the SSA apply/delete path that stays CLI-owned; ensure it uses server-side apply with manager `opm-cli` (D10).
- `internal/cmd/release/{apply,delete,status,list,diff}.go` — read/write the CR instead of the Secret.
- New `internal/cmd/install/` (or equivalent) — `opm install crds|operator`, `opm uninstall operator`, embedded manifests, `--version` (D5).
- New `internal/cmd/release/handoff.go` — `opm release handoff` with D7 verification; **forward-only** (CLI → operator), no reverse mode (D16).
- **Module rename (D15)** — `cli/go.mod` `module` line and every internal `github.com/opmodel/cli/...` import path renamed to `github.com/open-platform-model/cli`; a mechanical prep slice landed before the `library` edge is added, so the kernel/inventory imports are written against the final name.
- `go.mod` — add `github.com/open-platform-model/library` **only** (kernel + the new shared inventory package). Do **not** add `opm-operator` (D13 — it drags controller-runtime + Flux). The `ModuleRelease` CR is read/written as `unstructured` via the CLI's existing client-go. The CUE bump to v0.17.0-alpha.1 is forced by importing `library` and is accepted (D14).
- New platform-resolution code (D11/D12/D17): resolve the platform spec by precedence (`--platform` flag > cluster `Platform` CR > local/embedded default), call `SynthesizePlatform` → `Materialize`, and on a solo cluster write the singleton `cluster` Platform CR write-if-absent (SSA, manager `opm-cli`). `handoff` forces the cluster-CR source; every other path stays usable against a local Platform with no cluster-admin (D17). Concrete flag surface across commands is OQ14; `diff`'s source is OQ12; write-if-absent atomicity is OQ13.

## Before / After

### Inventory store

```diff
- Secret opm.jellyfin.<uuid>  (type opmodel.dev/release, key "inventory")
-   data.inventory = JSON ReleaseInventoryRecord{ CreatedBy, …, Inventory{…} }
+ ModuleRelease jellyfin (namespace media)
+   spec.owner: cli
+   spec.module: { path: example.com/modules/jellyfin, version: 1.2.0 }
+   status.inventory: { revision, digest, count, entries[] }
+   status.lastAppliedRenderDigest: <digest computed by the library kernel>
+   status.conditions: [ { type: Ready, reason: AppliedByCLI } ]
```

### Render path

```diff
  opm release apply
-   cli/pkg/render  +  cli/pkg/loader (match)      # CLI's own pipeline
+   library kernel: match + render                  # same kernel the operator runs
    cli/internal/kubernetes SSA apply (opm-cli)     # CLI keeps its own apply
```

### Handoff (the new capability)

```diff
- (impossible) hand-write a ModuleRelease, kubectl apply, delete the Secret, hope the
-   operator's first reconcile is a no-op
+ opm release handoff jellyfin
+   verify operator ready → CR is owner:cli → spec.module resolvable →
+   render digest == status.lastAppliedRenderDigest  (parity guaranteed by shared kernel)
+   patch spec.owner: operator → operator reconcile: Ready:True, 0 changed, 0 pruned
```
