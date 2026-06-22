# Design Decisions — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. The log is **append-only** — never remove or renumber. A reversed decision gets a new entry that supersedes it; the original stays.

D1–D8 are promoted from `cli/docs/rfc/0007`, which is the design rehearsal for this work; their Source lines cite the RFC. D9 and D10 are decisions taken when this enhancement was created (user direction, 2026-06-22) and they extend the RFC: D9 pulls render/match into scope (the RFC had left the whole engine question to "future work"), and D10 fixes the precise render-vs-apply cut.

---

## Decisions

### D1: The CLI writes a `ModuleRelease` CR instead of a Secret

**Decision:** On `opm release apply`, the CLI creates/updates a `ModuleRelease` object named after the release, in the release namespace, and stores its inventory in `status.inventory` via the status subresource. `release delete` resolves inventory from the CR and deletes the CR last; `release list` lists `ModuleRelease` objects; `release status` / `diff` read `status.inventory`. CR writes use field manager `opm-cli`. `cli/internal/inventory` (Secret CRUD/marshaling) is deleted.

**Alternatives considered:**

- Keep the Secret, add a CR mirror. Rejected: two stores reintroduces exactly the disjoint-source-of-truth problem the enhancement exists to remove.
- A new CLI-specific CRD distinct from the operator's. Rejected: a separate type defeats the handoff goal — the whole point is that both actors read and write the *same* object.

**Rationale:** A single source of truth for "what is deployed" that both the CLI and operator already share the shape of. The operator's prune set is `previous status.inventory − current render`; if the CLI has written the deployed entries into `status.inventory`, the operator's first post-handoff reconcile sees a zero stale set.

**Source:** `cli/docs/rfc/0007` D1.

---

### D2: The CLI writes a strict subset of status

**Decision:** The CLI writes only `inventory`, `releaseUUID`, `lastAppliedRenderDigest`, `lastAppliedSourceDigest`, `lastAppliedConfigDigest`, `lastAppliedAt`, and a single `Ready` condition with reason `AppliedByCLI`. It does **not** write `observedGeneration`, `lastAttempted*`, `failureCounters`, `history`, or `nextRetryAt`. The operator MUST tolerate a `ModuleRelease` carrying only this subset (it already tolerates empty status on a fresh CR).

**Alternatives considered:**

- The CLI writes the full status shape. Rejected: most fields encode control-loop semantics (retry bookkeeping, observed generation) that a one-shot actor cannot meaningfully own; writing them would be fiction the operator then has to distrust.
- The CLI writes no status, only spec, and lets the operator populate status. Rejected: then a CLI-only cluster (no operator) has no inventory at all — the store has to be CLI-written.

**Rationale:** The CLI is a one-shot actor with no reconcile loop. The subset is exactly the facts it can stand behind, and exactly what the operator needs to detect a no-op on first reconcile (the `lastApplied*` digests + inventory).

**Source:** `cli/docs/rfc/0007` D2.

---

### D3: Explicit `spec.owner` marker; the operator skips CLI-owned CRs

**Decision:** Add `spec.owner: "cli" | "operator"` to `ModuleRelease` (default `"operator"`). When `spec.owner: cli`, the operator skips render/apply/prune entirely, sets a single `Ready: Unknown` condition with reason `ManagedExternally`, and never touches `status.inventory` or any CLI-written status field. The CLI's existing `EnsureCLIMutable` guard maps onto this field: the CLI refuses to apply/delete a release whose `spec.owner` is `operator`. This is an operator-side change, documented here per the cross-repo scope.

**Alternatives considered:**

- `spec.suspend: true` as the marker. Rejected: conflates "paused" with "CLI-owned"; a `kubectl edit` unsuspend would trigger an unverified takeover. Suspend stays orthogonal.
- Status-driven skip (`status.inventory.createdBy == cli`). Rejected: driving controller behaviour from status is fragile (status is lost on backup/restore); spec is the user-intent surface.

