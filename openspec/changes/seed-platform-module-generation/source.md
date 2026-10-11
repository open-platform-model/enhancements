# Source note: seed-platform-module-generation

This is a seed. It records behaviour the library and the operator ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-module-generation`. Full seed (13 requirements). Written 2026-10-11 from `library` at commit `a87fddaa` and `opm-operator` at commit `cb97ffb0`.

## Sources

All read at the commits named. The requirement text is rewritten at intent level: no Go symbol, file path, flag or field path. Four specs feed the seed: `L` is `library` `openspec/specs/platform-module-generation/spec.md`; `O` is `opm-operator` `openspec/specs/platform-module-generation/spec.md`; `R` is `opm-operator` `openspec/specs/registration-driven-regeneration/spec.md`; `C` is `opm-operator` `openspec/specs/platform-crd/spec.md`.

| Requirement here | Source requirement in the spec | Code read |
| --- | --- | --- |
| Generation is pure and deterministic | L "Generation is pure and deterministic" | `opm/helper/platformmodule/generate.go:92` (`Generate`) |
| An entry's expected version is stamped bare | L "A registry entry stamps its version bare"; O "The CR's version is stamped as the expected-version tripwire" (the stamp only; merged) | `generate.go:192` (`modversion.Bare`) |
| Core is pinned at the kernel's verified release | L "The core pin defaults to the kernel's verified release"; O "The reconciler generates a platform module from the CR" (core-pin sentences and the "Core pin follows the library" scenario) | `generate.go:75` (`Roots`) |
| The dependency closure comes from published module files | L "The dependency closure is derived from published module files" and "Registry access is caller-configured" (merged); O "The reconciler generates a platform module from the CR" (closure sentence, transitive-dependency scenario) | `opm/helper/platformmodule/closure.go:71` (`Closure`) |
| The registry unites authored subscriptions and active claims | O "The reconciler generates a platform module from the CR" (the two-path sentences and four scenarios) | `internal/controller/platform_controller.go:520` (`platformEntries`) |
| The package depends on spec and active claims | R "The generated package is a function of the platform spec and the active-claim set"; O (deterministic regeneration, claimless platform) | `platform_controller.go:327` (`activeClaims`), `:157-190`. The waking event is discarded: `mapClaimToPlatform` returns the singleton whatever claim changed (`:570-572`), and the tuple is read from current state (`:172-183`) |
| Regeneration follows every input and coalesces bursts | R "Regeneration is edge-triggered by every input" | `platform_controller.go:554-565`, `:605` (`claimContributionPredicate`), the no-op skip at `:193-217`. The burst scenario: one wake-up per claim reads every active claim (`:172-183`) and the later ones hold the identity already held, so they skip (`:198-217`); the operator test `internal/controller/platform_claims_test.go:458-505` pins it |
| Platform status names the package and its registry | R "A generated package is identified by its inputs" and "The effective registry is readable from the Platform" (merged) | `internal/platform/identity.go:56`, `api/v1alpha1/platform_types.go:169,180`, `platform_controller.go:366`, `internal/reconcile/warnings.go:84`. A render writes the identity to the reconcile log (`internal/reconcile/warnings.go:80-88`, `log.Info`) and nothing else records it in plain form. The render input key also carries it into the digest in `status.lastAppliedInputs` (`internal/reconcile/inputs.go:24-33`, `:48`); that digest is read only by the render's skip switch (`internal/reconcile/moduleinstance.go:1771-1786`, `internal/reconcile/modulepackage.go:480`), which 15:45 keeps out of the seeds, so the requirement does not state it. The status source values are Subscription and Registration (`api/v1alpha1/platform_types.go:106-114`) |
| The generated module is validated by building it | O "The generated module is validated by building it"; L "The emitted module builds through the kernel"; C "PlatformStatus carries conditions and observedGeneration" (Ready reasons, observed generation, operator version) | `platform_controller.go:258` (`AcquirePlatformFromDir`), `:253-283`, `:440` (`failReconcile`) |
| Packages are written whole and kept while held | O "The generated module lives in a per-identity directory and is swapped whole"; R "A package stays readable while a render holds it" | `internal/platform/layout.go:60,109,136`, `cmd/main.go:325`, `platform_controller.go:296-298`. A failed write removes its staging directory and never leaves a package directory (`layout.go:60-82`); the prune runs only after a package is recorded (`platform_controller.go:296-298`), and the no-op skip returns before it (`:198-217`) |
| Generated files stay in a local owned directory | L "Files are written into a caller-owned directory"; O "The generated module is build-local and never published" | `opm/helper/platformmodule/write.go:14` (`WriteTo`) |
| The Platform is a cluster singleton | C "Cluster-scoped singleton Platform resource" | `api/v1alpha1/platform_types.go:230-232` |
| The Platform spec names type and pinned subscriptions | C "PlatformSpec projects core #Platform" and "Subscription shape" (merged) | `api/v1alpha1/platform_types.go:31-97`. No CRD default exists for the enable flag or the skew policy: an omitted enable flag resolves to true in the generator input (`platform_controller.go:530`) and an omitted skew policy to Warn (`internal/platform/skew.go:17-22`) |

## Left out

- L "Registry access is caller-configured": the test-shaped sentence (a test can supply a fixture graph) and the rule that the helper reads no environment as a matter of its API. The consumer-visible part, that resolution follows the caller's settings, is in the closure requirement.
- L "The core pin ...": the statement that no option or option type exists in the package. It describes a Go API shape, not behaviour.
- L closure: honouring cancellation. It is a property of the Go call, not of the platform.
- L "Files are written ...": the no-lifecycle clause is kept; nothing else is left out.
- O "The reconciler generates a platform module from the CR": the fixed module path (`opmodel.dev/platforms/cluster@v0`, `platform_controller.go:63`) is an internal coordinate; only "the reserved platforms namespace stays unpublished" is kept. The clause that the content is byte-identical to the previous in-tree generator, and the attribution header, describe a migration that is done.
- O "The Platform CR API is unchanged": a statement of the scope of one past change. `C` states the shape.
- O and R: the directory name form (`gen-<generation>`, a digest of the claim list), the default of the platform directory flag and the volume it sits on. They are mechanism.
- O "The generated module is validated by building it": the reasons `ContractCollisions`, `OverSubscribedContracts` and `ComparablePredicates`, the `ContractsFulfilled` condition and the retired materialize-era reasons. The first three belong to the inventory gate (`opm-operator` `platform-inventory-gate`), `ContractsFulfilled` to the same spec; neither is in this seed's four sources. The seed says only that a refusal carries the gate's reason. The second map pass (T4.1b) lists the gate.
- C "Platform registered in the scheme without a reconciler": stale. The code has a reconciler (`platform_controller.go:133`). The code wins and the seed holds no such requirement.
- C "PlatformSpec projects core #Platform": what `skewPolicy` does to a render (warn, or refuse before evaluation) lives in `platform-reconciler` and `platform-gated-rendering` and is not seeded here. The seed keeps the field, its two values and its default, and that it stays outside the generated module.
- C "PlatformStatus ...": the Operator print column (a display detail), and the use of the operator version as the CLI's version ceiling (enhancement 0021 owns that behaviour). The stamp of the operator's version on Platform status is kept: no 0021 requirement states it (DECISIONS 2026-10-11 09:50).
- O "The CR's version is stamped as the expected-version tripwire": the sentence that a pin disagreeing with the stamped version fails the build at a path naming the entry, with its scenario. The seed `platform-registry` states that conflict ("Entry identity is derived"). The seed here keeps the bare stamp and that the stamp does not select a build.
- C "Subscription shape": the stored legacy singleton scenario, which describes a one-time schema change. The surviving behaviour, a subscription without a version failing with a named path, is a scenario of the spec requirement.
- Behaviour a live entry owns, kept out: the authored `#Platform` of admission entries with a floor and a ceiling, the resolved-platform rename, generation once per distinct resolution, and the module-less build per admitted major (enhancement 0026, D2, D3 and D9). The seed holds the shipped behaviour that those decisions will modify.

