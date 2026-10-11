# Source note: seed-platform-reconciliation

This is a seed. It records behaviour the operator ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-reconciliation`. Full seed (15 requirements). Written 2026-10-11 from the operator at commit `cb97ffb0`.

## Sources

All read at the commit named. `P` is `opm-operator` `openspec/specs/platform-reconciler/spec.md`; `G` is `opm-operator` `openspec/specs/platform-gated-rendering/spec.md`. Code paths are in `opm-operator`. The requirement text is rewritten at intent level: no Go symbol, field path or file path. Condition reasons and published Kubernetes kinds are named, as `seed-platform-module-generation` does.

| Requirement here | Source requirement in the spec | Code read |
| --- | --- | --- |
| Only the cluster Platform is reconciled | P "Generate and build the singleton Platform on reconcile" (the `cluster` sentence and the "Non-cluster object ignored" scenario) | `internal/controller/platform_controller.go:136-140` |
| An unchanged package is not rebuilt | P same requirement (the skip sentence and "An unchanged tuple regenerates nothing") | `platform_controller.go:193-218` (identity equal and `dirExists`) |
| A failure records the observed generation | P "Observed generation is recorded on failure" | `platform_controller.go:440-467` (`failReconcile`) |
| A failed build requeues on a bounded interval | P "Build failures requeue on a bounded interval" (first sentence group and two scenarios) | `platform_controller.go:440-467`; `internal/status/conditions.go:297-299` (`MarkStalled`), `:311-315` (`MarkReadyWithReason` clears Stalled) |
| A registry failure does not outlive its reconcile | P same requirement (the module-file source sentence) and its scenario "A transient registry failure does not outlive its reconcile" | `platform_controller.go:409-427` (`modFiles`) |
| Transient failures retry faster than other failures | P "Transient failures retry faster than semantic failures" | `platform_controller.go:470-481` (`isTransientFailure`), `:71` (`transientRecheckInterval`), `internal/reconcile/backoff.go:17` |
| Failure events fire on transition only | P "Failure events are emitted on transition, not every recheck" | `platform_controller.go:448-461` |
| The skew policy is recorded with the package | P "The skew policy is recorded with the generated module" | `internal/platform/store.go:42-45`, `internal/platform/skew.go:17-22` (`ResolveSkewPolicy`), `platform_controller.go:290-295` |
| One generated platform is held for readers | P "Single-slot identity-keyed store for concurrent read" (the slot, the key and the lease; not the on-disk retention) | `internal/platform/store.go:63-142` |
| Deleting the Platform clears the held platform | P "Clear the store on Platform deletion" | `platform_controller.go:142-158`, `store.go:160-168` |
| A ModuleInstance renders against the held platform | G "ModuleRelease renders through the kernel against the generated platform" | `internal/render/kernel_module_renderer.go:106-140` |
| No platform blocks an instance without side effects | G "Block ModuleRelease when no platform is generated" | `kernel_module_renderer.go:111-115` (the lease is taken first, before any registry access: "Gate before any registry I/O"), `internal/reconcile/moduleinstance.go:1596-1621` (`classifyRenderError`), `:465-479` |
| A Platform change re-enqueues consuming instances | G "Re-enqueue ModuleInstances when the platform becomes ready" (first paragraph and scenarios) | `internal/controller/moduleinstance_controller.go:307-376` (`platformConsumedFieldsChanged`) |
| Only operator-managed instances are re-enqueued | G same requirement (the owner and suspend paragraph) | `moduleinstance_controller.go:378-415` |
| A restart recovers instances blocked on no platform | G same requirement (the operator-version sentence and its scenario) | `moduleinstance_controller.go:331-335, 357` |

## Left out

- P "Reconciler stamps status.operatorVersion on every outcome": held by `seed-platform-module-generation` ("A clean build sets Ready"), after the correction of DECISIONS 2026-10-11 09:50: the stamp is stated by no 0021 requirement, so it is not left to 0021. Requirement 15 here stays: it is the instance gate's reaction to a status write that carries the new operator version.
- P "Generate and build the singleton Platform on reconcile" (generation, the two-input tuple, the wake on a claim change), "Subscription mapping and build failures", and the Ready=True, BuildFailed, GenerateFailed and last-good rules of "Surface build outcome on status": held by `seed-platform-module-generation`. This seed keeps the requeue and retry class of a failure and the skip of an unchanged package.
- P "Surface build outcome on status": the gate reasons ContractCollisions, OverSubscribedContracts and ComparablePredicates, their precedence, the message content and the ContractsFulfilled report. The seed `platform-contract-gates` (row 16) holds them. The failure rules here (requeue, class, event on transition, observed generation) apply to a refusal too, because the code sends a refusal through the same failure path. They are stated once, here, as general rules. The gate seed needs only point to them.
- P "Single-slot identity-keyed store": the identity derivation and the retention of superseded directories (`seed-platform-module-generation`: "Platform status names the package and its registry", "Packages are written whole and kept while held"); the lease itself, the report of which identities are leased, the exactness of lease counts and safety under concurrent reads (process internals and a race test; the observable part, that a running render finishes on the platform it started with, stays in requirements 9, 10 and 11).
- P "Transient failures retry faster ...": the sentence that the class comes from the type of the cause, never from message text. It is a rule of the code's method; the observable part is the interval for each cause.
- P "Generate and build ...": "No second, derived copy of the platform exists". It is a negative design statement; no consumer observes it.
- P "Build failures requeue ...": the sentence that a module-file source injected into the reconciler is used as given. It is a test seam.
- G first requirement: that the render is "the single-build render". The render rules (promotion, the skew comparison, matching, refusal) are held by `seed-single-build-render`. The record's skew policy reaches that render; this seed states only that the record carries it.
- The SkewRefused, RenderFailed and ResolutionFailed classification of a refused render, and the ModulePackage reconcile loop (it blocks on PlatformNotReady and uses the same watch predicate). The map (T4.1b, "Left out") has no capability for either, and the classification sits in `modulepackage-kernel-rendering`, where 0006 D9 and 0021 touch it (DECISIONS 2026-10-11 06:40 (3)).
- The TransformerRegistration reconciler's deferral on PlatformNotReady: `seed-transformer-registration` and `registration-acceptance` hold the claim side.
- The instance's pre-render skip: a reconcile whose render input key is unchanged skips the render, and the key holds the Platform's package identity and skew policy (`internal/reconcile/inputs.go:55-77`). No spec of the two read states it, so a change of pin set or policy re-rendering an instance is stated here only through the re-enqueue. A spec for the skip is a candidate for the operator render-path capability the map leaves out.
- A held record that cannot read its own inventory is treated as stale and regenerated (`platform_controller.go:204-207`). It is a robustness detail, and the failure it ends in is already in `seed-platform-module-generation` ("An unreadable inventory fails the build").
- Live entries: enhancement 0026 changes what a platform is built from (`#ResolvedPlatform`, one resolution per distinct input) and so may touch the identity and the held record; it MODIFIES the generation seed first. Nothing here is a 0026 target as written. Enhancement 0027 consumes the instance gate; no requirement here is its target.

