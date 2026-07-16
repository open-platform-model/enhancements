# Enhancement 0006 — CLI CR Inventory, Library Kernel Adoption, and Operator Handoff

See [`config.yaml`](config.yaml) for metadata. This README is the index of the six split documents plus the Scope and Cross-References tables; everything else lives in the split files.

## Summary

Converges the OPM CLI onto the same runtime contract the operator already runs. Three coupled moves: (1) the CLI stops storing its release inventory in a Kubernetes Secret and instead writes the operator's `ModuleInstance` custom resource, recording inventory in `status.inventory`, using its own local inventory logic (entry identity, stale-set, digest) rather than a shared package — D31; (2) the CLI deletes its own render/match pipeline and renders through the `library` kernel — the same kernel the operator uses — so a CLI render and an operator render of the same release are byte-identical by construction; (3) the CLI imports `library` for the kernel only — **not** `opm-operator` (no CRD types, no inventory package) — while handling the `ModuleInstance` CR as `unstructured` and keeping its own server-side-apply engine (duplicated from the operator, SSA mandatory). On top of that contract sits the headline feature: `opm instance handoff`, a zero-downtime transfer of a CLI-deployed release to operator management, made a no-op server-side apply because both actors read and write the same `InventoryEntry` shape in the same CR (anchored by the CRD schema, not by shared code) and now compute the same render digest from the same kernel.

This enhancement promotes the storage/handoff design of `cli/docs/rfc/0007` (and, for the inventory-storage mechanism only, the Secret-based `cli/docs/rfc/0001`) into the workspace enhancements workflow, because the work is cross-repo (`cli/` + `opm-operator/`) and now also depends on enhancement [0001](../0001/)'s library-kernel rewrite.

## Documents

1. [01-problem.md](01-problem.md) — Why two disjoint inventory stores (CLI Secret vs operator CR) and two divergent render pipelines (CLI `pkg/render` vs library kernel) make the learner-to-operator path impossible and handoff unsafe
2. [02-design.md](02-design.md) — CR-backed inventory, full library-kernel adoption for render/match, CLI-side SSA apply, `spec.owner` marker, `opm operator install`, `opm instance handoff`
3. [03-decisions.md](03-decisions.md) — Append-only decision log (D1–D35) and Open Questions
4. [04-graduation.md](04-graduation.md) — draft → accepted, accepted → implemented gates
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, Alternatives not taken
6. [06-operational.md](06-operational.md) — Observability, semver impact, deprecation, rollback, cross-repo coordination

Pure-CUE / Go-shape sketches live under [`schemas/`](schemas/).

## Scope

### In scope

- CLI release inventory moves from the Secret `opm.<releaseName>.<releaseID>` to the operator's `ModuleInstance` CR; inventory stored in `status.inventory` (D1). The CLI writes a strict subset of status (`inventory`, `instanceUUID`, `lastApplied*`, a single `Ready` condition) — D2.
- CLI deletes its own render/match pipeline and renders through the `library` kernel end-to-end (D9). Match/materialize behaviour is whatever 0001's kernel ships; the CLI does not carry a second implementation.
- CLI resolves its `#Platform` by precedence — `--platform` flag > cluster `Platform` CR > local/embedded default — and materializes it via the same kernel calls the operator uses; `handoff` forces the cluster CR (D11). The `Platform` carries no owner marker; the operator always owns the singleton, and the CLI writes an un-owned `cluster` Platform write-if-absent in solo clusters (D12).
- CLI keeps its own apply step (client-go server-side apply, field manager `opm-cli`); duplication of the operator's apply semantics is accepted, SSA is mandatory on both sides (D10).
- CLI imports `library` only — **not** `opm-operator` (D13, supersedes D4). The CLI handles the `ModuleInstance` CR as `unstructured`, avoiding controller-runtime + Flux, and keeps its own local inventory logic (entry-building, identity, stale set, digest) rather than importing it from a shared package — D31 reverted D13's original plan to home that logic in `library`; see D31 in [`03-decisions.md`](03-decisions.md) for why the shared-package premise didn't hold up. The CLI's apply/prune is a one-shot design borrowing the operator's reconcile concepts, not its machinery. See [`research/findings.md`](research/findings.md) for the dependency analysis.
- No backwards-compatibility or deprecation burden — the CLI has a single user; refactor freely (D14). The CUE v0.16.1 → v0.17.1 bump (retargeted off the alpha and relocated into C1 by D36) is accepted; D8's Secret-format fallback window collapses to a one-time migration.
- `spec.owner: cli | operator` marker on `ModuleInstance`; the operator skips reconcile of CLI-owned CRs with a `ManagedExternally` condition (D3). Operator-side change, documented here.
- `opm operator install [--crds-only]`, `opm operator uninstall` (D5; noun-first surface per D32, uninstall semantics per D34); CRDs become a hard prerequisite for every CLI apply (gate lands with the CR-inventory slice — D33); one embedded operator artifact (`dist/install.yaml`) with a `--version` fetch fallback (D35).
- `spec.module` contents when applying from a local path vs a published reference (D6).
- `opm instance handoff` with digest verification — forward-only, CLI → operator (D7); reverse mode is out of scope (D16).
- Rename the CLI Go module `github.com/opmodel/cli` → `github.com/open-platform-model/cli`, aligning it with `library` and `opm-operator`; a mechanical prep slice landed before the `library` edge is added (D15).
- Both a local/embedded Platform and the in-cluster `Platform` CR are first-class render sources; OPM stays usable without cluster-admin on every non-`handoff` path (D17).
- Migration of existing Secret inventories to CR inventories on apply, with a one-release Secret read-fallback window (D8).

