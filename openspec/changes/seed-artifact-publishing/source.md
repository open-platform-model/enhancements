# Source note: seed-artifact-publishing

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `artifact-publishing`. Full seed (21 requirements). Written 2026-10-11 from the CLI at commit `09b0b812`, with the library at `a87fdda` and core at `f3b7ecd` read where the CLI calls them.

## Sources

All read at the commits named. The requirement text is rewritten at intent level: no Go symbol, flag, file path or condition reason. Code lines are in the CLI, paths under `internal/`.

The repo spec is `cli` `openspec/specs/artifact-publishing/spec.md`, nine requirements. Its long requirements are split here because a requirement holds at most 500 characters of text. The nine map as follows.

| Spec requirement | Requirements here |
| --- | --- |
| "One pipeline, two entry points" | "One pipeline serves module and catalog publish"; "Coordinates are read, never composed"; "The pushed bytes are the artifact directory"; "Publish refuses a module the kernel refuses" |
| "Gates and refusal catalog" | "Every evaluable gate runs in a fixed order"; "A refusal has one fixed shape"; "Identity must be concrete and consistent"; "The module configuration must agree with the artifact"; "Namespace gates bind owned domains only"; "A published version is never replaced" |
| "Local overrides are never honored; modules may waive the gate" | "Local overrides are ignored and refused" |
| "`--version` fills or asserts, never overwrites" | "The version option fills or asserts" |
| "The plan is the dry run" | "The plan is the dry run" |
| "Exit codes" | "Exit codes follow the cause"; "Registry failures are named by their cause"; "Some registry answers read as not found"; "An unconfigured registry is its own refusal" |
| "The compatibility gate" | "The compatibility gate compares against history"; "A compatibility refusal names its member and predecessor"; "Dev builds and prerelease lines are exempt, visibly" |
| "Member and posture gates" | Only the one clause that is not held elsewhere: "the member and posture gates cover every level; the alpha exemption belongs to the compatibility gate alone", inside "A compatibility refusal names its member and predecessor". See "Left out". |
| "Connectivity across the member walk" | "A connectivity failure mid-walk is never a GO" |