**Rationale:** A CLI-created CR in a cluster running the operator would otherwise be reconciled immediately, with the operator fighting the CLI for resources. An explicit spec-level marker the operator respects is the minimal safe coordination point, and it is the field `handoff` flips.

**Source:** `cli/docs/rfc/0007` D3.

---

### D4: The operator exports its inventory package; the CLI imports it

**Decision:** `opm-operator/internal/inventory` moves to `opm-operator/pkg/inventory` (no behaviour change), exporting `InventoryEntry`, `NewEntryFromResource`, `IdentityEqual`, `K8sIdentityEqual`, `ComputeStaleSet`, `ComputeDigest`. The CLI adds `github.com/open-platform-model/opm-operator` to `go.mod` and imports `api/v1alpha1` (the `ModuleRelease`/`Inventory`/`InventoryEntry` types), `pkg/inventory` (the functions above), and `pkg/core` (label constants). The CLI does **not** import the operator's apply/prune engine. Dependency direction `cli → opm-operator` is accepted.

**Alternatives considered:**

- Move the shared types into `library`, both repos import from there. Cleaner long-term, but fights Kubebuilder codegen for the CRD types and adds a third repo to every schema change. Reserved — see OQ2, which reopens this now that the CLI also depends on `library` (D9).
- Keep the CLI's own inventory copy. Rejected: the two copies already drifted once; a single shared implementation is the point.

**Rationale:** The inventory shape and functions already exist in the operator (copied from the CLI by the `cli-dependency-and-inventory-bridge` change, which explicitly anticipated this promotion). Inverting the dependency — operator owns, CLI imports — gives one implementation. The import is narrow: API types plus pure functions, pulling in apimachinery but not controller-runtime's manager or Flux SSA.

**Source:** `cli/docs/rfc/0007` D4; `opm-operator/openspec/changes/archive/2026-04-12-01-cli-dependency-and-inventory-bridge/`.

**Superseded in part by D13** (dependency direction). Static analysis (`research/findings.md`) showed `opm-operator/api/v1alpha1` drags `controller-runtime/pkg/scheme` + `fluxcd/pkg/apis/meta` + `apiextensions-apiserver` into any importer, because Go imports at package granularity. The CLI does **not** import the operator after all; the shared inventory logic moves to `library`.

---

### D5: `opm install` — CRDs and operator via the CLI

**Decision:** Add `opm install crds` (CRDs only — required for any CLI apply), `opm install operator` (full operator from `dist/install.yaml`), and `opm uninstall operator`. Installs use SSA with field manager `opm-cli`. The CLI embeds the CRD manifests and `dist/install.yaml` of a pinned operator version at build time (`go:embed`), with `--version` to fetch a different release. `opm uninstall` never deletes CRDs. Missing-CRD behaviour on `release apply`: fail with a one-line hint (`ModuleRelease CRD not found — run 'opm install crds'`), not silent auto-install.

**Alternatives considered:**

- Auto-install CRDs inside `release apply`. Rejected: installing CRDs is a cluster-admin write; doing it implicitly inside an app apply surprises exactly the operators who care. A `--install-crds` convenience flag is left open (OQ7).
- Fetch manifests from GitHub at runtime always (no embed). Rejected: breaks the offline learner path and loses the build-time "this CLI matches this CRD version" fact. Embed is default, fetch is the fallback.

**Rationale:** Once inventory lives in a CR, the CRDs are a hard prerequisite for *every* CLI apply, including clusters that never run the operator. Embedding keeps the learner path offline-friendly; never deleting CRDs via the CLI makes accidental cluster-wide data loss impossible (a CRD delete cascades to every `ModuleRelease`).

**Source:** `cli/docs/rfc/0007` D5.

---

### D6: Spec contents when applying from a local module

**Decision:** When the CLI applies from a published module reference, it writes that reference into `spec.module` verbatim. When it applies from a local path, it writes the module's declared path/version as best-effort metadata plus a `module-release.opmodel.dev/source: local` annotation; the CR is a valid inventory store but not yet reconcilable. Handoff (D7) is the gate that guarantees `spec.module` is resolvable before the operator ever owns the CR.

