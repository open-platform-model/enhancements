# Design Decisions — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. The log is **append-only** — never remove or renumber. A reversed decision gets a new entry that supersedes it; the original stays.

D1–D8 are promoted from `cli/docs/rfc/0007`, which is the design rehearsal for this work; their Source lines cite the RFC. D9 and D10 are decisions taken when this enhancement was created (user direction, 2026-06-22) and they extend the RFC: D9 pulls render/match into scope (the RFC had left the whole engine question to "future work"), and D10 fixes the precise render-vs-apply cut.

---

## Decisions

### D1: The CLI writes a `ModuleInstance` CR instead of a Secret

**Decision:** On `opm instance apply`, the CLI creates/updates a `ModuleInstance` object named after the release, in the release namespace, and stores its inventory in `status.inventory` via the status subresource. `instance delete` resolves inventory from the CR and deletes the CR last; `instance list` lists `ModuleInstance` objects; `instance status` / `diff` read `status.inventory`. CR writes use field manager `opm-cli`. `cli/internal/inventory` (Secret CRUD/marshaling) is deleted.

**Alternatives considered:**

- Keep the Secret, add a CR mirror. Rejected: two stores reintroduces exactly the disjoint-source-of-truth problem the enhancement exists to remove.
- A new CLI-specific CRD distinct from the operator's. Rejected: a separate type defeats the handoff goal — the whole point is that both actors read and write the *same* object.

**Rationale:** A single source of truth for "what is deployed" that both the CLI and operator already share the shape of. The operator's prune set is `previous status.inventory − current render`; if the CLI has written the deployed entries into `status.inventory`, the operator's first post-handoff reconcile sees a zero stale set.

**Source:** `cli/docs/rfc/0007` D1.

---

### D2: The CLI writes a strict subset of status

**Decision:** The CLI writes only `inventory`, `instanceUUID`, `lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`, and a single `Ready` condition with reason `AppliedByCLI`. It does **not** write `observedGeneration`, `lastAttempted*`, `failureCounters`, `history`, or `nextRetryAt`. The operator MUST tolerate a `ModuleInstance` carrying only this subset (it already tolerates empty status on a fresh CR).

**Alternatives considered:**

- The CLI writes the full status shape. Rejected: most fields encode control-loop semantics (retry bookkeeping, observed generation) that a one-shot actor cannot meaningfully own; writing them would be fiction the operator then has to distrust.
- The CLI writes no status, only spec, and lets the operator populate status. Rejected: then a CLI-only cluster (no operator) has no inventory at all — the store has to be CLI-written.

**Rationale:** The CLI is a one-shot actor with no reconcile loop. The subset is exactly the facts it can stand behind, and exactly what the operator needs to detect a no-op on first reconcile (the `lastApplied*` digests + inventory).

**Source:** `cli/docs/rfc/0007` D2.

**Amended by D25:** the CLI no longer writes the `Ready` condition; `status.conditions` is operator-exclusive. D2's written subset is reduced to `inventory`, `instanceUUID`, and the `lastApplied*` fields (`lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`). The rest of D2 stands.

---

### D3: Explicit `spec.owner` marker; the operator skips CLI-owned CRs

**Decision:** Add `spec.owner: "cli" | "operator"` to `ModuleInstance` (default `"operator"`). When `spec.owner: cli`, the operator skips render/apply/prune entirely, sets a single `Ready: Unknown` condition with reason `ManagedExternally`, and never touches `status.inventory` or any CLI-written status field. The CLI's existing `EnsureCLIMutable` guard maps onto this field: the CLI refuses to apply/delete a release whose `spec.owner` is `operator`. This is an operator-side change, documented here per the cross-repo scope.

**Alternatives considered:**

- `spec.suspend: true` as the marker. Rejected: conflates "paused" with "CLI-owned"; a `kubectl edit` unsuspend would trigger an unverified takeover. Suspend stays orthogonal.
- Status-driven skip (`status.inventory.createdBy == cli`). Rejected: driving controller behaviour from status is fragile (status is lost on backup/restore); spec is the user-intent surface.

**Rationale:** A CLI-created CR in a cluster running the operator would otherwise be reconciled immediately, with the operator fighting the CLI for resources. An explicit spec-level marker the operator respects is the minimal safe coordination point, and it is the field `handoff` flips.

**Source:** `cli/docs/rfc/0007` D3.

---

### D4: The operator exports its inventory package; the CLI imports it

**Decision:** `opm-operator/internal/inventory` moves to `opm-operator/pkg/inventory` (no behaviour change), exporting `InventoryEntry`, `NewEntryFromResource`, `IdentityEqual`, `K8sIdentityEqual`, `ComputeStaleSet`, `ComputeDigest`. The CLI adds `github.com/open-platform-model/opm-operator` to `go.mod` and imports `api/v1alpha1` (the `ModuleInstance`/`Inventory`/`InventoryEntry` types), `pkg/inventory` (the functions above), and `pkg/core` (label constants). The CLI does **not** import the operator's apply/prune engine. Dependency direction `cli → opm-operator` is accepted.

**Alternatives considered:**

- Move the shared types into `library`, both repos import from there. Cleaner long-term, but fights Kubebuilder codegen for the CRD types and adds a third repo to every schema change. Reserved — see OQ2, which reopens this now that the CLI also depends on `library` (D9).
- Keep the CLI's own inventory copy. Rejected: the two copies already drifted once; a single shared implementation is the point.

**Rationale:** The inventory shape and functions already exist in the operator (copied from the CLI by the `cli-dependency-and-inventory-bridge` change, which explicitly anticipated this promotion). Inverting the dependency — operator owns, CLI imports — gives one implementation. The import is narrow: API types plus pure functions, pulling in apimachinery but not controller-runtime's manager or Flux SSA.

**Source:** `cli/docs/rfc/0007` D4; `opm-operator/openspec/changes/archive/2026-04-12-01-cli-dependency-and-inventory-bridge/`.

**Superseded in part by D13** (dependency direction). Static analysis (`research/findings.md`) showed `opm-operator/api/v1alpha1` drags `controller-runtime/pkg/scheme` + `fluxcd/pkg/apis/meta` + `apiextensions-apiserver` into any importer, because Go imports at package granularity. The CLI does **not** import the operator after all; the shared inventory logic moves to `library`.

---

### D5: `opm install` — CRDs and operator via the CLI

**Decision:** Add `opm install crds` (CRDs only — required for any CLI apply), `opm install operator` (full operator from `dist/install.yaml`), and `opm uninstall operator`. Installs use SSA with field manager `opm-cli`. The CLI embeds the CRD manifests and `dist/install.yaml` of a pinned operator version at build time (`go:embed`), with `--version` to fetch a different release. `opm uninstall` never deletes CRDs. Missing-CRD behaviour on `instance apply`: fail with a one-line hint (`ModuleInstance CRD not found — run 'opm install crds'`), not silent auto-install.

**Alternatives considered:**

- Auto-install CRDs inside `instance apply`. Rejected: installing CRDs is a cluster-admin write; doing it implicitly inside an app apply surprises exactly the operators who care. A `--install-crds` convenience flag is left open (OQ7).
- Fetch manifests from GitHub at runtime always (no embed). Rejected: breaks the offline learner path and loses the build-time "this CLI matches this CRD version" fact. Embed is default, fetch is the fallback.

**Rationale:** Once inventory lives in a CR, the CRDs are a hard prerequisite for *every* CLI apply, including clusters that never run the operator. Embedding keeps the learner path offline-friendly; never deleting CRDs via the CLI makes accidental cluster-wide data loss impossible (a CRD delete cascades to every `ModuleInstance`).

**Source:** `cli/docs/rfc/0007` D5.

---

### D6: Spec contents when applying from a local module

**Decision:** When the CLI applies from a published module reference, it writes that reference into `spec.module` verbatim. When it applies from a local path, it writes the module's declared path/version as best-effort metadata plus a `module-instance.opmodel.dev/source: local` annotation; the CR is a valid inventory store but not yet reconcilable. Handoff (D7) is the gate that guarantees `spec.module` is resolvable before the operator ever owns the CR.

**Alternatives considered:**

- Refuse to write a CR when applying from a local path. Rejected: CLI-from-local-path is a primary learner workflow; it must still get CR-backed inventory.
- Publish the local module automatically on apply. Rejected: applying and publishing are distinct user intents; conflating them surprises the user and may push to a registry they did not choose.

**Rationale:** A CLI-owned CR can temporarily describe a module the operator could not fetch, and that is safe *because* D3 stops the operator acting on CLI-owned CRs and D7 refuses to flip ownership until the spec is reconcilable.

**Source:** `cli/docs/rfc/0007` D6.

---

### D7: `opm instance handoff` — the migration feature

**Decision:** `opm instance handoff <release>` verifies, in order: (1) operator installed and ready; (2) the CR exists with `spec.owner: cli`; (3) `spec.module` is a published, registry-resolvable reference; (4) the render digest the CLI computes from the published reference + the CR's values matches `status.lastAppliedRenderDigest` — mismatch aborts (`--force` overrides with a diff). Then it patches `spec.owner: operator` (single SSA patch, manager `opm-cli`) and waits, bounded, for the operator's first reconcile, reporting the outcome (expected: `Ready: True`, inventory revision incremented, zero changed, zero pruned). A reverse flip (`--to cli`) reuses the same machinery.

**Alternatives considered:**

- Flip ownership without digest verification. Rejected: an unverified flip is exactly the unsafe manual path this enhancement replaces.
- A separate `opm migrate` top-level command. Rejected: handoff is a release-scoped operation; it belongs under `release`.

**Rationale:** With shared inventory (D1) and a shared kernel (D9), the digest check in step 4 is *meaningful* — both sides render through the same kernel, so equal digests genuinely mean the operator's first apply is a no-op. The zero-downtime property is the payoff of the whole enhancement.

**Source:** `cli/docs/rfc/0007` D7. Note: the RFC framed step-4 parity as best-effort because the CLI then had its own pipeline; D9 makes it structural.

---

### D8: Migration of existing Secret inventories

**Decision:** On `opm instance apply` against a release that has a Secret inventory but no `ModuleInstance` CR: read the Secret, create the CR, write the Secret's record into `status.inventory` (preserving revision), proceed with the normal apply, then delete the Secret only after the CR status write succeeds. `instance status`/`delete`/`list` fall back to reading Secrets for one minor release with a deprecation warning; after that the Secret path is removed entirely.

**Alternatives considered:**

- Hard cutover (no Secret fallback). Rejected: silently orphaning resources tracked only in a pre-existing Secret is the worst possible outcome.
- A one-off `opm migrate-inventory` command users must run. Rejected: migration on next apply is invisible and reliable; an opt-in command would be skipped and leave stragglers.

**Rationale:** Delete-after-success ordering means a failure mid-migration leaves the Secret intact and the release still discoverable. The one-release fallback window covers releases not yet re-applied.

**Source:** `cli/docs/rfc/0007` D8.

