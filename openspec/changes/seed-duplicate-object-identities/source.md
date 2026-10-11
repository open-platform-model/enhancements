# Source note: seed-duplicate-object-identities

This is a seed. It records behaviour the repos ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `duplicate-object-identities`. Full seed (6 requirements). Written 2026-10-11 from `library` at commit `a87fdda`, `cli` at `09b0b812` and `opm-operator` at `cb97ffb0`. The enhancement decisions behind it are 0015:D12 (both registrations get one instance-derived name) and 0015:D15 (the duplicate check, refused before apply).

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, field path, condition reason, package path or file path.

| Requirement here | Source requirement in the repo's spec | Code read |
| --- | --- | --- |
| Identity is group, kind, namespace and name | `library` `openspec/specs/duplicate-object-identities/spec.md` at `a87fdda`, first requirement, first sentences and the version, core-group and group scenarios | `opm/k8s/object/duplicates.go` (`keyOf`, `groupOf`); test `TestDuplicates_OneNameInTwoNamespacesStaysDistinct` for the namespace scenario |
| Each shared identity is reported with its producers | same file, first requirement, the rows, the order and the producer sentences and the four row scenarios | `opm/k8s/object/duplicates.go` (`Duplicates`, `Producer`) |
| A non-object value is skipped | same file, "Objects without an apply identity are skipped" | `opm/k8s/object/duplicates.go` (`identityOf`) |
| The refusal is worded once | same file, "The refusal is worded once" | `opm/k8s/object/duplicates.go` (`DuplicateIdentitiesError.Error`, `joinProducers`, `versionLabel`) |
| The check runs after the render | same file, "The kernel stays neutral", first sentence of the render half and the last sentence | `opm/kernel/render_test.go:427` (`TestRender_DuplicateObjectIdentitiesStillSucceed`) |
| A runtime refuses a duplicate before apply | `cli` `openspec/specs/kernel-render/spec.md`, "The CLI SHALL render instances exclusively through ...", second paragraph; `opm-operator` `openspec/specs/kernel-module-renderer/spec.md`, "Adapt compiled output to operator resources"; `opm-operator` `openspec/specs/modulepackage-kernel-rendering/spec.md`, scenario "Duplicate identities are a refusal of their own" | cli `internal/workflow/render/render.go:302`, `validation.go:60`; operator `internal/render/kernel_module_renderer.go:222`, `internal/reconcile/resolution.go:120-127`, `internal/reconcile/moduleinstance.go:1627-1629`, `internal/reconcile/modulepackage.go:735-738` |

## Left out

- The package that holds the check (`opm/k8s/object`), that the kernel does not import it, and the statement that the helper tier never holds it: 0012 owns the tier, its fence and where the check lives (0012:D2 item 5, R7, with R1). The library spec cites ADR-011 item 9 for the same placement. Also `library` `helper-packages`, scenario "Duplicate-identity helper landing place".
- "`Compiled` SHALL gain no identity fields; the check reads the identity off `Compiled.Value`": a library-internal shape no consumer observes.
- "The exported identity type SHALL keep its fields": an API shape, not behaviour.
- How the operator and the CLI turn a refused render into an exit code, an event or a render-failed header: only the refusal and what is built or applied are kept. The condition reason name is left out (V19 excludes it); the scenario says "a reason that is neither a render failure nor a platform problem", which the code comment at `opm-operator` `internal/status/conditions.go:58-64` states.
- Anything about the render itself (matching, staging, diagnostics): `seed-single-build-render` holds the render-side rules.
- Apply, deletion, inventory, stale sets and pruning: 0012 and the cli and operator apply specs own them.

## Disagreements between spec and code

- The library spec's "The refusal is worded once" says the message names each identity "one identity per line". The code also opens the message with a header line that counts the objects and the identities (`duplicates.go`, `Error`). The cli spec and code rely on that header. The seed states the header; the code wins.
- The library spec says the check is "opt-in" in its Purpose. Both first-party runtimes run it on every render (cli `render.go:302`, operator `kernel_module_renderer.go:222`). The seed keeps "opt-in" for the render and states the runtimes' obligation in the last requirement.