## Code against spec (the code wins)

- `platform-reconciler` says deletion clears the store. The code also clears it while the Platform carries a deletion timestamp (`platform_controller.go:153-158`). The seed states both, with a scenario.
- `platform-gated-rendering` says a blocked instance requeues. The code marks it not ready, not stalled, and retries on the exponential backoff that starts at 5 seconds and stops growing at 5 minutes (`internal/reconcile/backoff.go:7-30`, `moduleinstance.go:944-949`), not on the 30-minute stalled recheck. The seed says "bounded retry backoff".
- The operator spec says the owner is "absent, empty or `operator`". The seed says "absent or `operator`": the API server rejects an empty owner, so a stored instance never has one (`opm-operator` `config/crd/bases/opmodel.dev_moduleinstances.yaml:117-138` at `cb97ffb0`, description and enum `cli`, `operator`; `seed-instance-ownership` requirement 1 holds that rule). The code excludes only an instance owned by the CLI (`moduleinstance_controller.go:386-391`). The two texts differ in the word "empty" only; no behaviour differs. Corrected in the consolidation pass T4.3c.
- A comment in `moduleinstance.go:465-470` says the restart edge is missed because the regeneration emits no status event. The watch predicate wakes on the operator version (`moduleinstance_controller.go:357`), and the spec's scenario says so. The seed follows the predicate and the spec.
- The short and the long interval have no number in the spec. The code uses one minute (`platform_controller.go:71`) and 30 minutes (`backoff.go:17`). The seed keeps the words "short" and "long stalled-recheck".

## Not verified

- No test suite was run.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- Fact error fixed: requirement "Only operator-managed instances are re-enqueued" said the owner may be "absent, empty or `operator`". The API server rejects an empty owner (`opm-operator` `config/crd/bases/opmodel.dev_moduleinstances.yaml:117-138` at `cb97ffb0`: an absent or `operator` owner is operator-managed, the enum is `cli` and `operator`), so the text reads "absent or `operator`" (`seed-instance-ownership` requirement 1 holds the rule).
- The scenario "A claim change replaces the held record" no longer says a claim activates: the new package identity on a claim change is `platform-module-generation`'s ("Platform status names the package and its registry"). The scenario "A stalled Platform reports its generation" no longer names the reasons BuildFailed and GenerateFailed, which `platform-module-generation` holds.