**Alternatives considered:**

- Refuse to write a CR when applying from a local path. Rejected: CLI-from-local-path is a primary learner workflow; it must still get CR-backed inventory.
- Publish the local module automatically on apply. Rejected: applying and publishing are distinct user intents; conflating them surprises the user and may push to a registry they did not choose.

**Rationale:** A CLI-owned CR can temporarily describe a module the operator could not fetch, and that is safe *because* D3 stops the operator acting on CLI-owned CRs and D7 refuses to flip ownership until the spec is reconcilable.

**Source:** `cli/docs/rfc/0007` D6.

---

### D7: `opm release handoff` — the migration feature

**Decision:** `opm release handoff <release>` verifies, in order: (1) operator installed and ready; (2) the CR exists with `spec.owner: cli`; (3) `spec.module` is a published, registry-resolvable reference; (4) the render digest the CLI computes from the published reference + the CR's values matches `status.lastAppliedRenderDigest` — mismatch aborts (`--force` overrides with a diff). Then it patches `spec.owner: operator` (single SSA patch, manager `opm-cli`) and waits, bounded, for the operator's first reconcile, reporting the outcome (expected: `Ready: True`, inventory revision incremented, zero changed, zero pruned). A reverse flip (`--to cli`) reuses the same machinery.

**Alternatives considered:**

- Flip ownership without digest verification. Rejected: an unverified flip is exactly the unsafe manual path this enhancement replaces.
- A separate `opm migrate` top-level command. Rejected: handoff is a release-scoped operation; it belongs under `release`.

**Rationale:** With shared inventory (D1) and a shared kernel (D9), the digest check in step 4 is *meaningful* — both sides render through the same kernel, so equal digests genuinely mean the operator's first apply is a no-op. The zero-downtime property is the payoff of the whole enhancement.

**Source:** `cli/docs/rfc/0007` D7. Note: the RFC framed step-4 parity as best-effort because the CLI then had its own pipeline; D9 makes it structural.

---

### D8: Migration of existing Secret inventories

**Decision:** On `opm release apply` against a release that has a Secret inventory but no `ModuleRelease` CR: read the Secret, create the CR, write the Secret's record into `status.inventory` (preserving revision), proceed with the normal apply, then delete the Secret only after the CR status write succeeds. `release status`/`delete`/`list` fall back to reading Secrets for one minor release with a deprecation warning; after that the Secret path is removed entirely.

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

