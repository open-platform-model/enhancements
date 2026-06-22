# Dependency Analysis — CLI ↔ library ↔ opm-operator

Gathered 2026-06-22 by static analysis of the three `go.mod` files and the import graphs of the packages the CLI would consume. This is the evidence behind D11/D13/D14 and OQ2. It is a snapshot of the module state on 2026-06-22; re-verify against HEAD before implementing.

## The dependency diamond

```
        github.com/opmodel/cli
          │                 │
   D9 ────┘                 └──── D4 (as written) → superseded by D13
          ▼                        ▼
 .../library  ◄────────────  .../opm-operator   (already requires library v0.5.2)
```

Acyclic; `library` is the shared base. The diamond's cost is entirely on the two edges out of the CLI.

## Module facts (2026-06-22)

| module | path | go | cuelang.org/go | k8s.io/* | controller-runtime | Flux |
| --- | --- | --- | --- | --- | --- | --- |
| cli | `github.com/opmodel/cli` | 1.26.0 | **v0.16.1** | v0.36.0 | — | — |
| opm-operator | `github.com/open-platform-model/opm-operator` | 1.26.2 | **v0.17.0-alpha.1** | v0.35.2 | v0.23.3 | yes |
| library | `github.com/open-platform-model/library` | 1.25.0 | **v0.17.0-alpha.1** | **none** | — | — |

No `replace` directives in any of the three (verified) — so there are no main-module-only rewrites the CLI would have to replicate.

Note the module-path inconsistency: the CLI is `github.com/opmodel/cli`; the other two are `github.com/open-platform-model/*`. Not a blocker, but the RFC-0007 text assumed `github.com/open-platform-model/cli`.

## `library` is k8s-free (verified)

`grep -rEl "k8s.io/|controller-runtime|opm-operator" library/ --include=*.go` returns one hit, in a `_test.go` (not compiled by importers). The kernel returns its own resource type (`library/opm/core`); k8s conversion happens in the consumer. **D9 (adopt the kernel) drags no Kubernetes machinery.**

## What importing the operator packages drags in (the D4 cost)

Go imports at *package* granularity. `opm-operator/api/v1alpha1` is one package; its files import:

- `sigs.k8s.io/controller-runtime/pkg/scheme` — `groupversion_info.go` (scheme builder)
- `github.com/fluxcd/pkg/apis/meta` — `release_types.go`, `common_types.go`
- `k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1`

So importing `ModuleRelease`/`Inventory`/`InventoryEntry` cannot avoid compiling the whole `v1alpha1` package, which pulls **controller-runtime/pkg/scheme + fluxcd/pkg/apis/meta + apiextensions-apiserver** into the CLI. (`pkg/scheme` is a thin Builder, not the full controller *manager* — but these modules still enter the CLI's graph.) `internal/inventory` (the future `pkg/inventory`) imports `api/v1alpha1` *and* `pkg/core`; `pkg/core` imports `library/opm/core` + `cuelang.org/go/cue`. So the inventory package inherits the same drag.

## The three problems

### Problem 1 — D9 forces the CLI onto CUE v0.17.0-alpha.1

MVS takes the max: `cuelang.org/go` = max(0.16.1, 0.17.0-alpha.1) = **0.17.0-alpha.1**. Importing `library` (D9) alone bumps the CLI's CUE to a pre-release alpha; the CLI's entire existing v0.16 CUE Go-API usage (`pkg/loader`, `pkg/render`, `internal/config`) must move to v0.17. **Driven by D9, not the diamond.** Resolution: **accepted** — see D14. The CLI may be refactored wholesale (single user, no backwards-compat). Connects to the known workspace v0.16-vs-v0.17-alpha split.

### Problem 2 — D4 drags controller-runtime + Flux

Resolution: **avoid it** — see D13. The CLI does not import `opm-operator/api/v1alpha1` or `pkg/inventory`. The shared pure inventory logic (entry-building from kernel-rendered resources, identity equality, `ComputeStaleSet`, `ComputeDigest`) homes in `library` over a runtime-neutral type, consumed by *both* the CLI and the operator (identical logic is required for handoff prune-set parity, not just convenience). The CLI represents the `ModuleRelease` CR via `unstructured` (or a CLI-local minimal typed struct) carrying no Flux/controller-runtime imports, and its apply/prune is a one-shot design that borrows the operator's reconcile *concepts* — not its controller-runtime machinery (D13, and the CLI-is-not-a-long-running-process point).

### Problem 3 — k8s + toolchain skew

MVS would compile the operator's packages + controller-runtime 0.23.3 (pinned for k8s 0.35) against the CLI's k8s 0.36 in the CLI build. With D13 the CLI no longer imports those packages, so this conflict largely evaporates for the CLI build — but to keep the two repos coherent, **bump `opm-operator` to the CLI's k8s line (latest stable) and a matching controller-runtime**, and align the `go` directive (CLI ≥ 1.26.2). Recorded as an operator prep step.

## Net result for the CLI's go.mod

With D13: the CLI gains **`library` only** (plus its existing `client-go`/apimachinery for unstructured CR handling). The `cli → opm-operator` Go-module edge is **dropped**; "borrow code from the operator" means copy concepts/code by hand or consume the shared logic from `library`, not a module dependency. The diamond collapses to a single `cli → library` edge.