## Code against spec (the code wins)

- `platform-crd` says the types are registered "without a reconciler". The code has one (`platform_controller.go:133`). The seed omits the requirement.
- `registration-driven-regeneration` says regeneration wakes "when any `TransformerRegistration` changes". The code wakes only on a claim event that can move the active set (`platform_controller.go:598-622`). The seed follows the code, and a scenario covers it.
- `platform-crd` leaves open whether the subscription version is required at admission. The code requires it with a minimum length of one (`platform_types.go:93-97`). The seed says it is required.
- `library` lists the invalid inputs without the module path. The code refuses an empty module path too (`generate.go:99-100`). The seed lists it.
- `registration-driven-regeneration` says every render "reports" the identity of its package. The code writes it to the reconcile log (`internal/reconcile/warnings.go:80-88`). The seed says a render records it.
- `library` names the default core as the kernel's default schema module. The code reads the default schema version (`generate.go:77`). No behaviour differs.

## Not verified

- That a key which disagrees with its imported catalog's declared path fails the build at the entry. Read in T4.9 (not run): `core` `f3b7ecd` `src/platform.cue:180` binds the key into the embedded catalog's module path (`#catalog: metadata: modulePath: Path`), and the comment at `:176-179` calls the drift "a build conflict naming the entry". The scenario stays; it was not run with `cue`.