### Out of scope

- **Apply-engine unification.** The CLI keeps its own SSA path; the operator keeps Flux `ResourceManager`. Only render/match is unified (via the kernel), not apply (D10). Sharing the apply engine is future work.
- **Reverse handoff (`--to cli`).** Handoff is forward-only (CLI → operator); flipping a reconciled CR back to CLI ownership — with its own operator-status cleanup and relinquish-race design — is deferred (D16).
- **`Release` / `BundleRelease` handoff.** This enhancement covers `ModuleInstance` only; the Flux-sourced CRs have no CLI-side equivalent.
- **Rollback / `status.history`.** Remains operator-only; the CLI does not gain rollback here.
- **The library-kernel match/materialize redesign itself.** That is enhancement [0001](../0001/); 0006 *consumes* it. 0006 does not modify `core/` or the kernel's match algorithm.
- **Operator lifecycle beyond install/uninstall** (upgrade orchestration, HA) — `opm operator install` applies manifests; it is not a package manager.

## Relationship to 0001

0006 is a downstream consumer of [0001](../0001/). 0001 rewrites the kernel's match/materialize (path-keyed registry, SemVer FQNs, always-unify) and the operator already adopted it. D9 (CLI adopts the library kernel) means the CLI's render path cannot land on the 0001 model until 0001's `library` slice ships. The inventory/CR/handoff strand (D1–D8) does **not** depend on 0001 and can proceed independently — see OQ5 on whether the two strands ship as separate waves.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `/CLAUDE.md` (workspace root) | Cross-repo routing + area vocabulary the `area` / `affects` fields validate against. |
| `cli/docs/rfc/0007-moduleinstance-cr-inventory-and-operator-handoff.md` | Seed design for D1–D8 (CR inventory, `spec.owner`, `opm install`, handoff, Secret migration). Promoted into this entry. |
| `cli/docs/rfc/0001-release-inventory.md` | The Secret-based inventory design whose storage mechanism this supersedes. |
| `cli/CLAUDE.md`, `cli/CONSTITUTION.md` | CLI repo principles governing the slices that land in `cli/`. |
| `cli/internal/inventory/`, `cli/pkg/inventory/`, `cli/pkg/ownership/` | Secret marshaling (retired by the CR-inventory slice) + entry identity/stale-set/rename-safety/collision-check (kept in place, ported onto the CR — D31) + ownership guard. |
| `cli/pkg/render/`, `cli/pkg/loader/` | The CLI's own render/match pipeline — deleted by the kernel-adoption slice (D9). |
| `cli/internal/workflow/apply/apply.go` | Apply workflow — rewired to render via kernel, write CR status, keep CLI-side SSA (D10). |
| `cli/internal/kubernetes/` | CLI apply/delete against the cluster; the SSA path that stays CLI-owned. |
| `opm-operator/CLAUDE.md`, `opm-operator/CONSTITUTION.md` | Operator repo principles governing the `cli-ownership-marker` slice. |
| `opm-operator/api/v1alpha1/moduleinstance_types.go`, `common_types.go` | `ModuleInstance` + `Inventory` + `InventoryEntry` types — the CRD serialization shape the CLI's CR fields must agree with (D3 adds `spec.owner` here). Not imported by the CLI (D13) — the CLI reads/writes the CR as `unstructured`. |
| `opm-operator/internal/inventory/` | Stays in place, unchanged by this enhancement (D31 reverted the D13/D4 plans to migrate or promote it elsewhere). |
| `opm-operator/dist/install.yaml` | The one install artefact the CLI embeds for `opm operator install` (D5/D35; CRDs are a filtered subset — `config/crd/bases/` is not separately embedded). |
| `opm-operator/openspec/changes/archive/2026-04-12-01-cli-dependency-and-inventory-bridge/` | The original copy of CLI inventory code into the operator; historical context only — D31 keeps both actors' inventory code independent rather than sharing in either direction. |
| `library/opm/` (kernel) | The CLI imports `library` for the kernel only (D9) — no inventory package (D31 reverted `library/opm/inventory`). |
| `enhancements/0001/` | The library-kernel redesign D9 consumes; gates the kernel-adoption strand. |

## Deviations from Design

None at this stage. Update when implementation lands.