**Amended by D14:** the CLI has no external users, so the one-minor-release Secret read-fallback window collapses to a single best-effort one-time migration (or a manual re-apply of the developer's own live releases); no deprecation window is owed.

---

### D9: The CLI replaces its own render/match pipeline entirely with the `library` kernel

**Decision:** The CLI deletes `cli/pkg/render` and the match path in `cli/pkg/loader`, and renders every release through the `library` kernel — the same kernel the operator runs. The CLI becomes a kernel consumer (load module → obtain materialized platform → kernel match + render → rendered resources + render digest). The CLI carries no second render/match implementation. This decision extends `cli/docs/rfc/0007`, which had left engine unification entirely to "future work."

**Alternatives considered:**

- Keep the CLI's own pipeline, share only the inventory store. Rejected: render-digest parity for handoff (D7 step 4) cannot be guaranteed by two independent pipelines; half the convergence buys none of the safety.
- Keep the CLI's pipeline but re-implement 0001's matcher inside it to stay aligned. Rejected: a permanent second implementation of the most intricate part of OPM, drifting on every 0001 follow-up.

**Rationale:** One render/match implementation across both actors makes handoff digest parity structural and means 0001's matcher redesign (and every future kernel change) reaches the CLI for free. The cost — a new `cli → library` dependency and the materialized-platform-sourcing question (OQ1) — is accepted. This strand depends on 0001's `library` slice landing; the inventory/CR/handoff strand does not (OQ5).

**Source:** User decision 2026-06-22.

---

### D10: The CLI keeps its own server-side apply engine; duplication accepted, SSA mandatory

**Decision:** The CLI keeps its own apply step (`cli/internal/kubernetes`, client-go server-side apply, field manager `opm-cli`). It does not import the operator's apply/prune engine. Duplicating the operator's apply semantics (staging order, conflict handling) is explicitly accepted; the operator may serve as the reference implementation to copy from. The one hard requirement: the CLI apply path MUST use server-side apply. Render/match is unified (D9); apply is not.

**Alternatives considered:**

- Unify the apply engine too (both consume one shared apply package, likely via `library`). Rejected for this enhancement: the operator applies via Flux `ResourceManager.ApplyAllStaged` wired into controller-runtime; lifting that into a CLI-usable package is a large, separable effort. Digest verification (D7.4) plus SSA field-manager transfer already make handoff safe without engine parity.
- Allow client-side apply in the CLI. Rejected: SSA field-manager semantics are what make the handoff transition window safe (manager transfer rather than destructive replace when ownership flips); client-side apply would reopen the takeover race.

**Rationale:** The render/apply cut is the cheapest line that still delivers the safety property: render parity (which needs the shared kernel) makes the operator's first apply a no-op; apply parity (which needs a shared engine) is not required for that. SSA on both sides is the non-negotiable part; the engine being duplicated is acceptable.

**Source:** User decision 2026-06-22.

---

### D11: The CLI's platform source is a precedence — flag, then cluster Platform CR, then local default; handoff forces the CR

**Decision:** The CLI resolves the platform it feeds to `Kernel.SynthesizePlatform` by precedence: (1) an explicit `--platform <file>` override; else (2) when targeting a cluster, the singleton `Platform` CR's spec read from the cluster and materialized locally via `Kernel.Materialize`; else (3) a local/embedded default platform — the evolution of today's `~/.opm/config.cue` provider. `opm instance handoff` forces source (2) with no fallback: absent a cluster `Platform`, handoff refuses, because render parity with the operator cannot be guaranteed otherwise. Offline `build` / `render` use sources (1)/(3) only and never touch the cluster. The CLI reads the Platform *spec* and runs `Materialize` itself — the operator never persists a materialized platform (it lives only in the controller's in-memory, generation-keyed `platformstore.Store`; `PlatformStatus` holds conditions only), so reading a pre-materialized result is impossible; both actors materialize from the same spec.

**Alternatives considered:**

- Always render against a local/config platform, never read the cluster. Rejected: the CLI and operator could then render the same instance differently; handoff digest parity (D7.4) degrades to best-effort and the cluster-consistency property is lost.
- Make a cluster `Platform` CR a hard prerequisite for *every* render, including offline `build`. Rejected: breaks offline authoring and the learner-solo path (a freshly-CRD'd cluster has no Platform yet).

**Rationale:** The platform is a property of the cluster — when targeting an operator-managed cluster the CLI must render against *that cluster's* platform or it deploys something the cluster's own reconciler would render differently. The precedence keeps offline authoring working while making the cluster CR authoritative where correctness depends on it. It mirrors the CLI's existing provider resolution (flag > config > default) and D5's "CRDs are a prerequisite" shape. A residual parity subtlety: because each side materializes fresh, a catalog version published between CLI apply and operator takeover can yield different materialized sets — D7.4's digest check catches it (safely aborting handoff); pinning the exact materialized version-set is a possible future hardening.

**Source:** User decision 2026-06-22. Grounded in `opm-operator/internal/controller/platform_controller.go` (`SynthesizePlatform` → `Materialize` → in-memory `Store`), `opm-operator/internal/render/kernel_module_renderer.go` (render gates on the store via `ErrPlatformNotReady`), and `cli/pkg/provider/` + `cli/internal/config/` (today's local provider resolution this evolves).

---

### D12: `Platform` carries no owner marker; the operator always owns the singleton; the CLI writes an un-owned `cluster` Platform in solo clusters

**Decision:** Unlike `ModuleInstance` (D3), the `Platform` CR gets **no** `spec.owner` skip marker. The operator's `PlatformReconciler` always materializes the singleton `cluster` Platform — its in-memory store is the sole input to every operator `ModuleInstance` render, so an operator that "skipped" the platform could render nothing. The CLI therefore only ever *reads* the Platform; it never owns or suspends it. In a CLI-solo cluster (CRDs installed per D5, no operator/Platform yet), the CLI writes its resolved local/default platform as the singleton `cluster` Platform CR — **write-if-absent**, never overwriting an existing operator- or user-managed Platform — using SSA field manager `opm-cli`. When the operator is later installed it adopts and materializes that existing spec; there is no platform-level handoff.

**Alternatives considered:**

- Give `Platform` the same `spec.owner` skip semantics as `ModuleInstance`, for symmetry. Rejected: a CLI-owned, operator-skipped singleton empties the operator's store and gates *every* operator render. The singleton cannot be per-actor the way namespaced releases can.
- CLI never writes a Platform; solo render stays local-only. Rejected (user decision): writing the singleton gives the cluster a record of what the CLI rendered against and lets the operator adopt it on install with zero extra steps.

**Rationale:** `ModuleInstance` ownership can be per-release and mixed; the `Platform` singleton cannot — the operator structurally needs it for its own function. So the platform is shared-read, operator-owned, with the CLI bootstrapping it when absent. Write-if-absent avoids clobbering a GitOps-defined Platform; SSA lets a user or the operator take field ownership later. This asymmetry with D3 is deliberate and must not be "consistency"-fied into owner-skip semantics by a slice.

**Source:** User decision 2026-06-22.

---

### D13: The CLI imports `library` only; it does not import `opm-operator` (no controller-runtime, no Flux) — supersedes D4's dependency direction

**Decision:** The CLI does **not** add a Go-module dependency on `opm-operator`. Importing `opm-operator/api/v1alpha1` (needed for the typed `ModuleInstance` and `InventoryEntry`) drags `sigs.k8s.io/controller-runtime/pkg/scheme`, `github.com/fluxcd/pkg/apis/meta`, and `k8s.io/apiextensions-apiserver` into the importer, because Go compiles whole packages and those types share the `v1alpha1` package (evidence: `research/findings.md`). Instead:

1. The shared **pure inventory logic** — building inventory entries from kernel-rendered resources, identity equality (`IdentityEqual`/`K8sIdentityEqual`), `ComputeStaleSet`, `ComputeDigest` — homes in `library` over a runtime-neutral entry type, and is consumed by **both** the CLI and the operator. This is required for correctness, not just tidiness: the operator's post-handoff prune set is `previous status.inventory.entries − current render entries`, so the CLI and operator must compute entry identity and digests with the *same* code or handoff prune-set parity breaks.
2. The CLI represents the `ModuleInstance` CR via `unstructured` (client-go dynamic) — or a CLI-local minimal typed struct — carrying **no** Flux / controller-runtime imports. It sets `spec.owner`, `spec.module`, `status.inventory`, etc. by field path; it does not need the operator's typed API package.
3. The CLI's apply + prune is a **one-shot** design (the CLI is not a long-running process — no informers, no work queue, no controller-runtime manager). It borrows the operator's reconcile *concepts* — phase order (render → plan stale → SSA apply → prune → write status), inventory-authoritative pruning, the ownership/managed-by guard, the never-prune-Namespaces/CRDs safety — by porting the logic, not by importing controller-runtime.

The CLI's resulting `go.mod` gains `library` only (plus its existing `client-go`/apimachinery). The `cli → opm-operator` edge is dropped; "borrow code from the operator" means port concepts/code or consume the shared logic from `library`, not a module dependency. The diamond collapses to a single `cli → library` edge.

**Alternatives considered:**

- D4 as written — CLI imports `opm-operator/api/v1alpha1` + `pkg/inventory`. Rejected: pulls controller-runtime + Flux + apiextensions into a one-shot CLI for no benefit; the CLI runs no controller machinery.
- Refactor the operator's `v1alpha1` package to split the Flux-dependent CRs (`Release`/`BundleRelease`) from `ModuleInstance`/`Platform`/inventory so a thin import avoids the drag. Rejected for now: fights Kubebuilder's single-package-per-API-group codegen and the shared `groupversion_info.go` scheme builder; large operator-side churn for a coupling we can avoid entirely.

**Rationale:** The CLI gets one render/match implementation (the kernel, D9) and one inventory implementation (now in `library`) without inheriting the operator's long-running-process dependency stack. Homing the pure logic in `library` keeps CLI and operator byte-identical where handoff parity demands it. The operator migrates its `internal/inventory` pure parts to consume the `library` package (replacing D4's "promote `internal/inventory` → `pkg/inventory`" — the home is `library`, not operator `pkg/`); its `api/v1alpha1.InventoryEntry` stays as the CRD serialization shape and maps to/from the `library` type.

**Source:** User decision 2026-06-22, on the `research/findings.md` dependency analysis. Supersedes D4's dependency direction; D4's intent (one shared inventory implementation, no CLI re-derivation) is preserved — only the home and import direction change.

---

### D14: No backwards-compatibility or deprecation burden; the CUE v0.17-alpha bump is accepted

**Decision:** The CLI has a single user (the developer); slices may refactor it wholesale and owe **no** backwards-compatibility guarantees and **no** deprecation windows. Two concrete consequences: (1) D9's forced bump of the CLI from `cuelang.org/go` v0.16.1 to v0.17.0-alpha.1 (because `library` and `opm-operator` are on the alpha, and MVS takes the max) is **accepted** — the CLI's existing v0.16 CUE Go-API usage is migrated to v0.17 as part of the kernel-adoption work, not guarded behind a compatibility shim. (2) D8's Secret→CR migration drops its one-minor-release fallback window: a single best-effort one-time migration on next apply (or a manual re-apply of the developer's own live releases) is sufficient; the Secret path is then deleted outright.

**Alternatives considered:**

- Preserve v0.16 compatibility / dual-build the CLI across CUE versions. Rejected: no consumer needs it; MVS makes a single CUE version mandatory once `library` is imported anyway.
- Keep the deprecation window on the Secret format. Rejected: protects nobody; adds fallback code paths to maintain and test.

**Rationale:** Spending implementation effort on compatibility and deprecation that protects no user is exactly the "unnecessary job" to avoid. Recording this up front keeps slices lean. The CUE-alpha dependency is a real stability note (the CLI ships against a CUE pre-release) but is accepted under the same single-user stance; it is tracked as a risk, and naturally resolves when `library`/`opm-operator` move to stable v0.17.

**Source:** User decision 2026-06-22. Captured in memory (`cli-no-external-users`).

---

### D15: Rename the CLI Go module from `github.com/opmodel/cli` to `github.com/open-platform-model/cli`

**Decision:** As part of this enhancement the CLI's Go module path is renamed `github.com/opmodel/cli` → `github.com/open-platform-model/cli`, aligning it with `library` (`github.com/open-platform-model/library`) and `opm-operator` (`github.com/open-platform-model/opm-operator`). The rename is a mechanical sweep: the `module` line in `cli/go.mod`, every internal `github.com/opmodel/cli/...` import path, and any doc/CI reference. It lands as its own prep slice ahead of the kernel-adoption work so the `cli → library` edge (D9/D13) is added under the final module name, not a name that immediately changes.

**Alternatives considered:**

- Leave the path as `github.com/opmodel/cli`. Rejected: this enhancement is the first to formally wire the CLI into the org's module graph (D9/D13), and `research/findings.md` already flagged the inconsistency (RFC-0007 assumed `github.com/open-platform-model/cli`). Coupling under a divergent org path is avoidable churn.
- Defer the rename to a separate, unrelated cleanup. Rejected: the import-path change is breaking, and D14 already grants a no-compat refactor window — doing it inside the same wave that adds the `library` edge means a single break, not two.

**Rationale:** One org namespace across the three coupled repos removes a standing inconsistency at the exact moment the modules become interdependent. Under D14 (single user, no backwards-compat) an import-path break costs nothing to absorb, so the cheapest time to rename is now, before the kernel/inventory imports are written against the old name.

**Source:** User decision 2026-06-22.

---

### D16: Reverse handoff (`--to cli`) is out of scope — supersedes the reverse-mode portion of D7

**Decision:** `opm instance handoff` ships in the forward direction only (CLI → operator). The reverse flip (`--to cli`, operator → CLI) named in D7 is **removed from scope**. The verification machinery, command surface, and the operator-side concerns of flipping a reconciled CR back to CLI ownership are not built in this enhancement. D7's forward path (preconditions → digest check → `spec.owner: operator` patch → bounded no-op-reconcile wait) is unchanged.

**Alternatives considered:**

- Keep `--to cli` as D7 specified. Rejected (user decision): reverse handoff carries its own unresolved concerns the forward path does not — chiefly cleaning up operator-written control-loop status (`observedGeneration`, `failureCounters`, `history`, `nextRetryAt`) left on a CR that flips back to a one-shot owner, plus the takeover-window race in the operator-relinquishing direction. None of that is needed for the headline learner-to-operator path.
- Build reverse handoff but gate it behind a flag. Rejected: still owes the status-cleanup and relinquish-race design; deferring the whole capability is cleaner than a half-built one.

**Rationale:** The enhancement's value is the one-directional CLI → operator transition (the "grow into GitOps" story). Reverse handoff is a separable capability with its own design surface; excluding it keeps the slice lean and avoids shipping an under-specified relinquish path. It can return as a future enhancement if a concrete need appears.

**Source:** User decision 2026-06-22. Supersedes the reverse-mode (`--to cli`) portion of D7; D7's forward path stands.

---

### D17: Both a local Platform and an in-cluster Platform CR are first-class; OPM must never require cluster-admin for normal use

**Decision:** The platform-source precedence in D11 (`--platform` flag > cluster `Platform` CR > local/embedded default) is a deliberate accessibility constraint, not just a convenience ordering: a user who is **not** a cluster admin — who cannot read or write the cluster-scoped singleton `Platform` CR — must still be able to render and apply releases against a local/embedded Platform. Forcing the cluster `Platform` CR as a hard prerequisite for every render would make cluster-admin a precondition for using OPM at all, which is explicitly not the intent. `handoff` is the one operation that forces the cluster CR (D11), and that is acceptable precisely because handoff is an operator-adoption step that inherently assumes operator/admin context. Every non-handoff path (`build`, `render`, `apply`, `diff`) must remain usable with a local Platform and no cluster Platform access.

**Alternatives considered:**

- Make the cluster `Platform` CR authoritative for all cluster-targeting commands, local Platform only for fully-offline `build`/`render`. Rejected: a non-admin who can apply `ModuleInstance` objects into their own namespace but cannot read the cluster-scoped `Platform` would be locked out of `apply` — turning OPM into an admin-only tool.
- Local Platform only; never read the cluster Platform. Rejected: that is the opposite failure — it loses cluster-render parity where correctness depends on it (the original reason for D11). Both must be first-class; the precedence picks between them per-command.

**Rationale:** OPM's adoption story is "anyone can try it." Gating normal use on admin-only cluster state contradicts that. Supporting both Platform sources — local for the unprivileged/solo path, cluster CR where parity with the operator matters — is what keeps the tool open to non-admins while preserving handoff safety. This frames D11's precedence as load-bearing for accessibility and constrains slices from ever "simplifying" it down to a cluster-only source.

**Source:** User decision 2026-06-22. Reinforces and constrains D11/D12.

---

### D18: After handoff the CLI may still edit the CR's spec; it writes only the CR and defers execution to the operator — refines D3's `EnsureCLIMutable` guard

**Decision:** The CLI is dual-mode, keyed on `spec.owner`:

- **`spec.owner: cli`** — the CLI is the full one-shot executor: render → SSA-apply resources → compute inventory → write the status subset (D2). It *is* the reconciler for that release.
- **`spec.owner: operator`** — the CLI is a thin CR editor. `opm instance apply` against an operator-owned release unifies its values, patches `spec` (`spec.module`, `spec.values`) via SSA manager `opm-cli`, waits bounded for the operator's reconcile, and reports the operator's status. It does **not** apply resources, prune, write inventory, or write the status subset — the operator owns all of that.

D3's `EnsureCLIMutable` guard is therefore refined: it gates the **direct-resource-apply path** (render + SSA-apply + inventory + status), not CR-*spec* edits. The CLI never refuses to edit an operator-owned CR's spec; it refuses only to act as the resource reconciler for one. `opm instance apply` branches on `spec.owner` to pick the path. Whether `instance delete` gets the symmetric treatment (delete the operator-owned CR and let the operator's finalizer prune, vs. refuse) is left to the apply/delete slice.

**Alternatives considered:**

- D3 as written — the CLI refuses any operator-owned release outright. Rejected (user decision): it denies a useful and safe workflow. Editing `spec` on an operator-owned CR is just a normal spec write that triggers the operator's reconcile; there is no takeover, because the CLI never touches resources or status in this mode. Refusing turns the CLI into a tool that goes dark the moment a release graduates to the operator.
- Let the CLI edit the spec *and* keep applying resources directly when `owner: operator`. Rejected: that is the exact two-actors-fighting-over-resources hazard D3 exists to prevent. The split must be at the execution boundary — spec edits yes, resource apply no.

**Rationale:** A single, consistent CLI surface across a release's whole lifecycle: the user runs `opm instance apply` the same way before and after handoff, and only the execution path underneath changes (the CLI reconciles when it owns; it hands the spec to the operator when the operator owns). This makes the CLI a typed front-end for `ModuleInstance` in operator-managed clusters, and it narrows OQ3 (status-subresource RBAC) to CLI-owned mode only — in operator-owned mode the CLI writes `spec` and never `status`. The continuous-spec-editing path also makes [D19](#d19-specvalues-is-the-sole-authoritative-render-input-the-cli-unifies-all-value-inputs-into-it--resolves-oq10)'s "`spec.values` is the sole authoritative render input" invariant load-bearing beyond the handoff moment: every post-handoff CLI edit relies on the operator reproducing the render from `spec.values` alone.

**Source:** User decision 2026-06-23. Refines D3 (append-only — D3 stands; D18 narrows the guard it describes).

---

### D19: `spec.values` is the sole authoritative render input; the CLI unifies all value inputs into it — resolves OQ10

**Decision:** The CLI resolves and unifies **all** of its value inputs (multiple `--values` files, config layering, and any future value source) into a single `spec.values` blob, writes that blob to the CR, and renders its own apply — and computes `lastAppliedRenderDigest` — from `spec.values`, not from any richer in-memory effective set. `spec.values` is thus the single authoritative render input that both actors consume: the operator reproduces the CLI's render from `spec.module` + `spec.values` through the same kernel (D9), and handoff (D7.4) is a structural no-op. The user is trusted to verify intent with `opm instance diff` / dry-run before applying; D7.4's digest abort is the automatic backstop that catches any capture gap (it only protects when `lastAppliedRenderDigest` is computed from `spec.values`, which this decision mandates).

**Forward-guard:** Today every CLI value input is a value file, and `unify(value files) → spec.values` is complete by construction — there is nothing outside `spec.values` that influences the render, so OQ10 closes with no residual precondition. If any *future* feature adds a render-affecting input that is **not** a value file — e.g. RFC-0005 environment wiring (not implemented, and may never be) — that input MUST fold into `spec.values` before it is written, or it reopens this decision. The trip-wire is specifically an input that `diff`/dry-run cannot catch because it resolves identically on both sides of the *user's own* diff (same environment) yet differently in the operator's context (no such environment). Value files are not such an input; an unresolved environment reference would be.

**Alternatives considered:**

- Track value-file provenance in the CR and have the operator re-expand the layering. Rejected: the operator does not have the CLI's files, config, or environment; re-expansion would diverge. Capturing the *resolved* unified set is the only self-contained option.
- Treat OQ10 as blocking research before `accepted`. Rejected: the read-side symmetry (same kernel, same CR fields) is structural and never the risk; the only real surface was a lossy *write*, and mandating `spec.values` as the CLI's own sole render input (apply + digest both from it) makes the lossy-write failure mode impossible rather than merely detectable.

**Rationale:** Both actors read the same CR fields through the same kernel, so a faithful, self-contained `spec.values` is sufficient for byte-identical renders by construction — there is no interpretation gap to close. Forcing the CLI to render its *own* apply from `spec.values` (rather than from a richer effective set it then partially serializes) collapses the entire faithfulness question to "is `spec.values` the thing I rendered from" — and the answer is yes by definition. The forward-guard records the exact condition under which a future feature would reopen the question, so the closure is honest today without building anything for a feature that may never land.

**Source:** User decision 2026-06-23. Resolves OQ10.

---

### D20: The umbrella ships as a single wave — no best-effort wave-1 handoff — resolves OQ5

**Decision:** 0006 ships as one wave, not a split of wave 1 (CR inventory + `spec.owner` + install + handoff against the CLI's current `pkg/render` pipeline) and wave 2 (kernel adoption, D9). Handoff is **not** shipped against the CLI's current pipeline; it lands only once the CLI renders through the `library` kernel (D9), so its render-digest parity check (D7.4) is structural from first ship, never best-effort. Slices may still be ordered internally (D15 rename → CR inventory/install → kernel adoption → handoff); "single wave" governs *not gating handoff behind a fake-parity intermediate*, not the internal slice order.

**Alternatives considered:**

- Two waves: land CR inventory + `spec.owner` + install + handoff (D1–D8) before 0001 completes, adopt the kernel (D9) in wave 2. Rejected: the split only paid off if D9 had to *wait* on 0001's `library` slice. It does not — `library` already landed and published v0.3.0 (the v0.17 recontract, `Materialize`, `SynthesizePlatform`), the operator rewrite onto that kernel is complete (2026-06-12), and 0001's own notes record that the CLI kernel adoption (this enhancement's D9) is the *sole remaining 0001 blocker*. The dependency that motivated splitting is already satisfied.
- Ship handoff in wave 1 anyway, accepting best-effort parity until wave 2. Rejected: that ships handoff's headline safety property (render-digest parity, D7.4) as best-effort against the `pkg/render` fork — exactly the unverified flip D7/D9 exist to eliminate — then immediately re-ships it for real once the kernel lands. Shipping the feature twice, the first time unsafe.

**Rationale:** The wave split only buys something if the kernel-adoption strand must wait on 0001; the kernel is published today, so it buys nothing. Shipping handoff against the current pipeline would make D7.4 best-effort — the CLI's `pkg/render` fork and the kernel can't be guaranteed byte-identical — which is the precise unsafe path the enhancement exists to replace. D9 + D13 are unblocked now, so the cheapest path to making D7.4 structural is also the only one worth shipping. Internal slice ordering is preserved; only the fake-parity intermediate is ruled out.

**Source:** User decision 2026-06-25.

---

### D21: Platform-source flag surface — single `--platform <file>` override + automatic precedence, with source-provenance reporting — resolves OQ14

**Decision:**

- A single `--platform <file>` flag is the highest-precedence, explicit *local* override, available on every non-`handoff` command (`apply`, `diff`, `render`, `build`). It supersedes today's `--provider` flag (renamed/subsumed under D14's no-compat license).
- When `apply`/`diff` target a cluster and no `--platform` is given, the CLI reads the cluster singleton `Platform` CR spec; if that read fails (RBAC denied) or the CR is absent, it falls back to the local/embedded default. The fallback **warns** — it never silently swaps platforms.
- Offline `build`/`render` never read the cluster: `--platform <file>` or the local/embedded default only.
- `handoff` forces the cluster `Platform` CR with no override; `--platform` is rejected there (D11).
- Every command that resolves a platform **reports which source it used** (`--platform <file>` / cluster `Platform` CR / local default) in its output, so the platform a release was rendered against is never ambiguous.
- No explicit `--platform-source` / `--use-cluster-platform` / `--local-platform` toggle is added now; a `--local-platform` escape hatch (force local even when the cluster CR is readable) is left as a future addition if a concrete preview need appears.

**Alternatives considered:**

- Explicit tri-state `--platform-source cluster|local|auto` alongside `--platform <file>`. Rejected: more surface and a second concept for one niche capability (force-local while the cluster Platform is readable); deferred to a possible later `--local-platform` without reopening the contract.
- No provenance reporting (warn only on fallback). Rejected: the genuine UX/safety risk is *silent source selection* — a user mis-believing which Platform they rendered against. The session's security analysis confirmed the override carries no privilege beyond the user's own RBAC, so provenance — not gating — is the right control.

**Rationale:** The override only affects client-side render applied under the user's own kubeconfig, so the blast radius equals the user's existing Kubernetes RBAC and there is no escalation on the apply path: the operator never consumes a local platform (D12) and handoff forces the cluster CR plus a digest check (D11/D7.4). Given that, Option A's single-flag precedence satisfies every locked constraint (handoff-forces-cluster, offline-never-cluster, non-admin-local-usable per D17) with one new flag that mirrors the CLI's existing flag>config>default resolution. The only real residual risk is a user being fooled about which source was used, which provenance reporting plus warn-on-fallback addresses directly. The asymmetric seeding path (a CLI-seeded solo Platform adopted later by the operator's privileged reconciler) is gated by cluster-scoped write RBAC and recorded as a risk (05-risks) rather than handled by the flag surface.

**Source:** User decision 2026-06-25.

---

### D22: Solo-cluster `Platform` write-if-absent uses a plain `Create` that tolerates `AlreadyExists`, not SSA apply — refines D12's mechanism, resolves OQ13

**Decision:** The CLI bootstraps the singleton `cluster` `Platform` in a solo cluster with a plain `Create` (POST), attributed via `CreateOptions.FieldManager = opm-cli`, and treats an `AlreadyExists` (HTTP 409) response as a **success-noop** — a Platform already exists, defer to it, write nothing. This refines D12, which said "write-if-absent via SSA manager `opm-cli`": for this specific write SSA *apply* is the wrong primitive because apply is create-*or-update* and would overwrite an existing Platform's `opm-cli`-owned fields, violating "never overwrite." The API server's atomic name-uniqueness check on `Create` is the synchronization primitive, so there is no real TOCTOU: in a create race against a concurrent operator install, one side wins and the other gets 409 and backs off without clobbering. On `AlreadyExists` the CLI does **not** read back or validate the existing Platform — write-if-absent means defer to whatever is present; validating an adopted Platform is the operator-install concern recorded in 05-risks, not the CLI's write. The operator adopting the Platform later via its own SSA apply still works (it takes field ownership on install — the intended adopt-on-install path).

**Alternatives considered:**

- SSA apply (PATCH, apply semantics) with manager `opm-cli`, as D12's wording implied. Rejected: apply is create-or-update with no create-only mode; against an existing Platform it would update the `opm-cli`-owned fields — the exact overwrite D12 forbids.
- GET-then-`Create`. Rejected: the GET is only an early-out; correctness still depends on `Create` rejecting a racing second create with 409, so it degrades into the plain-`Create`-tolerating-`AlreadyExists` design while adding a round-trip and a wider TOCTOU window.

**Rationale:** "Write-if-absent" needs a create-only primitive, and Kubernetes provides exactly one with the right atomicity: `Create`, whose server-side name-uniqueness check makes the absent-check and the write a single atomic operation. Tolerating `AlreadyExists` turns a lost create race into a clean back-off rather than a clobber. SSA's merge semantics are the right tool for the operator's *update/adopt* path but the wrong tool for the CLI's *bootstrap-if-absent* write; the field manager is still set on the `Create` so attribution and later operator adoption are unaffected.

**Source:** User decision 2026-06-25. Refines D12 (append-only — D12 stands; D22 pins the mechanism its wording left open).

---

### D23: Status-subresource RBAC — opt-in `--rbac` emission + a pre-flight access check, both as edge-case safety nets — resolves OQ3

**Decision:** Implement both halves of OQ3, framed as safety nets rather than critical-path machinery, because the common CLI-without-operator user is a cluster admin trying OPM out (for whom `moduleinstances/status` is already granted and neither feature ever triggers):

- **(a) Opt-in RBAC emission.** `opm install crds --rbac [--user U | --group G]` additionally creates a `ClusterRole` (e.g. `opm-cli-user`) granting `moduleinstances` (full verbs) + `moduleinstances/status` (get/patch/update) + `platforms` (get/list, for reading the cluster Platform per D11/D21), and binds it when `--user`/`--group` is supplied. **Off by default** — plain `opm install crds` stays RBAC-free; RBAC wiring is environment-specific and the install-time admin is often not the applying user, so emit-and-bind is opt-in.
- **(b) Pre-flight access check.** On the `owner: cli` apply path the CLI issues a `SelfSubjectAccessReview` for `patch moduleinstances/status` in the target namespace **before applying any resources**, and aborts on denial with an actionable error ("can apply ModuleInstance spec but not status; inventory cannot be recorded — grant `moduleinstances/status` or run `opm install crds --rbac`"). The `owner: operator` apply path (D18 — CLI writes only `spec`) skips the check entirely.

**Alternatives considered:**

- Implement (b) only, document required permissions, never emit RBAC. Rejected (user direction): cheap to also ship the opt-in `ClusterRole` as a convenience for the rare non-admin case; both together cost little.
- Make `--rbac` default-on. Rejected: the common solo user is already admin and needs no binding; default-emitting RBAC objects (especially a binding) into a cluster on a CRD install is a surprising cluster-wide write. Opt-in matches D5's "never implicitly do cluster-admin writes" posture.
- Skip the pre-flight and just let the status write fail. Rejected: applying resources first and 403-ing on the subsequent status write deploys resources with **no recorded inventory** → orphan. The check must precede any apply.

**Rationale:** Echoing the user's framing — "usually a user using the CLI and not the Operator is a cluster admin; in the try-OPM-out scenarios this won't be an issue." So status RBAC is an edge case, not a primary path, and the right treatment is lightweight safety nets that are invisible to the admin (the SSAR returns allowed instantly; `--rbac` is never typed) yet protect the namespace-scoped non-admin from the silent-orphan failure. The pre-flight is the load-bearing half — it converts a deploy-then-orphan into a clean pre-apply abort; `--rbac` is pure convenience.

**Source:** User decision 2026-06-25.

---

### D24: CRD/operator version skew — CLI-≥-cluster invariant, gate-only (CRD field-presence floor + operator-version ceiling via `Platform.status`) — resolves OQ4

**Decision:** The CLI must be equal to or newer than the operator and CRDs running in the cluster; it **refuses the unsafe direction** (CLI older than the cluster) rather than maintaining a compatibility window — consistent with D14, since refusing the unsafe skew is cheaper than promising multi-version support. Enforcement is gate-only: two bounded checks, no per-field schema adaptation.

- **Floor (CRD capability).** Before any `apply`, the CLI verifies the installed `ModuleInstance` CRD carries the fields it must write — `spec.owner` and `status.inventory`. Missing → refuse: "ModuleInstance CRD is missing required fields — run `opm install crds`." Expressed as field-presence rather than a version string: it is robust, and it *is* the safety floor — it prevents the API server silently pruning an unknown `spec.owner` and the operator then reconciling a CLI-owned release (the D3 hazard).
- **Ceiling (operator version).** The operator self-publishes its running version into `Platform.status.operatorVersion` on every reconcile (operator-side addition, within `affects: opm-operator`). The CLI reads it — zero extra round-trips, it already reads the Platform for render (D11) — and refuses if `operatorVersion` exceeds the CLI's own version: "your CLI is older than the cluster operator — upgrade the CLI." When `Platform.status.operatorVersion` is **absent**, there is no operator in the cluster (solo cluster, CLI-written Platform per D22) and the ceiling check is skipped. Every operator that ships this schema writes the field, so an operator-present-but-empty case does not occur and needs no fallback branch.

Full schema-driven validation (the CLI adapting field-by-field to the installed CRD schema) and making `core/` the single CRD-schema source are explicitly **out of scope** — a separate, larger enhancement. The CRDs today are hand-written Kubebuilder Go types in `opm-operator/api/v1alpha1`, a duality with `core/src/module_instance.cue` + `platform.cue` that consolidation would remove, but only at the cost of a generation pipeline from `core` CUE to both CRD YAML and the operator's Go types — a pipeline the operator's controller-runtime nature still requires; that work is tracked as a future enhancement, not here.

**Alternatives considered:**

- A formal multi-version compatibility window the CLI maintains across operator releases. Rejected: D14 owes no external consumer such a contract; "refuse the unsafe direction" is cheaper and sufficient for a single-user tool whose user controls both sides.
- Field-by-field schema adaptation (the CLI down-levels what it writes to match the installed CRD). Rejected for now as over-engineering: with additive-only schema evolution (`core/`) and a shared kernel (D9), the band where adaptation differs is narrow; gate + floor closes the one real hazard. Deferred to the same future enhancement that would make `core/` the CRD source.
- Operator version from a Deployment label or a dedicated ConfigMap/lease. Rejected: `Platform.status` is operator-owned, already reconciled, and already in the CLI's read path — the cheapest reliable home.
- Inferring the operator version from a CRD annotation `opm install` stamped. Rejected: the operator can be upgraded out-of-band (Flux/Helm) without `opm install` running, so the CRD stamp can be stale relative to the running operator; the operator must self-publish.

**Rationale:** The unsafe skew is CLI-older-than-cluster — a newer operator may expect semantics an older CLI does not write correctly — so refusing exactly that direction is the whole contract ("the CLI must be equal or higher to the operator running in the cluster and the CRDs installed"). Gate-only is the simplest mechanism that still prevents the `spec.owner` silent-prune break. The operator version lives in `Platform.status.operatorVersion` because the Platform is operator-owned, reconciled, and already read by the CLI; and because every operator shipping this schema writes the field, the CLI relies on its presence whenever an operator exists, with absence meaning "solo cluster, no operator check."

**Source:** User decision 2026-06-25.

---

### D25: The CLI writes no `status.conditions`; conditions are operator-exclusive — amends D2, resolves OQ11

**Decision:** The CLI's status write drops the `Ready` condition entirely. The CLI writes only `status.inventory`, `instanceUUID`, and the `lastApplied*` fields (`lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`) — **never** `status.conditions`. `status.conditions` becomes **operator-exclusive**: the operator writes `Ready: Unknown` / `ManagedExternally` on CLI-owned CRs (D3) and the real reconciled `Ready` on operator-owned CRs. In a solo cluster (no operator) `status.conditions` is simply absent; the CLI derives any "applied/ready" display for `instance status` / `list` from the presence of `status.inventory` + `lastAppliedAt` rather than from a persisted condition.

This **resolves OQ11** by removing the shared list: with no CLI-written condition there is no two-writer contention on the `Ready` element — neither in the handoff transition window nor in steady state — so the associative-list-merge / force-apply question is moot. It also **removes a latent contradiction** between D2 (the CLI writes a `Ready` condition) and D3 (the operator "never touches any CLI-written status field" yet "sets a single `Ready: Unknown` condition"): with the CLI writing no condition, D3's operator-written `Ready` is unambiguous, and "never touches CLI-written status fields" now refers cleanly to `inventory` / `lastApplied*` only.

**Alternatives considered:**

- D2 as written — the CLI writes a single `Ready: AppliedByCLI` condition. Rejected (user direction): a one-shot actor's `Ready` is a fiction the moment anything drifts (it records "last apply succeeded," not liveness), it duplicates a fact already recoverable from `status.inventory` + `lastAppliedAt`, and — in an operator-present cluster — it contends with the operator's `ManagedExternally` write on the same `Ready` element. Dropping it is consistent with D2's own rationale that the CLI should write only facts a one-shot actor can stand behind.
- Keep a CLI condition but on a CLI-specific type (not `Ready`) to avoid the collision. Rejected: still persists a control-loop-shaped fact the CLI cannot maintain, and leaves two condition entries for tools to reconcile; cleaner to make conditions wholly operator-territory.

**Rationale:** Echoing the user — "what if conditions were not written by the CLI at all; all we need from the CR for the CLI implementation is spec + status.inventory, maybe something else." The "something else" is the `lastApplied*` digest/timestamp set (needed by the CLI's own `diff` / `status` drift checks and the handoff D7.4 precondition) plus `instanceUUID`; none of it is a condition. Conditions encode reconciled control-loop state that only the operator can own, so making them operator-exclusive dissolves OQ11's race, fixes the D2/D3 inconsistency, and shrinks the CLI's status footprint to exactly the facts it can stand behind. The cost — a solo-cluster CR carries no `Ready` for `kubectl get` to display — is acceptable: the CLI's own commands read inventory/digests, and a derived readiness can be shown without persisting it, on the very path where the CLI is the intended interface.

**Source:** User decision 2026-06-25. Amends D2 (append-only — D2 stands; D25 removes the condition from its written subset) and resolves OQ11.

---

### D26: Prune-safety checks move into the shared `library` inventory package — resolves OQ6

**Decision:** The CLI-only prune-safety checks — component-rename detection and the pre-apply existence check — move into the shared `library` inventory package (D13), so both the CLI and the operator execute them. They are no longer CLI-local.

**Alternatives considered:**

- Keep them CLI-side only. Rejected: if a prune-safety check changes what is pruned or applied and only one actor runs it, the CLI and operator compute different prune/apply outcomes — the exact handoff prune-set parity break D13 exists to prevent.
- Duplicate them in both the CLI and the operator. Rejected: two implementations drift; D13 already homes the parity-critical inventory logic in one `library` package precisely to avoid that.

**Rationale:** Same parity argument as D13: anything that influences the prune set or apply plan must be computed by identical code on both sides or handoff's zero-stale-set guarantee is unsound. Moving the checks into `library` is a correctness requirement, not just consolidation. The cost — a wider operator slice and a change to operator prune behaviour that needs operator-side test coverage — is accepted.

**Source:** User decision 2026-06-25. Resolves OQ6 (RFC-0007 OQ-1); confirms the RFC's "yes" bias.

---

### D27: No `--install-crds` flag; missing CRDs fail with a hint to run `opm install crds` — resolves OQ7

**Decision:** No `--install-crds` convenience flag is added to `apply` (or any command). When the `ModuleInstance` CRD is absent, the CLI fails with a one-line actionable hint — `ModuleInstance CRD not found — run 'opm install crds'` (D5) — and does nothing else. Installing CRDs stays an explicit, separate, user-initiated step.

**Alternatives considered:**

- Add an opt-in `--install-crds` flag on `apply` that installs CRDs then applies. Rejected (user direction): even an explicit flag blends a cluster-admin CRD write into an app-apply invocation; keeping the two operations fully separate is clearer, and the failure hint already makes the remedy obvious in one step.
- Silent auto-install of CRDs inside `apply`. Already rejected by D5 (a cluster-admin write hidden inside an app apply).

**Rationale:** Installing CRDs is a distinct, privileged, one-time cluster-setup action; `apply` is a per-release operation. Keeping them separate — fail-with-hint rather than fold-in — keeps each command's blast radius legible and matches D5's stance that the CLI never does cluster-admin writes implicitly. The first-run friction is one extra command the hint names exactly.

**Source:** User decision 2026-06-25. Resolves OQ7 (RFC-0007 OQ-2); affirms and closes D5's left-open option.

---

### D28: Install commands are verb-first — `opm install operator` / `opm install crds` / `opm uninstall operator` — resolves OQ8

**Decision:** The install surface is verb-first: `opm install crds`, `opm install operator`, `opm uninstall operator` (D5). There is no `opm operator install` command group.

**Alternatives considered:**

- Noun-first `opm operator install` / `opm operator uninstall`. Rejected: it splits off a separate `operator` command group while D5 already established the `install`/`uninstall` verb groups (which also host `crds`); verb-first keeps one consistent surface.

**Rationale:** D5 already ships `opm install crds`; `opm install operator` is the consistent sibling. A single `install`/`uninstall` verb group reads consistently across both targets (`crds`, `operator`) and avoids a one-off noun-first group for the operator alone.

**Source:** User decision 2026-06-25. Resolves OQ8 (RFC-0007 OQ-3); confirms D5's implied taxonomy.

---

### D29: `instance list --all-namespaces` is a native cluster-wide CR list; clear error on insufficient RBAC; no label fallback — resolves OQ9

**Decision:** `opm instance list --all-namespaces` performs a native cluster-scoped `ModuleInstance` CR list (requiring cross-namespace list permission). On insufficient RBAC it fails with a clear, actionable error rather than degrading. There is no label-based fallback. Default `opm instance list` stays single-namespace (namespace-scoped list permission only).

**Alternatives considered:**

- Keep the Secret-era label-based listing as a fallback. Rejected: obsolete — D8/D14 remove the Secret inventory entirely, so there is nothing to fall back to; inventory now lives in the `ModuleInstance` CRs, and listing those CRs *is* the list.
- Silently scope `--all-namespaces` down to readable namespaces on partial RBAC. Rejected: a list that silently omits namespaces the user cannot read misrepresents cluster state; a clear permission error is honest.

**Rationale:** With inventory in CRs, `--all-namespaces` is just a cluster-wide CR list; cross-namespace list permission is the natural requirement (satisfied for the common admin user, a clean 403-with-hint for namespace-scoped users — matching the D23 preflight philosophy). Removing the label fallback drops dead Secret-era code.

**Source:** User decision 2026-06-25. Resolves OQ9 (RFC-0007 OQ-5).

---

### D30: The OQ1 render-digest parity experiment is deferred into the C2 kernel-adoption slice — closes the last `draft → accepted` gate

**Decision:** The render-digest parity experiment that OQ1 and `04-graduation.md` flag — CLI and operator producing equal render digests for the same release against the same `Platform` spec — is **not** run before `accepted`. It is deferred into the **C2 `cli-kernel-adoption`** slice and recorded as an `accepted → implemented` gate (an e2e/experiment requirement on C2), not a `draft → accepted` gate. The experiment, when it runs, MUST cover both a bare published-module reference and a release with **non-trivial layered values** (per D19/OQ10), and asserts byte-equal `lastAppliedRenderDigest` between a CLI render and an operator render of the same `ModuleInstance`.

**Alternatives considered:**

- Run the parity experiment now as a blocking `draft → accepted` gate. Rejected: there is no CLI kernel-render path to measure until C2 lands D9 — the CLI still carries its own `pkg/render` fork. A "parity experiment" today would measure the fork the design *deletes*, proving nothing about the shipped pipeline; it is only meaningful once the CLI renders through the `library` kernel.
- Drop the parity experiment entirely. Rejected: render-digest parity is the load-bearing safety property of handoff (D7.4) — equal digests are what make the operator's first post-handoff apply a structural no-op. It must be empirically validated, just at the point where it becomes measurable (inside/after C2), not abandoned.

**Rationale:** D20 already commits the umbrella to a single wave in which handoff ships only once the CLI renders through the kernel, so the parity property is structural by construction; the experiment is the empirical confirmation of that property and naturally belongs in the slice that creates the path it measures. `04-graduation.md` explicitly permits deferring OQ1's experiment into the kernel-adoption wave with a recorded reason — this is that reason. With this, every `draft → accepted` gate item is satisfied.

**Source:** User decision 2026-06-30.

---

### D31: Revert the shared `library/opm/inventory` package — the CLI and operator keep independent local inventory implementations — supersedes D13's shared-logic clause and D26

**Decision:** `library/opm/inventory` (shipped as slice A3, `library/2026-06-30-library-inventory-pkg`) is reverted. Neither the CLI nor the operator imports a shared inventory package for entry-building, identity comparison, stale-set computation, digest computation, component-rename safety, or pre-apply/collision checking. Each actor keeps — for the CLI, keeps as it already exists today — an independently maintained local implementation of these functions. The only thing that must be identical across actors is the `InventoryEntry` *wire shape* persisted to `status.inventory.entries[]` on the `ModuleInstance` CR, and that is already anchored by the CRD's OpenAPI schema (`opm-operator/api/v1alpha1.InventoryEntry`), not by a shared Go package.

This reverses D13's first clause ("the shared pure inventory logic... homes in `library`... consumed by both the CLI and the operator") and D26 in full ("prune-safety checks move into the shared `library` inventory package... so both the CLI and the operator execute them"). D13's other clauses stand: the CLI still does not import `opm-operator` (still avoids the controller-runtime/Flux drag), the CR is still represented as `unstructured` (or a CLI-local type) rather than the operator's typed API, and the CLI's apply/prune is still a ported one-shot design, not an imported controller-runtime loop.

**Alternatives considered:**

- Keep the full library package as originally scoped (D13/D26). Rejected: tracing which functions are actually compared or relied upon across the actor boundary shows only the entry shape qualifies. `ComputeStaleSet` is never compared cross-actor — D7.4's render-digest gate already guarantees `previous ≈ current` at the one moment a stale-set computation crosses actors (the operator's first post-handoff reconcile reading CLI-written entries), making the base-relation choice moot at exactly that instant. `ComputeDigest` has no cross-actor consumer at all — D2/D25 never has the CLI write a `lastAppliedInventoryDigest` the operator's `IsNoOp` fast-path reads, so the operator's first post-handoff reconcile always takes the real render+stale-set path regardless of digest-algorithm agreement. `ApplyComponentRenameSafetyCheck` is only meaningful paired with a specific stale-set base relation, not independently shareable. `CollidesOnApply`/`PreApplyExistenceCheck` decide only what *this* actor does before *its own* apply, never compared against the other actor's verdict for the same identity.
- Shrink the shared package to just `InventoryEntry` + `NewEntryFromResource`. Rejected: even this narrower surface doesn't earn a cross-repo dependency. The operator still needs its own CRD-serialization type regardless (Kubebuilder-generated, can't be replaced by a plain library type — the same reasoning D13 already used to keep the CLI off `opm-operator/api/v1alpha1`); the CLI still needs its own local type per D13.2. A shared library type adds a third representation everything maps through rather than collapsing the two that actually matter. And the one thing `NewEntryFromResource` depends on for correctness — that both actors observe the same rendered object (GVK, namespace, name, the `component.opmodel.dev/name` label) — is already guaranteed by kernel-render-parity (D9), not by sharing the extraction code; the extraction itself has no decision logic to drift, only a mechanical field copy off an input that can't disagree.
- Keep the library package in place but unimported, as reference-only documentation. Rejected: a package presented as kernel contract (its own `doc.go`: "a contract every OPM frontend MUST compute identically") that nothing actually imports is actively misleading to future readers, and the real drift risk this enhancement needs to manage — behavioral differences like the stale-set base relation — is now a documented Open Question (OQ15) rather than something a reference package would have caught anyway, since it was never cross-compared in the first place.

**Rationale:** The original premise (D4, carried into D13/D26) was that identical entry-identity/digest/stale-set computation across the CLI and operator is a correctness precondition for safe handoff. Tracing the actual data flow shows that's true only for the *entry shape* — what gets written into and read back out of `status.inventory.entries[]` — because that's the one artifact that literally crosses the actor boundary unmediated. Everything downstream of that (how a given actor decides what's stale, what to prune, what collides) is computed by exactly one actor at a time, for its own upcoming action, and the moment that *would* create a cross-actor dependency (the operator's first post-handoff stale-set computation, reading CLI-written entries) is already independently gated by D7.4's render-digest check, which guarantees the sets being compared are equal before the comparison algorithm's own choices could matter. A shared package built to prevent a drift risk that turns out not to exist at the point of contact isn't earning the coordination cost it imposes — a `go.mod` edge, alpha-tag version pinning, a release cycle blocking downstream slices, exactly the friction already observed blocking B1 on `library v1.0.0-alpha.4`.

Discovered while tracing this: the CLI's existing `pkg/inventory.ComputeStaleSet` and the operator's existing `internal/inventory.ComputeStaleSet` already use different base relations (`IdentityEqual`, component-aware, vs. `K8sIdentityEqual`, component-agnostic) — evidence the "near-identical code" framing in `01-problem.md` understated how far the two copies had already diverged before this enhancement began. That divergence sits squarely in the "local policy, never cross-actor-compared" tier established above, so it is not itself unsafe — but it is a real behavioral inconsistency a user could observe depending on which tool they use, and is recorded as OQ15 rather than resolved here.

Also discovered: the operator's apply path (`internal/apply/apply.go`, via Flux's `ResourceManager.ApplyAllStaged`) always applies with SSA field-ownership force, matching the CLI's own `internal/kubernetes/apply.go` (`Force: true`, unconditional) in that respect — but unlike the CLI, the operator has no equivalent of the CLI's `PreApplyExistenceCheck` guarding against silently force-claiming a foreign or terminating object. That gap is real and independent of whether the check's *code* is shared: first-principles analysis (force-ownership is unconditional on both apply paths; the operator's delete-time ownership guard in `Prune` cannot backstop an apply-time mislabel, because a successful colliding apply relabels the foreign object as `opm-controller`-managed before any delete-time check would ever run) argues the operator needs *some* form of this protection regardless of the code-sharing question. It is recorded as OQ16 and as a new risk entry in `05-risks.md`; the shape of the protection (reuse the CLI's decision table informally, or design independently) is left open.

**Source:** User decision 2026-07-01, arising from an explore-mode design session investigating slice B1 (`operator-adopt-library-inventory`). Supersedes D13's shared-logic clause and D26 in full; D13's remaining clauses (no `opm-operator` import, CR as `unstructured`, ported one-shot apply/prune) stand.

---

### D32: Noun-first `opm operator` command group — `opm operator install [--crds-only]` / `opm operator uninstall` — supersedes D28

**Decision:** The install surface moves to a noun-first `operator` command group. `opm operator install` applies the full embedded `dist/install.yaml`; `opm operator install --crds-only` applies only the `CustomResourceDefinition` documents filtered from that same artifact (the CLI-solo path); `opm operator uninstall` removes what install applied, except CRDs (D5) and the `Namespace` (D34). The `opm install` / `opm uninstall` verb groups from D5/D28 are not created. Command-name spellings elsewhere update accordingly — in particular D27's missing-CRD hint becomes `ModuleInstance CRD not found — run 'opm operator install --crds-only'`. Every other D5 clause stands unchanged: SSA installs with field manager `opm-cli`, build-time embed with `--version` fetch fallback, uninstall never deletes CRDs, no silent auto-install inside `apply`. D23's opt-in RBAC emission moves with the command: `opm operator install --crds-only --rbac [--user U | --group G]`.

**Alternatives considered:**

- Keep D28's verb-first surface (`opm install crds`, `opm install operator`, `opm uninstall operator`). Rejected (user direction): the operator lifecycle is one coherent noun; a dedicated `opm operator` group keeps the root command list flatter and gives future operator-lifecycle surface (upgrade, status) a home, instead of spreading one concern across two verb groups.
- `opm operator install crds` as a child command of `install`. Rejected: `install` would need to be both a runnable command (full install) and a parent with a `crds` child — workable in cobra but an unusual shape; a flag on one command mirrors the underlying reality that the CRDs are a filtered subset of the single artifact (D35), not a second artifact.
- Mixed taxonomy — only the operator lifecycle moves noun-first, `opm install crds` stays verb-first for CLI-solo users. Rejected: two taxonomies for one artifact is the worst of both; the `--crds-only` spelling serves the solo user without a second command group.

**Rationale:** D28's own rationale was consistency with a D5 `install` group that "already hosts `crds`" — but with D35 establishing that the CRDs *are* the install artifact filtered, there is no independent `crds` target to host, and the consistency argument inverts: one noun-first group with a subset flag is the surface that matches the packaging. This supersession reverses a 2026-06-25 user decision by a 2026-07-02 user decision; the log keeps both.

**Source:** User decision 2026-07-02 (explore-mode session on slice B2; `--crds-only` flag form chosen over subcommand and mixed forms). Supersedes D28 and OQ8's resolution; amends the command spellings in D5, D23, and D27.

---

### D33: Slice B2 ships install/uninstall only — the missing-CRD apply gate moves to C1; the CLI-wide field manager constant becomes `opm-cli` in B2

**Decision:** B2 delivers the `opm operator install/uninstall` commands (D32, D34, D35) and touches nothing on the apply path. The missing-CRD fail-with-hint (D5/D27) and D24's version-skew gates (CRD field-presence floor, operator-version ceiling) land in C1, where the apply path actually begins reading and writing the `ModuleInstance` CR. B2 does, however, rename the CLI's existing SSA field manager constant from `opm` (`cli/internal/kubernetes/labels.go`) to `opm-cli`, so the install writes it introduces and everything the CLI applies thereafter share the one manager identity D10 and the design already assume.

**Alternatives considered:**

- Ship the missing-CRD apply gate in B2, as planned-changes originally described ("makes the CRD a hard prerequisite for every CLI apply"). Rejected: pre-C1 the apply path is Secret-backed and never touches `ModuleInstance`; gating it on a CRD it doesn't read is a check with no referent, and would block working applies for nothing. The CRD becomes a hard prerequisite exactly when C1 makes the CR the inventory backend.
- Defer the `opm` → `opm-cli` manager rename to C1's apply-path rewrite. Rejected: B2 is the first slice that writes with `opm-cli`; introducing a second manager alongside the old `opm` constant — even temporarily — creates exactly the accidental-looking coexistence the rename removes. The rename is mechanical, and with no external CLI users the manager-identity change on already-applied resources is a non-event (the apply path already forces ownership).

**Rationale:** Each check lands with the code that gives it meaning; each slice stays mechanically verifiable on its own. B2's blast radius is two new commands plus a constant rename — nothing existing changes behavior.

**Source:** User decision 2026-07-02 (explore-mode session on slice B2). Amends slice B2's and C1's scope in `planned-changes.md`; the manager naming itself was already fixed by D10/D5 — this decision only places the rename.

---

### D34: `opm operator uninstall` preserves the namespace; refuses while cleanup finalizers are armed, with `--remove-finalizers` as the override

**Decision:** `opm operator uninstall` deletes the operator's workload and RBAC objects from the embedded manifest set but never deletes CRDs (D5) and never deletes the `Namespace`. Before deleting anything, it lists `ModuleInstance` CRs cluster-wide; if any carry the operator's `opmodel.dev/cleanup` finalizer (i.e. operator-owned, reconciled instances), it warns — naming each instance — and refuses. Passing `--remove-finalizers` overrides: the CLI strips the operator's `opmodel.dev/cleanup` finalizer (that finalizer only — foreign finalizers belong to other live controllers and are untouched) from every `ModuleInstance`, then proceeds with the uninstall. The consequence is stated in the warning: with the finalizer gone and no controller running, those instances and their rendered resources are deliberately orphaned — deleting such a CR later removes only the CR, never its workloads.

**Alternatives considered:**

- Delete the namespace as part of uninstall. Rejected: namespace deletion cascades to everything inside it, including anything user-added; it also re-arms the finalizer hazard from the other side (namespace termination waits on the instances' finalizers with no controller left to satisfy them). A leftover empty namespace is cheap; a wedged terminating namespace is not.
- Warn but proceed by default (no refusal). Rejected: the failure this guards against — every later `kubectl delete moduleinstance` hanging indefinitely on an unsatisfiable finalizer — surfaces long after the uninstall, when the cause is hardest to see. Refuse-by-default puts the decision at the moment it is being made.
- Name the flag `--force`. Rejected: `--remove-finalizers` names the destructive action actually taken; `--force` hides it.
- Strip all finalizers rather than only `opmodel.dev/cleanup`. Rejected: foreign finalizers are other controllers' liveness contracts; those controllers are still running and will satisfy them.

**Rationale:** Uninstalling the controller while its finalizers stay armed converts a routine future delete into an indefinite hang — the classic operator-uninstall footgun. The refusal makes the hazard visible exactly once, at uninstall time, with the remedy (handoff/delete instances first, or `--remove-finalizers` and accept orphaning) in hand.

**Source:** User decision 2026-07-02 (explore-mode session on slice B2; default warn-and-refuse with a finalizer-removal flag chosen by the user, flag name and single-finalizer scope proposed by the session). New behavior — extends D5's uninstall clause.

---

### D35: One embedded artifact — `dist/install.yaml`, CRDs as a filtered subset; pinned version with a refresh task; `--version` fetches the GitHub release asset; install waits for completion

**Decision:** The CLI embeds exactly one operator artifact: `dist/install.yaml` from a pinned opm-operator release (`go:embed`). All three surfaces derive from it — `install` applies all documents, `install --crds-only` applies the `CustomResourceDefinition` documents, `uninstall` deletes all documents except CRDs and the Namespace (D34). The pinned version is recorded in one place in `cli/` (a constant alongside the embed), refreshed by a cli Taskfile task (shape: `task operator:sync VERSION=vX.Y.Z`) that downloads the release asset and rewrites the pin. `--version <tag>` fetches `install.yaml` from the corresponding opm-operator GitHub release (the asset `release.yml` already uploads) over HTTPS; no further checksum/signature verification is added at this stage — TLS-to-GitHub integrity is accepted while the project is alpha. `opm operator install` waits, bounded, for completion: CRDs reach `Established`, and the operator `Deployment` completes its rollout; `--crds-only` waits for `Established` only. The readiness check is built to be reusable — C3's "operator installed and ready" handoff precondition (D7.1) consumes the same machinery.

**Alternatives considered:**

- Separately embed `config/crd/bases/*.yaml` for the CRDs-only path (D5's original framing implied both artifacts). Rejected: two embedded copies of the same CRDs can drift; `install.yaml` already contains them, and the operator's release pipeline publishes only `install.yaml` — so the fetch fallback would have no CRD-only asset to fetch anyway.
- Verify fetched artifacts against a checksum/signature. Deferred, not rejected: worth revisiting when releases stabilize; at alpha, HTTPS to GitHub releases is the accepted integrity boundary (user decision).
- Fire-and-forget install (no readiness wait). Rejected (user direction): "installed" should mean "running"; and the handoff precondition needs the ready-check machinery regardless, so building it here is paid for twice.

**Rationale:** One artifact, one pin, one refresh task keeps the operator-version story auditable in a single diff line; deriving the CRD subset by filtering makes drift between "what `install crds` gives you" and "what the operator ships" structurally impossible. The GitHub release asset was verified present (`opm-operator/.github/workflows/release.yml` uploads `dist/install.yaml`), and v1.0.0-alpha.2 — which already contains both A1's dependency line and A4's `spec.owner` CRD — is the natural first pin.

**Source:** User decision 2026-07-02 (explore-mode session on slice B2: single-artifact embed accepted, install-waits-for-completion chosen, checksum verification deferred). Refines D5's embed clause.

---

### D36: The CLI's CUE bump retargets to v0.17.1 and relocates from C2 to C1; library/operator pin bumps happen outside 0006 — amends D14's clause (1)

**Decision:** Slice C1 bumps the CLI's `cuelang.org/go` from v0.16.1 directly to **v0.17.1** (released 2026-07-16) — not to v0.17.0-alpha.1 as D14 named, and not deferred to the C2 kernel-adoption slice as D14 placed it. The `library`/`opm-operator` upgrades off their v0.17.0-alpha.1 pins are handled **separately, outside 0006's slices** (user-owned). One sequencing constraint is recorded as a hard precondition: both `library` and `opm-operator` MUST be on the same CUE line as the CLI **before C2's render-digest parity experiment runs (the D30 gate) and before C3 handoff ships** — a shared kernel (D9) does not neutralize evaluator-version skew; the same kernel code under different `cuelang.org/go` versions can legitimately produce different rendered bytes, which would hollow out D7.4's digest gate.

**Evidence (2026-07-16):** a scratch-modfile trial built the CLI against v0.17.1 with **zero code changes** and the full unit suite (`./pkg/...` + `./internal/...`) green — the v0.16→v0.17 Go-API migration D14 budgeted into kernel adoption does not exist for the CLI's current usage. Same-day workspace measurement: `library` and `opm-operator` full suites are byte-identical to their alpha.1 baselines under v0.17.1 with the catalog_opm hoisted-guard workaround retained. Caution note: v0.17.1 fixes upstream cue-lang/cue#4423 *as filed* but does **not** fix OPM's own closedness manifestation — the hoisted-guard workaround in catalog_opm remains load-bearing on every tool ≥ v0.17.0 and must not be reverted; the upgrade is safe *because* that workaround already removed the trigger pattern from the catalog.

**Alternatives considered:**

- Keep the bump inside C2 per D14 ("migrated to v0.17 as part of the kernel-adoption work"). Rejected: the migration cost D14 coupled to kernel adoption is measured to be zero, so the coupling buys nothing; bumping in C1 shrinks C2 to pure kernel adoption and gives the CLI local-module.cue-capable tooling (D37) one slice earlier.
- Target official v0.17.0. Rejected: v0.17.1 fixes several v0.17.0 evaluator regressions (panics, hangs, spurious `field not allowed` / `structural cycle` errors involving comprehensions) and makes module replacements MVS-participating — the latter directly relevant to D37.
- Add a 0006 slice for the `library`/`opm-operator` pin bumps. Rejected (user decision): owned separately; 0006's remaining slices stay CLI-scoped, and the constraint above records the only cross-repo ordering fact 0006 needs.

**Rationale:** The bump is verified-cheap now and prerequisite-free (the CLI has no `library` edge yet, so no MVS forcing applies — this is a proactive bump, not a forced one). Landing it in C1 means kernel adoption (C2) starts from a CLI already on the final CUE line, and the local-module workflow (D37) becomes available to the inventory-backend slice's own development and testing. When C2 later adds the `library` import, MVS resolves to v0.17.1 regardless of whether `library`'s own pin has moved yet.

**Source:** User decision 2026-07-16 (explore-mode session planning C1). Trial evidence: scratch-modfile build + unit suite, 2026-07-16. Amends D14's clause (1) — target version and slice placement; D14's no-compat stance and its clause (2) (Secret migration, no deprecation window) stand unchanged.

---

### D37: `cue.mod/local-module.cue` is the sanctioned local-module workflow; `spec.module` always carries the canonical declared reference — the CR never represents a local path

**Decision:** With the CLI on CUE ≥ v0.17 (D36), CUE's local module file — `cue.mod/local-module.cue`, holding `deps: "<path>@vN": replaceWith: "<local dir | fork@version>"` — is the sanctioned way to develop and apply against unpublished or locally-edited modules: instance packages keep their canonical registry imports, and the replacement lives in a file that is **never published and honored only in the main module**, so local-ness structurally cannot leak into a published artifact or into the CR. Consequently the `ModuleInstance` CR never represents a filesystem path in any mode: (a) a module-dir-as-main-module apply (D6's local case) writes the module's **declared** `spec.module` path/version — always present, since `#Module.metadata` requires both, so the CRD's `MinLength=1` constraints hold for every local apply; (b) a locally-replaced-dependency apply writes the canonical import verbatim and is indistinguishable in the CR from a registry apply. Handoff safety is unchanged and marker-free: D7.3 (resolvable reference) and D7.4 (digest re-render from the *published* reference) structurally abort on a diverged local checkout. D6's `module-instance.opmodel.dev/source: local` annotation is **demoted from fixed behavior to OQ17** (generalized to "rendered bytes did not come from a registry-resolved artifact", covering both modes); if kept it is observability-only and MUST never be a gate input, since annotations are user-editable. Operational notes: consuming `cue.mod/module.cue` files declare `language.version: "v0.17.0"` **exactly** (it is a consumer floor; declaring v0.17.1 would gratuitously lock out v0.17.0-line tools for zero gain), and C1's bump work verifies (i) the CLI loader resolves modules through the SDK's standard module resolution so `replaceWith` is honored rather than bypassed by the CLI's own OCI wiring, and (ii) a fully-replaced, never-published module path needs no registry existence (the docs' omit-`v`-for-replace-only-deps wording implies yes; one 5-minute check).

**Alternatives considered:**

- Represent local provenance structurally in `spec.module` (a path field or URI scheme). Rejected: a filesystem path is not module *identity*, leaks dev-machine detail into cluster state, and `spec.module` is a registry reference by CRD design.
- Require publishing before any apply. Already rejected by D6 — local-first is a primary learner workflow; local-module.cue makes it cleaner, not conditional.
- Keep D6's annotation as fixed mandatory behavior. Demoted rather than rejected: the safety argument never rested on it, and with `replaceWith` the canonical-reference story covers the main workflow; keep-vs-drop is a pure observability tradeoff, so it moves to OQ17 instead of being silently re-decided here.

**Rationale:** The feature (landed v0.17.0-alpha.3; `replace` → `replaceWith` in rc.1; replacement-MVS in v0.17.1) is exactly the missing dev-time indirection: "which bytes satisfy this import" is a resolution-time concern, and CUE now confines it to a file that cannot travel. This retires the localhost-registry publish-mirror loop previously required to test unpublished module edits against real instance definitions (e.g. `releases/<env>/<module>/`), and — as a bonus — `replaceWith` onto a local directory bypasses the CUE module cache, side-stepping its registry-blind staleness trap. The CR keeps a single, truthful semantics: `spec.module` states *identity* (what this is an instance of); provenance (where the bytes came from this time) is at most an advisory annotation (OQ17), and correctness never depends on it because handoff re-derives everything from the published reference.

**Source:** User decision 2026-07-16 (explore-mode session planning C1). Feature verified against https://cuelang.org/docs/reference/modules/#local-module-file and the cue-lang/cue v0.17.x release notes. Refines D6 (write-side semantics unchanged; annotation clause demoted to OQ17). Depends on D36.

---

### D38: The provenance annotation is kept and promoted to a fail-closed handoff pre-gate; the handoff verification render MUST bypass local replacements — resolves OQ17

**Decision:** Two coupled halves, discovered by tracing what happens when a `local-module.cue`-replaced apply is followed by `handoff`:

- **The real hole is in D7.4's verification render, and its fix is C3's.** If the handoff verification render resolves through the same `cue.mod/local-module.cue` that the apply used, it reproduces the same local bytes, the digest check passes self-consistently, and the operator — resolving from the registry — then renders something else. Therefore C3's handoff verification render MUST bypass local replacements entirely: ignore `local-module.cue` and resolve `spec.module` strictly from the registry (with cache handling that cannot serve a stale copy — the CUE module cache is registry-blind). This, not the annotation, is the authoritative guarantee.
- **The annotation (OQ17) is kept, C1 writes it, C3 reads it as a fail-closed pre-gate.** C1 stamps `module-instance.opmodel.dev/source: local` whenever the rendered bytes did not come from pure registry resolution (main module is a local directory, or any local-path `replaceWith` in the main module's `local-module.cue` — conservative: replaced dependencies also change bytes); a fully-registry-resolved apply omits it and SSA field ownership removes it. C3's handoff refuses while it is present, with the remedy in the error ("publish and re-apply, then hand off"). The layering is safe in both directions: the annotation only ever *blocks* — hand-stripping it grants nothing, because the strict-registry digest gate stands behind it — and a local checkout byte-identical to the published module clears naturally via the prescribed re-apply.

**Alternatives considered:**

- Annotation-only gate (no strict-registry verification render). Rejected: annotations are user-editable and the detection could miss a mode; an authority that can be stripped is not a safety mechanism. The digest gate must be independently sound.
- Digest-gate-only (drop the annotation, the direction the OQ17 "drop" option pointed). Rejected (user decision): the failure would then surface only as a digest mismatch at handoff time, without the CR ever recording *why*; the annotation converts a confusing late abort into an early, legible refusal with the remedy named, and costs one SSA-managed annotation.
- Have the annotation trigger stricter verification rather than refusal. Rejected: the strict verification must run unconditionally anyway (the annotation can be absent on a stale-cache or stripped-marker path), so conditioning strictness on it buys nothing over refuse-and-remedy.

**Rationale:** The user's framing — "we need the CLI to register that it was built using a local release, so a handoff gate will prevent disaster" — is exactly right, with the addition that the register-and-refuse layer is necessary but not sufficient: without the bypass-local verification render, D7.4 would validate local bytes against local bytes and bless the disaster it exists to prevent. With both halves, provenance is legible (CR self-documents local origin), the refusal is early and actionable, and the safety floor is structural.

**Source:** User decision 2026-07-16 (C1 fast-forward drafting session, `cli/openspec/changes/cli-cr-inventory-backend/design.md` D7). Resolves OQ17; refines D7.4 (verification-render resolution requirement, C3 scope) and D37 (annotation semantics finalized).

---

## Open Questions

- **OQ1: Where does the CLI get its `MaterializedPlatform`?** Status: resolved-by-D11, resolved-by-D12. The CLI uses a source precedence (flag > cluster `Platform` CR > local/embedded default), reads the Platform *spec* and materializes it itself via the same kernel calls the operator uses, and forces the cluster CR for `handoff` (D11). The `Platform` carries no owner marker — the operator always owns/materializes the singleton; in solo clusters the CLI writes an un-owned `cluster` Platform (write-if-absent) which the operator adopts on install (D12). The render-digest parity experiment this OQ recommended (CLI and operator producing equal render digests for the same release against the same Platform spec) is **deferred into the C2 kernel-adoption slice** (D30) — it is only measurable once the CLI renders through the `library` kernel (D9), and is recorded as an `accepted → implemented` gate on C2, not a `draft → accepted` gate.
- **OQ2: Dependency topology with the `cli → library` + `cli → opm-operator` diamond.** Status: resolved-by-D13. The diamond is collapsed: the CLI imports `library` only (not `opm-operator`), avoiding controller-runtime + Flux; the shared pure inventory logic homes in `library` and the CLI handles the CR as `unstructured`. `library` is added to `affects`. The go.mod build spike (does the CLI's v0.16 CUE code compile under v0.17-alpha; does everything resolve) is still worth running before the kernel-adoption slice — see `research/findings.md` "What the spike must prove" — but the topology decision no longer waits on it.
- **OQ3: Status-subresource RBAC for a user-credential actor.** Status: resolved-by-D23. Both halves implemented as edge-case safety nets (the common CLI-without-operator user is a cluster admin, for whom neither triggers): opt-in `opm install crds --rbac [--user|--group]` emits a `ClusterRole` granting `moduleinstances` + `moduleinstances/status` + `platforms` (off by default), and the `owner: cli` apply path pre-flights a `SelfSubjectAccessReview` for `moduleinstances/status` before applying any resources, aborting cleanly on denial (the `owner: operator` path skips it — D18 writes only spec). Original analysis: The operator writes `status` as a controller with a service account; the CLI writes it with the user's kubeconfig, which needs explicit `moduleinstances/status` permission. Does `opm install crds` emit an optional CLI-user Role/RoleBinding? Does apply degrade gracefully (clear error) when the user can patch `spec` but not `status`? RFC-0007 flagged RBAC as low-risk but did not pin the contract.
- **OQ4: CRD version-skew compatibility contract.** Status: resolved-by-D24. CLI-≥-cluster invariant — the CLI refuses the unsafe direction (CLI older than the operator/CRDs) rather than maintaining a compat window (D14-consistent). Gate-only: a CRD field-presence floor (`apply` refuses if the installed CRD lacks `spec.owner`/`status.inventory` → "run `opm install crds`") plus an operator-version ceiling (operator self-publishes to `Platform.status.operatorVersion`; CLI refuses if it exceeds the CLI version; absent = solo cluster, check skipped). Full schema-driven adaptation and core-as-CRD-source are out of scope (future enhancement). Original analysis: The CLI embeds operator-vX CRDs (D5); the cluster may run operator-vY. `spec.owner` and the status subset must be forward/backward compatible across the skew the `--version` flag allows. What is the supported window, and does `opm install crds` warn or refuse on mismatch?
- **OQ5: Does the umbrella ship as two waves?** Status: resolved-by-D20. Single wave — no split. The wave split's only payoff was letting the inventory/handoff strand land before 0001's `library` slice; but that slice already landed and published v0.3.0 and the CLI kernel adoption (D9) is 0001's *sole remaining blocker*, so the dependency is already satisfied and the split buys nothing. Handoff is held until the CLI renders through the kernel (D9) so D7.4 parity is structural from first ship, never the best-effort wave-1 form. Internal slice ordering (rename → inventory/install → kernel adoption → handoff) is preserved. Original analysis: The kernel-adoption strand (D9) is gated on 0001's `library` slice; the inventory/CR/handoff strand (D1–D8) is not. Splitting into wave 1 (CR inventory + `spec.owner` + install + handoff against the CLI's *current* pipeline) and wave 2 (kernel adoption) lets inventory/handoff land before 0001 completes — but wave-1 handoff digest parity would be best-effort until wave 2 makes it structural (D7 vs D9). Decide whether to ship handoff in wave 1 at all, or hold it for wave 2.
- **OQ6: Does the shared `pkg/inventory` absorb the CLI-only prune-safety checks?** Status: resolved-by-D26. Yes — component-rename detection and the pre-apply existence check move into the shared `library` inventory package so the CLI and operator run identical prune-safety logic (parity, per D13); the wider operator slice is accepted. (RFC-0007 OQ-1). Component-rename detection and the pre-apply existence check exist only CLI-side today. Moving them into the shared package makes them operator behaviour too (a benefit) but widens the operator slice. Bias: yes.
- **OQ7: `--install-crds` convenience flag on `apply`?** Status: resolved-by-D27. No — no `--install-crds` flag; a missing CRD fails with a one-line hint to run `opm install crds` (D5), keeping the privileged CRD install a separate explicit step. (RFC-0007 OQ-2). D5 decides against silent auto-install; an explicit opt-in flag could still collapse first-run friction.
- **OQ8: `opm install operator` vs `opm operator install`.** Status: resolved-by-D28; **D28 superseded by D32** — the surface is now noun-first `opm operator install [--crds-only]` / `opm operator uninstall`; no `install`/`uninstall` verb groups. Original D28 resolution: verb-first `opm install operator` (with `opm install crds` / `opm uninstall operator`); no separate `operator` command group. (RFC-0007 OQ-3). Pure CLI-surface taxonomy; decide in the install slice.
- **OQ9: `instance list --all-namespaces` over CRs.** Status: resolved-by-D29. Native cluster-wide `ModuleInstance` CR list; clear RBAC error on insufficient cross-namespace list permission; no label-based fallback (Secret inventory is gone — D8/D14). Default `instance list` stays single-namespace. (RFC-0007 OQ-5). Listing CRs cluster-wide needs list permission on `moduleinstances` across namespaces. Acceptable, or keep a label-based fallback?
- **OQ10: Is `spec.values` captured faithfully enough for handoff render parity?** Status: resolved-by-D19. The CLI unifies all value inputs into a single `spec.values` blob and renders its own apply (and computes `lastAppliedRenderDigest`) from that blob, making it the sole authoritative render input both actors consume; the read-side symmetry was never the risk, and rendering the CLI's own apply from `spec.values` makes a lossy capture structurally impossible rather than merely detectable. Trusted via `diff`/dry-run with D7.4's digest abort as the automatic backstop. No residual precondition today (all value inputs are value files); D19's forward-guard records the exact condition under which a future non-value-file render input (e.g. RFC-0005 env wiring) would reopen it. The OQ1 parity experiment (04-graduation) should still include a release with non-trivial layered values. Original analysis retained below. D7.4 recomputes the render digest from `spec.module` **plus the CR's values**, so the operator reproduces the render from `spec.module` + `spec.values`. But the CLI today has richer value inputs than a single blob — config layering, env wiring (RFC-0005), multiple `--values` files. If the CLI's *effective* values do not collapse losslessly into `spec.values`, the operator renders something different and the zero-downtime no-op silently fails. D6 pins `spec.module` capture but says nothing about value capture. This is load-bearing for the whole zero-downtime claim and deserves its own investigation (how the CLI flattens its value sources, whether anything is irreducibly CLI-local, and whether the handoff digest check is sufficient to catch a lossy flatten). The OQ1 parity experiment (04-graduation) MUST include a release with non-trivial layered values, not just a bare module reference. Bias: capture the fully-resolved value set into `spec.values` and treat anything that cannot round-trip as a handoff-blocking precondition.
- **OQ11: Who owns `status.conditions` during the handoff transition window?** Status: resolved-by-D25. Dissolved rather than arbitrated: the CLI writes no `status.conditions` at all (D25 amends D2's subset), so conditions are operator-exclusive and there is no shared `Ready` element to contend on — in the handoff window or in steady state. This also removed the latent D2/D3 contradiction (both actors writing `Ready` on a CLI-owned CR). Original analysis: `status.conditions` is a shared list written under SSA by two field managers (`opm-cli`, `opm-controller`). 05-risks covers the `spec.owner` *field* race, but between the `spec.owner: operator` patch and the operator's first reconcile both actors could write the `Ready` condition. Does SSA's associative-list merge (keyed on `type`) resolve the overlap cleanly, or do the two managers conflict on the same list element? Pin the field-ownership contract for the conditions list across the flip, and confirm the CLI relinquishes the condition (or that the operator's manager cleanly takes it).
- **OQ12: Which Platform source does `instance diff` (and other live-compare paths) use?** Status: resolved-by-D21. `diff` follows the same precedence as `apply` (`--platform <file>` > cluster `Platform` CR > local/embedded default, warn-on-fallback, source provenance reported), so the diff reflects what `apply` would actually do. The `diff`-specific nuance — falling back to a local default while comparing against live cluster state can show spurious drift — is handled by D21's warn + provenance banner rather than refusing to diff, because refusing would break D17 accessibility for non-admins; the accurate diff is available to anyone who can read the cluster `Platform`. Original analysis: D11 places offline `build`/`render` on flag/local and forces the cluster CR for `handoff`, but `diff` — which compares a fresh render against live cluster state — is not placed in that precedence. Diffing against the cluster while rendering against a *local* default Platform yields misleading diffs; always reading the cluster Platform reintroduces the admin-only problem D17 forbids. Decide diff's default source and how it interacts with the platform-source flags (OQ14). Likely outcome: diff follows the same precedence as `apply` (flag > cluster CR > local default) so the diff reflects what `apply` would actually do.
- **OQ13: How is the solo-cluster `Platform` write-if-absent made atomic?** Status: resolved-by-D22. Plain `Create` with `FieldManager: opm-cli`, tolerating `AlreadyExists` (409) as a success-noop; the API server's atomic name-uniqueness check is the synchronization primitive, so there is no TOCTOU. SSA apply is rejected for this write (create-or-update would overwrite an existing Platform); GET-then-Create degrades into the same design. Refines D12's "via SSA" wording. Original analysis: D12 has the CLI write the singleton `cluster` Platform **write-if-absent** via SSA manager `opm-cli`, never overwriting an existing operator/user Platform. But SSA with a manager is create-*or-update*, not create-only; "write-if-absent" needs either a create-only call (and tolerating `AlreadyExists`) or a GET-then-create with a TOCTOU window against a concurrent operator install. Pin the mechanism so a race with the operator adopting/creating the Platform cannot clobber a spec.
- **OQ14: What platform-source flags do the relevant CLI commands expose?** Status: resolved-by-D21. Single `--platform <file>` local override (highest precedence, all non-`handoff` commands, supersedes `--provider`) + automatic cluster-CR-then-local-default fallback for `apply`/`diff` (warn on fallback) + offline `build`/`render` never reading the cluster + `handoff` forcing the cluster CR; every command reports which platform source it resolved. No tri-state toggle now; `--local-platform` escape hatch deferred. Grounded in the session security analysis: the local override carries no privilege beyond the user's own RBAC, so provenance reporting (not gating) is the control; the seeding path is a 05-risks note. Original analysis: D11/D17 establish the precedence (flag > cluster CR > local default) and that both sources are first-class, but the concrete flag surface is unspecified. What flags select the source on each command — a single `--platform <file>` (local override), an explicit `--use-cluster-platform` / `--local-platform` toggle, or both — and which default applies per command (`apply`, `diff`, `render`, `build`, `handoff`)? `handoff` forces cluster (D11) and offline `build`/`render` never touch the cluster (D11/D17); `apply` and `diff` (OQ12) are the cases needing an explicit, consistent flag contract. Decide in the kernel-adoption / platform-resolution slice.
- **OQ15: Should the CLI's and operator's stale-set base relation (component-aware vs. component-agnostic) be reconciled to the same behavior?** Status: open. Discovered during D31's investigation: `cli/pkg/inventory.ComputeStaleSet` uses `IdentityEqual` (a component rename is flagged stale, then rescued by `ApplyComponentRenameSafetyCheck`); `opm-operator/internal/inventory.ComputeStaleSet` uses `K8sIdentityEqual` (a component rename is never flagged stale in the first place). D31 established this divergence is not a safety issue — it is never cross-compared between actors — but it is a product-consistency issue: the same user action (renaming a component) produces different observable prune behavior depending on which tool manages the release. Resolving this requires deciding whether cross-tool behavioral consistency is a goal this enhancement (or a follow-on) should pursue, and if so, which behavior to standardize on, and whether standardizing means a documented convention each side independently implements or an actual reason to reconsider shared code for this one function.
- **OQ16: Should the operator gain its own apply-time foreign/terminating-object collision guard, and if so, what shape?** Status: open. Discovered during D31's investigation. The CLI's `PreApplyExistenceCheck` (`cli/internal/inventory/stale.go`) refuses to apply into an identity that already exists foreign-owned or is mid-deletion, on a release's first-ever apply. The operator's apply path (`internal/apply/apply.go`, via Flux's `ResourceManager.ApplyAllStaged` with `ForceOwnership`) has no equivalent at any point — first reconcile or steady-state. Given both apply paths force SSA field-ownership unconditionally, and the operator's existing delete-time ownership guard (`Prune`) cannot backstop a collision that already occurred at apply time (a successful colliding apply relabels the foreign object as `opm-controller`-managed, so it looks legitimately owned from then on), this is a real, presently-shipping exposure independent of this enhancement's other decisions (see also `05-risks.md`). Resolving requires: (a) deciding whether to build it now or track it separately from 0006; (b) if built, deciding the check's scope in a continuously-reconciling system (every reconcile that grows the entry set, vs. only the release's first-ever reconcile — the CLI's one-shot model doesn't have this distinction to make); and (c) deciding the failure-handling shape (abort the whole reconcile vs. skip-and-flag the one colliding entry, and whether an override such as `spec.rollout.forceConflicts` should apply here or whether collision refusal should have no override).
- **OQ17: Does the CLI stamp an advisory provenance annotation when the rendered bytes did not come from a registry-resolved artifact?** Status: resolved-by-D38. Kept — and promoted beyond advisory: C1 stamps `module-instance.opmodel.dev/source: local` (conservative trigger: local main module or any local-path `replaceWith`), and C3's handoff refuses while it is present, as a fail-closed pre-gate in front of the authoritative check. D38 also closes the hole the investigation surfaced: C3's D7.4 verification render MUST bypass `local-module.cue` and resolve strictly from the registry, else a local replacement makes the digest check self-consistent and meaningless. The original analysis (kept for record): D37 demoted D6's annotation from fixed behavior to this question; safety does not depend on the annotation (D7.3/D7.4 gate handoff regardless), and it must never become a granting input since annotations are user-editable — D38 satisfies this by making its only effect refusal.
