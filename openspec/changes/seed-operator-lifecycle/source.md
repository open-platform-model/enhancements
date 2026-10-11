# Source note: seed-operator-lifecycle

This is a seed. It records behaviour the CLI and the operator ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `operator-lifecycle`. Seed of 26 requirements (the consolidation pass T4.3c took it from 25 to 24; the fixes of review T4.R25 and T4.R36 added two). Written 2026-10-11 from the CLI at commit `09b0b812` and the operator at commit `cb97ffb0`. Rules that the converted entry 0021 states as its own requirements are not in the seed (DECISIONS.md 2026-10-11 13:30); see "Left out" and "For the owner at 0021's accept".

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, flag or file path. Scenario facts come from the same spec unless the last column says "code".

CLI spec: `cli` `openspec/specs/operator-lifecycle/spec.md` at `09b0b812` ("CLI spec"). Operator spec: `opm-operator` `openspec/specs/operator-version-identity/spec.md` at `cb97ffb0` ("operator spec").

| Requirement here | Source | Code read |
| --- | --- | --- |
| Install records the operator as a CLI-owned instance | CLI spec "Install deploys the operator module as a CLI-owned instance in two steps" (instance name, namespace, owner) | `internal/operator/names.go`; `internal/cmd/operator/install.go` |
| CRDs are served before the instance is recorded | same requirement (CRD step, then the instance apply, no Namespace outside the render) | `internal/operator/install.go` (CRD apply, wait, then the instance apply with namespace creation off) |
| The record lists every rendered object | same requirement (inventory, no refusal of the install's own objects); "Platform seeding and the opt-in user role stay install steps" (the role is not recorded) | `internal/operator/install.go` (role objects applied after the instance, never recorded) |
| A reinstall changes only what changed | same requirement, last sentence and two scenarios | `internal/operator/install.go` |
| Install refuses a non-CLI-owned record | "Install refuses an operator instance record that is not CLI-owned" | `internal/operator/plan_install.go` (`OwnedRecordError`, exit 2 in `internal/cmd/operator/install.go`) |
| Install resolves a selected version | "Install resolves another module version as the registry serves it" (selector, refusal before any cluster call, the report) | `internal/operator/plan_install.go` (`ResolveTarget`); `internal/cmd/operator/install.go` (`resolveBeforeCluster`) |
| Install refuses an unreadable operator version | The CLI spec states it only for the pin task; for install it is code | `internal/operator/opversion.go` (`VersionError`, exit 2 via `IsRefusal` in `internal/operator/target.go`). Code |
| Install refuses a render that disagrees with itself | same requirement (second and third bullets) | `internal/operator/target.go` (`CheckTarget`, `RenderedOperatorImage`); `internal/inventory/gates.go` (`CRDFieldFloor` is "spec.owner and status.inventory") |
| The operator's settings are recorded values | "The operator's settings are recorded instance values that survive reinstall" | `internal/operator/values.go` (`MergeValues`); `internal/operator/plan_install.go` (`RecordedValuesError`) |
| Install succeeds only after the rollout | "Install succeeds when the installed operator has rolled out"; the scenario "A failure after the CRD step is safe to re-run" is code | `internal/operator/install.go:32-41,105-110` (`RolloutError`), `:104-110` (the controller wait). Code for the last scenario, now its own requirement |
| A failure after the CRDs says to re-run | code only; the CLI spec has no such sentence. Split out of the rollout requirement (review T4.R25 finding 8) | `internal/cmd/operator/install.go:233-234` (`installError(withRerunHint(result, err))`), `:257-263` (`withRerunHint`: the hint is added when `result.CRDs > 0`, so after a failed step of `Install` once a CRD was applied: the CRD step, the opt-in role apply and the rollout (`internal/operator/install.go:55-110`); the instance apply prints its own error when it fails while writing (`internal/workflow/apply/apply.go:268, 316, 354`, `Printed: true`), and `internal/cmd/run.go:32` then prints nothing, so the hint is not shown; the Platform create at `internal/cmd/operator/install.go:246-249` gets no hint, and `internal/platform/cluster.go:108-109` returns its error as is; reviews T4.R36 finding 1, T4.R43 finding 1). Code |
| Platform seeding follows the rollout | "Platform seeding and the opt-in user role stay install steps" (Platform half, less the existing-Platform rule); the skip scenario is code | `internal/platform/cluster.go` (`createClusterPlatform`: plain create, field manager `opm-cli`); `internal/cmd/operator/install.go`. Code for the skip scenario. The RBAC-denied scenario states the warning's cause, not a permission name: `internal/platform/cluster.go:141-142` ("create denied by RBAC") |
| Catalog resolution precedes every cluster write | "Catalog resolution precedes every cluster write" | `internal/cmd/operator/install.go` (`resolveBeforeCluster`, `catalogResolveError`); `internal/platform/catalog.go` |
| (moved to `seed-platform-resolution` in T4.3c) The seeded subscription pins one catalog build | not in the CLI spec. Code and tests only | `internal/platform/catalog.go` (`selectCatalogVersion`: release mode takes the highest tag with no prerelease; prerelease mode takes the highest tag whose first prerelease identifier is not numeric; development builds carry a numeric first identifier); `internal/platform/catalog_test.go`. Code |
| Contradictory options are refused first | "Platform flags are validated before any lookup or cluster contact"; "Opt-in RBAC emission" (subject without role); "The operator's settings..." (values with CRDs-only); "user together with group" is code | `internal/cmd/operator/install.go` (`installFlags.validate`); `internal/operator/rbac.go` (`RBACOptions.Validate`). Code for user together with group |
| The opt-in user role stays an install step | "Opt-in RBAC emission via `--rbac`"; "Platform seeding and the opt-in user role stay install steps" (CRDs-only path) | `internal/operator/rbac.go` |
| Install refuses before it writes | "Install runs every refusing check before its first write" (the check list, the write order, no delete or patch outside the instance apply); the status-permission check moved to its own requirement | `internal/operator/plan_install.go` (`PlanInstall`: the wait for terminating objects `:187`; the ownership guard `:201`; all before `Install` in `internal/operator/install.go` applies the first CRD, which is why a refusal leaves the CRDs unchanged) |
| A missing status permission refuses install | "Install runs every refusing check before its first write" (the check list names the permission); exit 4, the named permission and the CRDs-only skip are code (split out for review T4.R25 and the ruling of the supervisor's 2026-10-11 row for T4.9b) | `internal/operator/plan_install.go:178-182` (`GateStatusRBAC` runs only when not CRDs-only; the error becomes `ExitPermissionDenied`, 4, `internal/exit/exit.go:11`); `internal/inventory/gates.go:131-158` (the message "patching moduleinstances/status is denied in namespace ..." names the permission). Code |
| Install judges every object it applies | "Install runs every refusing check before its first write" (the check runs on every install, with or without a record; an earlier manifest's objects judged like any other; the unlabelled-CRD scenarios) | `internal/operator/plan_install.go` (`inventory.Guard`) |
| An ownership refusal exits 2 and changes nothing | same requirement (exit 2, naming, no delete or rename advice, failed read) | `internal/operator/plan_install.go` (`GuardError`); `internal/cmd/operator/install.go` (`installError`) |
| Install waits out terminating objects | same requirement (last part) | `internal/operator/install.go:133-152` (`waitForTerminating`), `:154-175` (`terminatingObjects`); the scenarios say only that install waits and which object is named, not the progress line the code prints. |
| Uninstall keeps the record after a read failure | "Uninstall keeps the record when a recorded object could not be read" | `internal/workflow/apply/delete.go`; `internal/cmd/operator/uninstall.go` (exit 1) |
| Uninstall fails when the record cannot be deleted | "Uninstall fails when the instance record cannot be deleted" | `internal/workflow/apply/delete.go` (`RecordDeleteError`); `internal/cmdutil/k8s.go` (`ExitCodeFromK8sError`: 4, 3, 1) |
| Every CLI server-side apply uses one field manager | "All CLI server-side-apply writes use field manager `opm-cli`" | `internal/kubernetes/apply.go` (patch with the manager and forced conflicts), `internal/kubernetes/labels.go`, `internal/inventory/store.go`; `sigs.k8s.io/structured-merge-diff/v6` v6.4.2 `merge/update.go:131, 145-147, 252-255` (a forced apply takes a field from another manager only where its value changes; a field no manager sets is pruned only when no other manager claims it); no cli code removes `opm` from `managedFields` (`internal/kubernetes/apply.go:460` and `diff.go:194` touch comparison copies only) |
| The running-operator check uses fixed names | "The running-operator check finds the operator by its fixed names alone" | `internal/operator/ready.go`, `internal/operator/names.go`; the only caller outside tests is the delete of an operator-owned instance (`internal/cmd/instance/delete.go`). The requirement says "a CLI command that needs a running operator", as the spec does |
| The operator reports its release version | operator spec "Version constant is burned into source and maintained by release automation" and "Version value contract" (merged) | `internal/version/version.go:47-77` (`Full`: `v` plus the constant; `+g` and the first seven characters of the revision when the binary has build info with a revision, so a checkout build and not a release image; `.dirty`), which is why "Tagged commit self-describes" compares the version without its `+` suffix (review T4.R25 finding 10); `release-please-config.json` (the file is an extra file of the release) |
| The operator logs its version at startup | operator spec "Version logged at startup" | `cmd/main.go` (the setup log line "Starting opm-operator" carries `version`) |

## Splits

The CLI spec states 20 requirements and the operator spec 3. The 500-character limit split two CLI requirements that remain, without cutting meaning: "Install deploys the operator module ... in two steps" (CRDs first, the record, reinstall) and "Install runs every refusing check ..." (checks and order, the ownership check, ownership refusals, terminating objects); "Platform seeding and the opt-in user role ..." is split into Platform and role. The platform option rules of two spec requirements and the values rule sit in one requirement, "Contradictory options are refused first". The operator spec's constant and value contract are merged. One requirement is added from code: "The seeded subscription pins one catalog build".

## Where spec and code differ

- The CLI spec lists the status-subresource permission check among the checks before the first write, with no word on CRDs-only. The code skips it for a CRDs-only install, which records no instance. The seed follows the code.
- The CLI spec says only "exit non-zero" for the rollout failure. The code exits 1; the seed keeps "non-zero".
- The operator spec says the suffix is "the short revision". The code takes the first seven characters.
- The CLI spec says uninstall deletes "every object except CRDs and the Namespace". The code also keeps any PersistentVolumeClaim. That rule is 0021's, so it is listed below, not in the seed.

## Code-only statements

Marked "Code" above: the refusal of a module with no readable operator version (the CLI spec states it only for the pin task); the safe-to-re-run hint; the skipped-Platform notice; the catalog build selection; user together with group refused; the status check skipped for CRDs-only.

## Left out

Rules the converted entry 0021 states as its own requirements (branch `refactoring-enhancements/p4-0021`, `operator-install-module` and `operator-version-ceiling`), per DECISIONS.md 2026-10-11 13:30: install from a registry; install independent of the cluster Platform; an existing Platform left alone and not recorded; each CLI release names its module and operator version; the MAJOR.MINOR refusal and its exemption for a running operator; the CRDs-only install; uninstall and its finalizer refusal. The detail the CLI spec adds to them is listed below.

Rules the converted entry 0012 states (`apply-verdict`, `deletion-protocol`): the ownership rules themselves, that install refuses an object adopted by another instance, that no override exists beyond the adopt annotation (the "admission set" of the code), the shared deletion plan and its order.

Other leave-outs:
- The pin refresh task and its check (CLI spec "The CLI pins ..." second half, two scenarios): a maintainer tool, not linked into the binary.
- The operator-version stamp in Platform status (`platform-module-generation`) and restart recovery (`platform-reconciliation`).
- The version selector grammar and the resolution report: `published-module-resolution`. Install only uses it.
- The negative statement that a selector shaped like an operator release tag gets no message of its own.
- The test-shaped scenario "Annotation guarded against reformat" and the release-automation mechanism (operator spec).
- The library version the operator also logs and keys renders with: render caching, not version identity.
- The apply-time gates on `opm instance apply`, the owner and its resolution, and platform resolution: seeds `apply-preflight-gates`, `instance-ownership` and `platform-resolution`.
- The refusal to delete an operator-owned instance that deploys the operator (`instance delete`): `instance-ownership`.

## For the owner at 0021's accept

Detail that the CLI and operator specs add to the rules 0021 states, taken out of this seed. 0021's text does not hold it. At 0021's accept the owner decides whether each item joins 0021 (as a requirement or a scenario) or is dropped.

Install:
- The operator module is `opmodel.dev/modules/opm_operator`, fetched from the CLI's configured registry; the render uses the module's own dependency pins only. One module version and one set of values give the same objects whatever the Platform says (scenario: two clusters with different Platforms, or none).
- Without a version selector, install installs the module version the CLI release pins; each CLI release names that version and the operator version it deploys, both known without a registry (scenario: the output names both).
- With the registry mapping routed to a mirror that holds the module and its dependencies, and the public registry unreachable, install succeeds.
- A MAJOR.MINOR above the CLI's is refused with exit 2, naming the module version, the operator version and upgrading the CLI; a CLI whose own version is not a release skips the rule with a warning; a running operator above the CLI's MAJOR.MINOR, or a target below what runs, does not refuse install (scenarios: operator newer than the CLI; a newer running operator does not block repair).
- Install never records the Platform in the instance; an existing Platform is reported and left untouched (scenario: the stored Platform is unchanged and the command says it was already present).

CRDs-only install:
- It renders the same module version as a full install, applies the same refusals before it applies any CRD, applies exactly the rendered CRDs with server-side apply as `opm-cli`, and waits for each to be `Established`. It writes no instance record, no workload and no Platform, and does no catalog lookup. A later full install of the same module version records those CRDs without recreating them (scenarios: solo-cluster CRD install; full install after CRDs-only).

Uninstall:
- Before it deletes anything it lists the instances cluster-wide. If any carries the operator's cleanup finalizer it refuses, exits 2 and names each as `namespace/name`. With the option that removes finalizers it strips exactly that finalizer from each, attempts every one, says their workloads are orphaned, and deletes only if every one was stripped. A failed list, an RBAC denial included, fails closed with the permission-denied exit code and nothing deleted (scenarios: refusal names the armed instances; override strips only the operator's finalizer; partial failure blocks the delete step; list failure fails closed).
- It reads the operator's instance record. With none it deletes nothing and exits 2 naming `opm operator install` (scenario: operator applied with kubectl).
- It deletes the objects the record lists, except CRDs, the Namespace and any PersistentVolumeClaim (code; the CLI spec names the first two), and any object the deletion rules for an instance leave in place, then the record when no object failed. It deletes no unlisted object, does not wait for deletion to finish, and treats an absent object as deleted. The closing line counts the deleted and the left-behind objects (scenarios: uninstall after a module install; re-running uninstall; a recorded object adopted by another instance is left behind).

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- The requirement "The seeded subscription pins one catalog build" is gone (25 requirements become 24, and one is added again by review T4.R25): `seed-platform-resolution` holds the catalog-version resolution ("A catalog version is resolved from the registry") and now also states that install uses it for the seeded subscription. Install-side seeding ("Platform seeding follows the rollout") stays here.