**Decision:** The CLI resolves the platform it feeds to `Kernel.SynthesizePlatform` by precedence: (1) an explicit `--platform <file>` override; else (2) when targeting a cluster, the singleton `Platform` CR's spec read from the cluster and materialized locally via `Kernel.Materialize`; else (3) a local/embedded default platform — the evolution of today's `~/.opm/config.cue` provider. `opm release handoff` forces source (2) with no fallback: absent a cluster `Platform`, handoff refuses, because render parity with the operator cannot be guaranteed otherwise. Offline `build` / `render` use sources (1)/(3) only and never touch the cluster. The CLI reads the Platform *spec* and runs `Materialize` itself — the operator never persists a materialized platform (it lives only in the controller's in-memory, generation-keyed `platformstore.Store`; `PlatformStatus` holds conditions only), so reading a pre-materialized result is impossible; both actors materialize from the same spec.

**Alternatives considered:**

- Always render against a local/config platform, never read the cluster. Rejected: the CLI and operator could then render the same release differently; handoff digest parity (D7.4) degrades to best-effort and the cluster-consistency property is lost.
- Make a cluster `Platform` CR a hard prerequisite for *every* render, including offline `build`. Rejected: breaks offline authoring and the learner-solo path (a freshly-CRD'd cluster has no Platform yet).

**Rationale:** The platform is a property of the cluster — when targeting an operator-managed cluster the CLI must render against *that cluster's* platform or it deploys something the cluster's own reconciler would render differently. The precedence keeps offline authoring working while making the cluster CR authoritative where correctness depends on it. It mirrors the CLI's existing provider resolution (flag > config > default) and D5's "CRDs are a prerequisite" shape. A residual parity subtlety: because each side materializes fresh, a catalog version published between CLI apply and operator takeover can yield different materialized sets — D7.4's digest check catches it (safely aborting handoff); pinning the exact materialized version-set is a possible future hardening.

**Source:** User decision 2026-06-22. Grounded in `opm-operator/internal/controller/platform_controller.go` (`SynthesizePlatform` → `Materialize` → in-memory `Store`), `opm-operator/internal/render/kernel_module_renderer.go` (render gates on the store via `ErrPlatformNotReady`), and `cli/pkg/provider/` + `cli/internal/config/` (today's local provider resolution this evolves).

---

### D12: `Platform` carries no owner marker; the operator always owns the singleton; the CLI writes an un-owned `cluster` Platform in solo clusters

**Decision:** Unlike `ModuleRelease` (D3), the `Platform` CR gets **no** `spec.owner` skip marker. The operator's `PlatformReconciler` always materializes the singleton `cluster` Platform — its in-memory store is the sole input to every operator `ModuleRelease` render, so an operator that "skipped" the platform could render nothing. The CLI therefore only ever *reads* the Platform; it never owns or suspends it. In a CLI-solo cluster (CRDs installed per D5, no operator/Platform yet), the CLI writes its resolved local/default platform as the singleton `cluster` Platform CR — **write-if-absent**, never overwriting an existing operator- or user-managed Platform — using SSA field manager `opm-cli`. When the operator is later installed it adopts and materializes that existing spec; there is no platform-level handoff.

**Alternatives considered:**

- Give `Platform` the same `spec.owner` skip semantics as `ModuleRelease`, for symmetry. Rejected: a CLI-owned, operator-skipped singleton empties the operator's store and gates *every* operator render. The singleton cannot be per-actor the way namespaced releases can.
- CLI never writes a Platform; solo render stays local-only. Rejected (user decision): writing the singleton gives the cluster a record of what the CLI rendered against and lets the operator adopt it on install with zero extra steps.

**Rationale:** `ModuleRelease` ownership can be per-release and mixed; the `Platform` singleton cannot — the operator structurally needs it for its own function. So the platform is shared-read, operator-owned, with the CLI bootstrapping it when absent. Write-if-absent avoids clobbering a GitOps-defined Platform; SSA lets a user or the operator take field ownership later. This asymmetry with D3 is deliberate and must not be "consistency"-fied into owner-skip semantics by a slice.

**Source:** User decision 2026-06-22.

---

### D13: The CLI imports `library` only; it does not import `opm-operator` (no controller-runtime, no Flux) — supersedes D4's dependency direction

**Decision:** The CLI does **not** add a Go-module dependency on `opm-operator`. Importing `opm-operator/api/v1alpha1` (needed for the typed `ModuleRelease` and `InventoryEntry`) drags `sigs.k8s.io/controller-runtime/pkg/scheme`, `github.com/fluxcd/pkg/apis/meta`, and `k8s.io/apiextensions-apiserver` into the importer, because Go compiles whole packages and those types share the `v1alpha1` package (evidence: `research/findings.md`). Instead:

1. The shared **pure inventory logic** — building inventory entries from kernel-rendered resources, identity equality (`IdentityEqual`/`K8sIdentityEqual`), `ComputeStaleSet`, `ComputeDigest` — homes in `library` over a runtime-neutral entry type, and is consumed by **both** the CLI and the operator. This is required for correctness, not just tidiness: the operator's post-handoff prune set is `previous status.inventory.entries − current render entries`, so the CLI and operator must compute entry identity and digests with the *same* code or handoff prune-set parity breaks.
2. The CLI represents the `ModuleRelease` CR via `unstructured` (client-go dynamic) — or a CLI-local minimal typed struct — carrying **no** Flux / controller-runtime imports. It sets `spec.owner`, `spec.module`, `status.inventory`, etc. by field path; it does not need the operator's typed API package.
3. The CLI's apply + prune is a **one-shot** design (the CLI is not a long-running process — no informers, no work queue, no controller-runtime manager). It borrows the operator's reconcile *concepts* — phase order (render → plan stale → SSA apply → prune → write status), inventory-authoritative pruning, the ownership/managed-by guard, the never-prune-Namespaces/CRDs safety — by porting the logic, not by importing controller-runtime.

The CLI's resulting `go.mod` gains `library` only (plus its existing `client-go`/apimachinery). The `cli → opm-operator` edge is dropped; "borrow code from the operator" means port concepts/code or consume the shared logic from `library`, not a module dependency. The diamond collapses to a single `cli → library` edge.

**Alternatives considered:**

- D4 as written — CLI imports `opm-operator/api/v1alpha1` + `pkg/inventory`. Rejected: pulls controller-runtime + Flux + apiextensions into a one-shot CLI for no benefit; the CLI runs no controller machinery.
- Refactor the operator's `v1alpha1` package to split the Flux-dependent CRs (`Release`/`BundleRelease`) from `ModuleRelease`/`Platform`/inventory so a thin import avoids the drag. Rejected for now: fights Kubebuilder's single-package-per-API-group codegen and the shared `groupversion_info.go` scheme builder; large operator-side churn for a coupling we can avoid entirely.

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

**Decision:** `opm release handoff` ships in the forward direction only (CLI → operator). The reverse flip (`--to cli`, operator → CLI) named in D7 is **removed from scope**. The verification machinery, command surface, and the operator-side concerns of flipping a reconciled CR back to CLI ownership are not built in this enhancement. D7's forward path (preconditions → digest check → `spec.owner: operator` patch → bounded no-op-reconcile wait) is unchanged.

**Alternatives considered:**

- Keep `--to cli` as D7 specified. Rejected (user decision): reverse handoff carries its own unresolved concerns the forward path does not — chiefly cleaning up operator-written control-loop status (`observedGeneration`, `failureCounters`, `history`, `nextRetryAt`) left on a CR that flips back to a one-shot owner, plus the takeover-window race in the operator-relinquishing direction. None of that is needed for the headline learner-to-operator path.
- Build reverse handoff but gate it behind a flag. Rejected: still owes the status-cleanup and relinquish-race design; deferring the whole capability is cleaner than a half-built one.

**Rationale:** The enhancement's value is the one-directional CLI → operator transition (the "grow into GitOps" story). Reverse handoff is a separable capability with its own design surface; excluding it keeps the slice lean and avoids shipping an under-specified relinquish path. It can return as a future enhancement if a concrete need appears.

**Source:** User decision 2026-06-22. Supersedes the reverse-mode (`--to cli`) portion of D7; D7's forward path stands.

---

### D17: Both a local Platform and an in-cluster Platform CR are first-class; OPM must never require cluster-admin for normal use

**Decision:** The platform-source precedence in D11 (`--platform` flag > cluster `Platform` CR > local/embedded default) is a deliberate accessibility constraint, not just a convenience ordering: a user who is **not** a cluster admin — who cannot read or write the cluster-scoped singleton `Platform` CR — must still be able to render and apply releases against a local/embedded Platform. Forcing the cluster `Platform` CR as a hard prerequisite for every render would make cluster-admin a precondition for using OPM at all, which is explicitly not the intent. `handoff` is the one operation that forces the cluster CR (D11), and that is acceptable precisely because handoff is an operator-adoption step that inherently assumes operator/admin context. Every non-handoff path (`build`, `render`, `apply`, `diff`) must remain usable with a local Platform and no cluster Platform access.

**Alternatives considered:**

- Make the cluster `Platform` CR authoritative for all cluster-targeting commands, local Platform only for fully-offline `build`/`render`. Rejected: a non-admin who can apply `ModuleRelease` objects into their own namespace but cannot read the cluster-scoped `Platform` would be locked out of `apply` — turning OPM into an admin-only tool.
- Local Platform only; never read the cluster Platform. Rejected: that is the opposite failure — it loses cluster-render parity where correctness depends on it (the original reason for D11). Both must be first-class; the precedence picks between them per-command.

**Rationale:** OPM's adoption story is "anyone can try it." Gating normal use on admin-only cluster state contradicts that. Supporting both Platform sources — local for the unprivileged/solo path, cluster CR where parity with the operator matters — is what keeps the tool open to non-admins while preserving handoff safety. This frames D11's precedence as load-bearing for accessibility and constrains slices from ever "simplifying" it down to a cluster-only source.

**Source:** User decision 2026-06-22. Reinforces and constrains D11/D12.

---

## Open Questions

- **OQ1: Where does the CLI get its `MaterializedPlatform`?** Status: resolved-by-D11, resolved-by-D12. The CLI uses a source precedence (flag > cluster `Platform` CR > local/embedded default), reads the Platform *spec* and materializes it itself via the same kernel calls the operator uses, and forces the cluster CR for `handoff` (D11). The `Platform` carries no owner marker — the operator always owns/materializes the singleton; in solo clusters the CLI writes an un-owned `cluster` Platform (write-if-absent) which the operator adopts on install (D12). A parity experiment (CLI and operator producing equal render digests for the same release against the same Platform spec) is still recommended before `accepted` — see 04-graduation.
- **OQ2: Dependency topology with the `cli → library` + `cli → opm-operator` diamond.** Status: resolved-by-D13. The diamond is collapsed: the CLI imports `library` only (not `opm-operator`), avoiding controller-runtime + Flux; the shared pure inventory logic homes in `library` and the CLI handles the CR as `unstructured`. `library` is added to `affects`. The go.mod build spike (does the CLI's v0.16 CUE code compile under v0.17-alpha; does everything resolve) is still worth running before the kernel-adoption slice — see `research/findings.md` "What the spike must prove" — but the topology decision no longer waits on it.
- **OQ3: Status-subresource RBAC for a user-credential actor.** Status: open. The operator writes `status` as a controller with a service account; the CLI writes it with the user's kubeconfig, which needs explicit `modulereleases/status` permission. Does `opm install crds` emit an optional CLI-user Role/RoleBinding? Does apply degrade gracefully (clear error) when the user can patch `spec` but not `status`? RFC-0007 flagged RBAC as low-risk but did not pin the contract.
- **OQ4: CRD version-skew compatibility contract.** Status: open. The CLI embeds operator-vX CRDs (D5); the cluster may run operator-vY. `spec.owner` and the status subset must be forward/backward compatible across the skew the `--version` flag allows. What is the supported window, and does `opm install crds` warn or refuse on mismatch?
- **OQ5: Does the umbrella ship as two waves?** Status: open. The kernel-adoption strand (D9) is gated on 0001's `library` slice; the inventory/CR/handoff strand (D1–D8) is not. Splitting into wave 1 (CR inventory + `spec.owner` + install + handoff against the CLI's *current* pipeline) and wave 2 (kernel adoption) lets inventory/handoff land before 0001 completes — but wave-1 handoff digest parity would be best-effort until wave 2 makes it structural (D7 vs D9). Decide whether to ship handoff in wave 1 at all, or hold it for wave 2.
- **OQ6: Does the shared `pkg/inventory` absorb the CLI-only prune-safety checks?** Status: open (RFC-0007 OQ-1). Component-rename detection and the pre-apply existence check exist only CLI-side today. Moving them into the shared package makes them operator behaviour too (a benefit) but widens the operator slice. Bias: yes.
- **OQ7: `--install-crds` convenience flag on `apply`?** Status: open (RFC-0007 OQ-2). D5 decides against silent auto-install; an explicit opt-in flag could still collapse first-run friction.
- **OQ8: `opm install operator` vs `opm operator install`.** Status: open (RFC-0007 OQ-3). Pure CLI-surface taxonomy; decide in the install slice.
- **OQ9: `release list --all-namespaces` over CRs.** Status: open (RFC-0007 OQ-5). Listing CRs cluster-wide needs list permission on `modulereleases` across namespaces. Acceptable, or keep a label-based fallback?
- **OQ10: Is `spec.values` captured faithfully enough for handoff render parity?** Status: open — needs dedicated research before `accepted` (or explicit deferral with a recorded reason). D7.4 recomputes the render digest from `spec.module` **plus the CR's values**, so the operator reproduces the render from `spec.module` + `spec.values`. But the CLI today has richer value inputs than a single blob — config layering, env wiring (RFC-0005), multiple `--values` files. If the CLI's *effective* values do not collapse losslessly into `spec.values`, the operator renders something different and the zero-downtime no-op silently fails. D6 pins `spec.module` capture but says nothing about value capture. This is load-bearing for the whole zero-downtime claim and deserves its own investigation (how the CLI flattens its value sources, whether anything is irreducibly CLI-local, and whether the handoff digest check is sufficient to catch a lossy flatten). The OQ1 parity experiment (04-graduation) MUST include a release with non-trivial layered values, not just a bare module reference. Bias: capture the fully-resolved value set into `spec.values` and treat anything that cannot round-trip as a handoff-blocking precondition.
- **OQ11: Who owns `status.conditions` during the handoff transition window?** Status: open. `status.conditions` is a shared list written under SSA by two field managers (`opm-cli`, `opm-controller`). 05-risks covers the `spec.owner` *field* race, but between the `spec.owner: operator` patch and the operator's first reconcile both actors could write the `Ready` condition. Does SSA's associative-list merge (keyed on `type`) resolve the overlap cleanly, or do the two managers conflict on the same list element? Pin the field-ownership contract for the conditions list across the flip, and confirm the CLI relinquishes the condition (or that the operator's manager cleanly takes it).
- **OQ12: Which Platform source does `release diff` (and other live-compare paths) use?** Status: open — investigate and boil down to a decision. D11 places offline `build`/`render` on flag/local and forces the cluster CR for `handoff`, but `diff` — which compares a fresh render against live cluster state — is not placed in that precedence. Diffing against the cluster while rendering against a *local* default Platform yields misleading diffs; always reading the cluster Platform reintroduces the admin-only problem D17 forbids. Decide diff's default source and how it interacts with the platform-source flags (OQ14). Likely outcome: diff follows the same precedence as `apply` (flag > cluster CR > local default) so the diff reflects what `apply` would actually do.
- **OQ13: How is the solo-cluster `Platform` write-if-absent made atomic?** Status: open. D12 has the CLI write the singleton `cluster` Platform **write-if-absent** via SSA manager `opm-cli`, never overwriting an existing operator/user Platform. But SSA with a manager is create-*or-update*, not create-only; "write-if-absent" needs either a create-only call (and tolerating `AlreadyExists`) or a GET-then-create with a TOCTOU window against a concurrent operator install. Pin the mechanism so a race with the operator adopting/creating the Platform cannot clobber a spec.
- **OQ14: What platform-source flags do the relevant CLI commands expose?** Status: open. D11/D17 establish the precedence (flag > cluster CR > local default) and that both sources are first-class, but the concrete flag surface is unspecified. What flags select the source on each command — a single `--platform <file>` (local override), an explicit `--use-cluster-platform` / `--local-platform` toggle, or both — and which default applies per command (`apply`, `diff`, `render`, `build`, `handoff`)? `handoff` forces cluster (D11) and offline `build`/`render` never touch the cluster (D11/D17); `apply` and `diff` (OQ12) are the cases needing an explicit, consistent flag contract. Decide in the kernel-adoption / platform-resolution slice.