| Requirement here | Code read |
| --- | --- |
| One pipeline serves module and catalog publish | `publish/gates.go:41-136` (`Run`), `publish/identity.go:21-51` (`conformIdentity`: unify with `#IdentityPackage`, keep CUE's error), `publish/load.go:44-66` (load error verbatim), `publish/registry.go:17-27` (`NewRegistryClient`: the resolver that reads use), `publish/registry.go:68-110` (`Push`) |
| Coordinates are read, never composed | `publish/gates.go:84-89` (repository and major cut from the declared path), `publish/identity.go:80-127` (tag from the declared version), `publish/publish.go` doc comment (never edits the artifact to match a coordinate) |
| The pushed bytes are the artifact directory | `publish/registry.go:68-105` (`modzip.CreateFromDir` of the plan's directory; `SetIdentityVersion` before the zip is the only write); `Run` never writes (`publish/gates.go:27-30`) |
| Every evaluable gate runs in a fixed order | `publish/gates.go:52-135` (the order of the calls); no-module-configuration and load short-circuits at `:55-58`, `:63-67`; one cause, one refusal at `publish/kernel_gate.go:18-20` and `publish/identity.go:28-36` |
| A refusal has one fixed shape | `publish/refusal.go:9-48`; `cmdutil/publish.go:143-154` (`PrintRefusals`) |
| Identity must be concrete and consistent | `publish/identity.go:57-73` (tristate, default counts concrete), `:80-150`, `publish/gates.go:194-234` (`gateDerivation`) |
| The module configuration must agree with the artifact | `publish/gates.go:52-58`, `:138-153` (no module configuration; points to init), `:155-173` (`gateSourceSelf`), `:175-192` (`gateCueModAgreement`), `:345-367` (`gatePackageName`, modules only) |
| Namespace gates bind owned domains only | `publish/gates.go:22-25` (shapes), `:260-287` (`gateNamespace`), `:289-339` (`gateKindSegment`) |
| Local overrides are ignored and refused | `publish/gates.go:369-412` (`gateOverride`: catalog no waiver, module waivable), `:414-463` (replacements beside the pinned version) |
| The version option fills or asserts | `publish/identity.go:80-127` (`resolveVersion`; the refusal of an open version with no option names `opm <kind> version set` and `opm <kind> publish --version` at `:124`), `publish/registry.go:72-76` (fill written at push), `cmdutil/publish.go:31-37` |
| A published version is never replaced | `publish/registry.go:29-61` (`gateAlreadyPublished`), `publish/gates.go:122-127` (also in a dry run) |
| The plan is the dry run | `publish/plan.go:35-93` (`Render`: rows, GO, INCOMPLETE, REFUSED), `cmdutil/publish.go:96-136` (plan before push; dry run returns before `Push`) |
| Publish refuses a module the kernel refuses | `publish/kernel_gate.go:21-43` (modules only; skipped while an identity field is open or absent), `publish/vet.go:32-` (`VetChecks` calls the same gate; no scenario here says so, T4.R22) |
| The compatibility gate compares against history | `publish/compat.go:50-65` (`gateCompat`; a dev tag returns at `:54-58` and a release-prerelease tag runs an empty walk at `:60`, `:147-150`, so each scenario of the requirement names a stable tag, "A dev build is never the baseline" included: a release-prerelease tag compares nothing, T4.R33), `:133-158` (alpha and transformers excluded), `:171-187` (`predecessorVersions`: below the tag, same major, dev excluded, newest first), `:75-125` (`compatScan`: first member found, remainder new) |
| A compatibility refusal names its member and predecessor | `publish/compat.go:464-489` (`compatRefusal`), `publish/catalog_gates.go:36-108` (member and posture gates run on every member, alpha included) |
| Dev builds and prerelease lines are exempt, visibly | `publish/compat.go:54-58`, `:189-216` (`IsDevTag`, `isReleasePrerelease`), `:143-150` (every beta and GA member of a release-prerelease tag counts as exempt, whatever the history holds, so a prerelease tag after a stable tag is not compared: `:60`, `:147-150`, `:214-216`; the "first stable tag" scenario holds because the tag then has no prerelease), `publish/plan.go:95-114` (`dev-exempt` row, prerelease-exempt count) |
| Exit codes follow the cause | `cmdutil/publish.go:96-136`, `:173-196` (`publishError`), `exit/exit.go:8-14`, `publish/publish.go:234-300` |
| Registry failures are named by their cause | `publish/publish.go:234-300` (`ConnectivityError`, `RegistryError`, `RegistryFailure`), `cuemod/connectivity.go:27-70` (typed classification), `config/registry_login.go:16-22` (login hint with the host) |
| Some registry answers read as not found | `cuemod/connectivity.go:43-65`; tests `publish/registryanswer_test.go:120-172` (403 lookup, token endpoint 401 on the lookup, token endpoint 403 on the push). The core-schema-fetch half rests on the repo spec and the code path `cmdutil/publish.go:162-167` (`CoreSchemaError`); no test of it was read |
| An unconfigured registry is its own refusal | `cmdutil/registry.go:18-26`, `config/kernel.go:27-70` |
| A connectivity failure mid-walk is never a GO | `publish/compat.go:232-260` (`loadPublishedPackage`), `:262-285`, `:304-314` (`unprovidedImport`), `publish/plan.go:75-93`; test `publish/compat_test.go:218-247` |

## Where spec and code differ

The code wins in each case.

- "Committed tree". The spec says the pushed bytes are "exactly the committed tree". The code zips the directory as it stands on disk (`registry.go:92`) and reads no version-control state. The requirement says "the artifact directory as it stands".
- Refusal shape. The spec says every refusal has all four parts and a runnable command. The code lets a part be empty (`refusal.go:17-26`), some refusals carry only a headline and CUE's error, and some actions are prose (`gates.go:190`). The requirement says "leaving a part out only where it adds nothing" and "as a runnable command where one exists".
- Gate order. The spec lists the gates without an order. The order in the requirement is the order of the calls in `Run`.
- "No partial verdict". The spec says a mid-walk transport failure renders no GO or REFUSED. The code prints INCOMPLETE when nothing was refused before the failure (`plan.go:84-86`, the tested case), and REFUSED when an earlier gate already refused (`plan.go:87-92`). The requirement says only that the plan never reads GO.
- No-registry message. The spec says it points to the config init command. The code points there when no config file exists, and otherwise says to add a registry field or replace the file (`config/kernel.go:62-66`). The requirement says "how to supply one".
- Kernel refusal. The spec says the refusal names the loader's failure class. The code puts the loader's error in the evidence row and picks the action from the loader's error class (`kernel_gate.go:36-57`). The requirement says "with the loader's own error".
- Compatibility action. The repo spec does not say what a compatibility refusal's action tells the author. The sentence in "A compatibility refusal names its member and predecessor" (make the change additive, or ship it alongside at a new API version) comes from the code alone (`publish/compat.go:487`).
- Absent field and the version option. The spec says the option cannot fill an absent field. The code returns early for an absent field (`identity.go:82-84`) and the refusal comes from the identity conformance check. The result is the same.

## Left out

- Tag major equals path major. The spec lists it as a gate and the code has one (`gates.go:236-258`). The tag is built from the declared version, and the rule that a version's major equals its path's major is held by the seed `artifact-identity` ("The version's major must equal the path's major"). One rule lives in one seed.
- The member gate and the trait posture gate, and what they refuse. The seed `catalog-member-gate` holds the gate and says a publishing tool unifies every member against it. The seed `contract-fulfilment` holds "A catalog cannot pin a trait's posture", which says publishing refuses an unstated or pinned posture. The spec's "Member and posture gates" requirement is covered there; only the clause about the alpha exemption stays here.
- The identity package shape, the one decomposition of a module path and the committed identity file. Held by `artifact-identity`. This seed states what the pipeline does with them.
- Publish gates a live entry owns. 0020 owns contract promotion, retirement and the tombstone record (publish refusals for a promotion that changes shape, an omitted beta or stable contract, a missing tombstone, an alpha tombstone, a replacement under the seasoning floor). 0022 owns the module-file block gate (warn, then refuse, a missing or stale block). 0017 owns the publish refusals for defaulted primitives and for blueprint narrowing and default marking. 0023 owns the signed claims attached to a published artifact. 0025 owns module traits. 0021 owns the rule that release tags and version-named registry tags of the organization's repositories keep their content; this seed holds only the CLI's refusal to publish over a held tag, which the CLI shipped in the publish pipeline.
- The comparison walk, level classification and the out-of-band catalog check. Held by the seed `catalog-compatibility` (row 29). The predecessor scan, the dev rule and the prerelease rule are in this seed because the repo spec states them as the publish gate and the code is in `publish/compat.go`, not in `internal/compat`. The seed `catalog-compatibility` should say that the out-of-band check agrees with them and not restate them.
- The version command that sets a version, scaffolding and registry login. Held by `module-authoring` (row 28).
- `opm module vet` as a command. It runs a subset of these gates (`publish/vet.go:32-`); no scenario or requirement here states it (T4.R22 removed the scenario line that did). It is not a mapped capability.
- Spec sentence "There SHALL be no separate check mode". The command that checks a published catalog out of band is another capability; the sentence is about the publish command.
- Spec sentence "No consumer contract is made on distinguishing refusal causes by code". It restates a lack of contract and has no behaviour to test.
- How a module is loaded and rendered by the kernel after publish. Held by `single-build-render` and the CLI render path; this seed states only that publish applies the kernel's loader.
- Library-internal placement: how the compat scan fetches and caches builds, the provenance scrub on the AST, the member walk over directories. No consumer observes them.
- The sentence that the CLI decides registry failures from the library's typed fetch classification, never from error text (repo spec "Connectivity across the member walk", marked `Source: 0021:D8:R12`). Live entry 0021 states typed fetch and resolution failures as its own requirement ("Fetch and resolution failures are typed"), and the mechanism is not observed by a consumer. It stays out of every seed.
- The refusal numbers (1 to 12) of the drafted messages and the text of each message. Intent only.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "Transformers and alpha members SHALL be exempt" and the sentence that the alpha exemption belongs to this gate alone no longer name the level rule; they say that transformers are exempt and that a member the comparison does not bind passes. The level rule is `primitive-keying`'s, applied by `catalog-compatibility`. The scenario "An alpha member is exempt only here" stays: it is the interplay of the gates in one publish.

sampled: 2026-10-11 18705155
